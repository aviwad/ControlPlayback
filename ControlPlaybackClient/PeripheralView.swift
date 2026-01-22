//
//  ContentView.swift
//  PeripheralDemo
//
//  Created by Kevin Lundberg on 3/25/22.
//

import SwiftUI
import Combine
import CombineCoreBluetooth

extension CBUUID {
  static let service = CBUUID(string: "1337")
  static let writeResponseCharacteristic = CBUUID(string: "0001")
  static let writeNoResponseCharacteristic = CBUUID(string: "0002")
  static let writeBothResponseAndNoResponseCharacteristic = CBUUID(string: "0003")
    static let sendIsPlaying = CBMutableCharacteristic(type: CBUUID(string: "1667"), properties: .writeWithoutResponse, value: nil, permissions: .writeable)
    static let controlCharacteristic = CBUUID(string: "1667")
    static let scrubCharacteristic = CBUUID(string: "1420")
}

class PeripheralDemo: ObservableObject {
  let peripheralManager = PeripheralManager.live()
  @Published var logs: String = ""
  @Published var advertising: Bool = false
    @Published var latestPlaybackInfo: PlaybackInformation?
  private var cancellables = Set<AnyCancellable>()          // long-lived delegate subscriptions
  private var advertisingCancellables = Set<AnyCancellable>() // short-lived advertising tasks
    private var controlCharacteristic: CBMutableCharacteristic!
    private var scrubCharacteristic: CBMutableCharacteristic!
    private var hasActiveCentral = false


  init() {
    peripheralManager.didReceiveWriteRequests
      .receive(on: DispatchQueue.main)
      .sink { [weak self] requests in
        guard let self = self else { return }
          print("Write received")
          print("request count: \(requests.count)")
//          for request in requests {
//              guard let data = request.value else {
//                  print("Request data empty")
//                  return
//              }
//              let playbackInformation = try? JSONDecoder().decode(PlaybackInformation.self, from: data)
//              if let playbackInformation {
//                  print("Playback INformation on iphone: \(playbackInformation.title) is playing? \(playbackInformation.isPlaying)")
//              } else {
//                  print("Could not decode playback information from data")
//              }
//          }
          guard let request = requests.last else {
              print("Error accessing final request")
              return
          }
            guard let data = request.value else {
                print("Request data empty")
                return
            }
            let playbackInformation = try? JSONDecoder().decode(PlaybackInformation.self, from: data)
            if let playbackInformation {
                latestPlaybackInfo = playbackInformation
                print("Playback INformation on iphone: \(playbackInformation.title) is playing? \(playbackInformation.isPlaying)")
            } else {
                print("Could not decode playback information from data")
            }

        self.peripheralManager.respond(to: requests[0], withResult: .success)
      }
    .store(in: &cancellables)

      peripheralManager.centralDidSubscribeToCharacteristic
          .receive(on: DispatchQueue.main)
          .sink { [weak self] _, characteristic in
              self?.hasActiveCentral = true
              print("Central subscribed to \(characteristic.uuid)")
          }
          .store(in: &cancellables)

      peripheralManager.centralDidUnsubscribeFromCharacteristic
              .receive(on: DispatchQueue.main)
              .sink { [weak self] _, characteristic in
                print("Central unsubscribed from \(characteristic.uuid)")
                self?.handleCentralDisconnect()
              }
              .store(in: &cancellables)
  }
    
    private func handleCentralDisconnect() {
        guard hasActiveCentral else { return }
        // Clear any stale playback info and restart advertising/services so a new central can attach cleanly.
        hasActiveCentral = false
        latestPlaybackInfo = nil
        advertising = false
        advertisingCancellables.removeAll()
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        buildServices()
        peripheralManager.startAdvertising(.init([.serviceUUIDs: [CBUUID.service]]))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                self?.advertising = true
            })
            .store(in: &advertisingCancellables)
    }
    
    func sendIsPlaying(_ shouldBePlaying: Bool) {
        guard hasActiveCentral else {
            print("No central subscribed; skipping isPlaying update")
            return
        }

        let data = Data([shouldBePlaying ? 1 : 0])
        let didSend = peripheralManager.updateValue(data, for: controlCharacteristic, onSubscribedCentrals: nil)
        print(didSend ? "Sent Is Playing Value" : "Central not ready for isPlaying update")
    }

    func sendScrubposition(_ newTimestamp: TimeInterval) {
        let seconds = UInt64(newTimestamp.rounded(.towardZero))
        var le = seconds.littleEndian
        let data = withUnsafeBytes(of: &le) { Data($0) }
        peripheralManager.updateValue(data, for: scrubCharacteristic, onSubscribedCentrals: nil)
        print("Sent Scrub Position")
    }

  func buildServices() {
      controlCharacteristic = CBMutableCharacteristic(
                  type: .controlCharacteristic,
                  properties: [.notify],
                  value: nil,
                  permissions: .readable
              )
      scrubCharacteristic = CBMutableCharacteristic(
                  type: .scrubCharacteristic,
                  properties: [.notify],
                  value: nil,
                  permissions: .readable
              )
    let service1 = CBMutableService(type: .service, primary: true)
    let writeCharacteristic = CBMutableCharacteristic(
      type: .writeResponseCharacteristic,
      properties: .write,
      value: nil,
      permissions: .writeable
    )
    let writeNoResponseCharacteristic = CBMutableCharacteristic(
      type: .writeNoResponseCharacteristic,
      properties: .writeWithoutResponse,
      value: nil,
      permissions: .writeable
    )
    let writeWithOrWithoutResponseCharacteristic = CBMutableCharacteristic(
      type: .writeBothResponseAndNoResponseCharacteristic,
      properties: [.write, .writeWithoutResponse],
      value: nil,
      permissions: .writeable
    )

    service1.characteristics = [
      writeCharacteristic,
      writeNoResponseCharacteristic,
      writeWithOrWithoutResponseCharacteristic,
      controlCharacteristic,
      scrubCharacteristic
    ]
    peripheralManager.removeAllServices()
    peripheralManager.add(service1)
  }

  func start() {
    peripheralManager.startAdvertising(.init([.serviceUUIDs: [CBUUID.service]]))
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { c in
        
      }, receiveValue: { [weak self] _ in
        self?.advertising = true
        self?.buildServices()
      })
      .store(in: &advertisingCancellables)
  }

  func stop() {
    peripheralManager.stopAdvertising()
    advertisingCancellables.removeAll()
    advertising = false
  }
}

struct PeripheralView: View {
//  @StateObject var peripheral: PeripheralDemo = .init()
//    @State var viewModel: ViewModel = ViewModel(sendIsPlaying: peripheral.sendIsPlaying(_:))

    
    @StateObject private var peripheral: PeripheralDemo
        @State private var viewModel: ViewModel

        init() {
            let demo = PeripheralDemo()
            _peripheral = StateObject(wrappedValue: demo)
            _viewModel = State(initialValue: ViewModel(sendIsPlaying: demo.sendIsPlaying(_:), sendScrubposition: demo.sendScrubposition(_:)))
        }
  var body: some View {
    Form {
      Section("Device that simulates a peripheral with various kinds of characteristics.") {

        if peripheral.advertising {
          Button("Stop advertising") { peripheral.stop() }
        } else {
          Button("Start advertising") { peripheral.start() }
        }

//          ContentView(viewModel: $viewModel)
          ContentView(
             viewModel: $viewModel,
             onPlayPause: { isPlaying in peripheral.sendIsPlaying(!isPlaying) }, // toggle to desired next state
             onScrub: { seconds in peripheral.sendScrubposition(seconds) }
         )
      }
    }
    .onReceive(peripheral.$latestPlaybackInfo.compactMap { $0 }) { info in
            viewModel.apply(info)
        }
    .onAppear {
      peripheral.start()
    }
    .onDisappear {
      peripheral.stop()
    }
  }
}

struct PeripheralView_Previews: PreviewProvider {
  static var previews: some View {
    PeripheralView()
  }
}
