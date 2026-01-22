//
//  ContentView.swift
//  CentralDemo
//
//  Created by Kevin Lundberg on 3/27/22.
//

import CombineCoreBluetooth
import SwiftUI

extension CBUUID {
  static let service = CBUUID(string: "1337")
  static let writeResponseCharacteristic = CBUUID(string: "0001")
  static let writeNoResponseCharacteristic = CBUUID(string: "0002")
  static let writeBothResponseAndNoResponseCharacteristic = CBUUID(string: "0003")
    static let sendIsPlaying = CBMutableCharacteristic(type: CBUUID(string: "1667"), properties: .notify, value: nil, permissions: .readable)
    static let controlCharacteristic = CBUUID(string: "1667")
    static let scrubCharacteristic = CBUUID(string: "1420")
}

class CentralDemo: ObservableObject {
     var controlCancellable: AnyCancellable?
    var scrubCancellable: AnyCancellable?
    var connectionCancellable: AnyCancellable?
  let centralManager: CentralManager = .live()
  @Published var peripherals: [PeripheralDiscovery] = []
  var scanTask: AnyCancellable?
  @Published var peripheralConnectResult: Result<Peripheral, Error>?
  @Published var scanning: Bool = false
    
  var connectedPeripheral: Peripheral? {
    guard case let .success(value) = peripheralConnectResult else { return nil }
    return value
  }

  var connectError: Error? {
    guard case let .failure(value) = peripheralConnectResult else { return nil }
    return value
  }

  func searchForPeripherals() {
    scanTask = centralManager.scanForPeripherals(withServices: [CBUUID.service])
      .scan([], { list, discovery -> [PeripheralDiscovery] in
        guard !list.contains(where: { $0.id == discovery.id }) else { return list }
        return list + [discovery]
      })
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] in
        self?.peripherals = $0
      })
    scanning = centralManager.isScanning
  }

  func stopSearching() {
    scanTask = nil
    peripherals = []
    scanning = centralManager.isScanning
  }

  func connect(_ discovery: PeripheralDiscovery) {
    centralManager.connect(discovery.peripheral)
      .map(Result.success)
      .catch { Just(Result.failure($0)) }
      .receive(on: DispatchQueue.main)
      .assign(to: &$peripheralConnectResult)
      
      connectionCancellable = centralManager
        .monitorConnection(for: discovery.peripheral) // sends true on connect, false on disconnect
        .receive(on: DispatchQueue.main)
        .sink { [weak self] connected in
          guard let self else { return }
          if !connected {
              print("disconnected")
            self.peripheralConnectResult = nil    // clear UI state
            self.controlCancellable = nil         // drop subscriptions to characteristics
            self.scrubCancellable = nil
          }
        }
  }
}

class PeripheralDevice: ObservableObject {
  let peripheral: Peripheral
  init(_ peripheral: Peripheral) {
    self.peripheral = peripheral
  }

  @Published var writeResponseResult: Result<Date, Error>?
  @Published var writeNoResponseResult: Result<Date, Error>? // never should be set
  @Published var writeResponseOrNoResponseResult: Result<Date, Error>?

  func write(
    playbackData: Data,
    to id: CBUUID,
    type: CBCharacteristicWriteType,
    result: ReferenceWritableKeyPath<PeripheralDevice, Published<Result<Date, Error>?>.Publisher>
  ) {
      print("calling peripheral.writevalue")
    peripheral.writeValue(
      playbackData,
      writeType: type,
      forCharacteristic: id,
      inService: .service
    )
    .receive(on: DispatchQueue.main)
    .map { _ in Result<Date, Error>.success(Date()) }
    .catch { e in Just(Result.failure(e)) }
    .assign(to: &self[keyPath: result])
  }

  func writeWithoutResponse(to id: CBUUID) {
    writeNoResponseResult = nil

    peripheral.writeValue(
      Data("Hello".utf8),
      writeType: .withoutResponse,
      forCharacteristic: id,
      inService: .service
    )
    .receive(on: DispatchQueue.main)
    .map { _ in Result<Date, Error>.success(Date()) }
    .catch { e in Just(Result.failure(e)) }
    .assign(to: &$writeNoResponseResult)
  }
}

struct CentralView: View {
  @StateObject var demo: CentralDemo = .init()
    @State var viewModel: ViewModel = ViewModel()

  var body: some View {
//      Text("Hi")
      VStack {
          ContentView(viewModel: $viewModel)
      }
    if let device = demo.connectedPeripheral {
        PeripheralDeviceView(device: .init(device), demo: demo, viewModel: $viewModel)
            .onAppear {
                print("SETTING CONTROL CANCELLABLE")
                demo.controlCancellable = device
                    .discoverCharacteristic(withUUID: .controlCharacteristic, inServiceWithUUID: .service)
                    .flatMap { characteristic in
                        device.subscribeToUpdates(on: characteristic)
                    }
                    .replaceError(with: nil)      // ignore errors
                    .compactMap { $0 }            // drop nil data
                    .sink { data in
                        let isPlaying = (data.first == 1)
                        if viewModel.isPlaying != isPlaying {
                            viewModel.playPause()
                        }
                        print("received new characteristic. is it now paused or playing? data: \(data)")
                    }
                
                demo.scrubCancellable = device
                    .discoverCharacteristic(withUUID: .scrubCharacteristic, inServiceWithUUID: .service)
                    .flatMap { characteristic in
                        device.subscribeToUpdates(on: characteristic)
                    }
                    .replaceError(with: nil)      // ignore errors
                    .compactMap { $0 }            // drop nil data
                    .sink { data in
                        print("Received scrub data")
                        guard data.count == 8 else {
                            print("data count is under 8")
                            return
                        }
                        let raw = data.prefix(8).withUnsafeBytes { $0.load(as: UInt64.self) }
                        let seconds = Int(UInt64(littleEndian: raw))
                        print("received new characteristic. scrub position: \(seconds)")
                        viewModel.setPosition(seconds)
                    }
            }
    } else {
      Form {
        Section {
          if !demo.scanning {
            Button("Search for peripheral") {
              demo.searchForPeripherals()
            }
          } else {
            Button("Stop searching") {
              demo.stopSearching()
            }
          }

          if let error = demo.connectError {
            Text("Error: \(String(describing: error))")
          }
        }

        Section("Discovered peripherals") {
          ForEach(demo.peripherals) { discovery in
            Button(discovery.peripheral.name ?? "<nil>") {
              demo.connect(discovery)
            }
          }
        }
      }
    }
  }
}

struct PeripheralDeviceView: View {
  @ObservedObject var device: PeripheralDevice
  @ObservedObject var demo: CentralDemo
    @Binding var viewModel: ViewModel

  var body: some View {
    Form {
//      Section("Characteristic sends response") {
//        Button(action: {
//          device.write(
//            to: .writeResponseCharacteristic,
//            type: .withResponse,
//            result: \PeripheralDevice.$writeResponseResult
//          )
//        }) {
//          Text("Write with response")
//        }
//        Button(action: {
//          device.write(
//            to: .writeResponseCharacteristic,
//            type: .withoutResponse,
//            result: \PeripheralDevice.$writeResponseResult
//          )
//        }) {
//          Text("Write without response")
//        }
//        label(for: device.writeResponseResult)
//      }

      Section("Characteristic doesn't send response (Playback Information)") {
//        Button(action: {
//          device.write(
//            to: .writeNoResponseCharacteristic,
//            type: .withResponse,
//            result: \PeripheralDevice.$writeNoResponseResult
//          )
//        }) {
//          Text("Write with response")
//        }
        Button(action: {
          device.write(
            playbackData: Data("hello".utf8),
            to: .writeNoResponseCharacteristic,
            type: .withoutResponse,
            result: \PeripheralDevice.$writeNoResponseResult
          )
        }) {
          Text("Write without response")
        }
        label(for: device.writeNoResponseResult)
      }

//      Section("Characteristic can both send or not send response") {
//        Button(action: {
//          device.write(
//            to: .writeBothResponseAndNoResponseCharacteristic,
//            type: .withResponse,
//            result: \PeripheralDevice.$writeResponseOrNoResponseResult
//          )
//        }) {
//          Text("Write with response")
//        }
//        Button(action: {
//          device.write(
//            to: .writeBothResponseAndNoResponseCharacteristic,
//            type: .withoutResponse,
//            result: \PeripheralDevice.$writeResponseOrNoResponseResult
//          )
//        }) {
//          Text("Write without response")
//        }
//
//        label(for: device.writeResponseOrNoResponseResult)
//      }
    }
    .onAppear(perform: sendPlaybackInfo)
    .onChange(of: viewModel.trackInfoUpdate) { _ in
        sendPlaybackInfo()
    }
  }

  func label<T>(for result: Result<T, Error>?) -> some View {
    Group {
      switch result {
      case let .success(value)?:
        Text("Wrote at \(String(describing: value))")
      case let .failure(error)?:
        if let error = error as? LocalizedError, let errorDescription = error.errorDescription {
          Text("Error: \(errorDescription)")
        } else {
          Text("Error: \(String(describing: error))")
        }
      case nil:
        EmptyView()
      }
    }
  }

  private func sendPlaybackInfo() {
    // Encode and push the latest playback info immediately (on connect and whenever it changes).
    guard let data = try? JSONEncoder().encode(
      PlaybackInformation(
        title: viewModel.currentTitle,
        currentTimestamp: viewModel.currentProgress,
        TotalTimestamp: viewModel.mediaLength,
        isPlaying: viewModel.isPlaying
      )
    ) else {
      print("Failed to encode playback info for peripheral")
      return
    }

    device.write(
      playbackData: data,
      to: .writeNoResponseCharacteristic,
      type: .withoutResponse,
      result: \PeripheralDevice.$writeNoResponseResult
    )
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    CentralView()
  }
}
