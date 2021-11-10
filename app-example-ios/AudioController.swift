//
// AudioController.swift
// app-example-ios
//
// Copyright (c) 2021 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import UIKit
import YbridPlayerSDK


class AudioController: AudioPlayerListener, YbridControlListener {


    /// Idea is to disable offset to live value during timeshifts.
    /// Wait unitl points in time for audioComplete from sdk are more reliable.
    static let visualizeTimeshifts = false
    
    let metadatas:MetadataItems
    let interactions:InteractionItems
    let metering:MeteringItems

    var control:PlaybackControl? {
        didSet {
            guard let control = control else {
                Logger.shared.notice("control changed to (nil)")
                
                if let oldControl = oldValue, oldControl.state != .stopped {
                    oldControl.stop()
                }
                attach(nil)
                return
            }
            
            if control.mediaEndpoint == oldValue?.mediaEndpoint {
                return
            }
            
            var oldPlaying = false
            if let oldControl = oldValue, oldControl.state != .stopped {
                oldPlaying = oldControl.running
                oldControl.stop()
            }
            attach(control)
            Logger.shared.debug("control changed to \(type(of: control))")
            if oldPlaying {
                control.play()
            }
        }
    }
    var cachedControls:[MediaEndpoint:PlaybackControl] = [:]

    private var state:PlaybackState { get {
        return control?.state ?? .stopped
    }}

    var ybrid:YbridControl? { get {
        control as? YbridControl
    }}
    
    init(view:ViewController) {
        metadatas = MetadataItems(view: view)
        interactions = InteractionItems(view: view)
        metering = MeteringItems(view: view)
        
        defineActions(view: view)
    }

    private func attach(_ control:PlaybackControl?) {
        if let control = control {
            interactions.attach(control)
            metadatas.attach(control)
            metering.attach(control)
            
            if let ybrid = control as? YbridControl {
                ybrid.select()
            }
        } else {
            interactions.detach()
            metadatas.detach()
            metering.detach()
        }
    }
    
    // MARK: user actions
    
    func defineActions(view:ViewController) {

        view.togglePlay.action = Action("toggle", .always) { [self] in
            if let control = control, !control.running {
                metering.clearMessage()
            }
            guard let endpoint = view.endpoint else {
                Logger.shared.error("no endpoint to toggle")
                return
            }
            onToggle(endpoint: endpoint)
        }

        view.swapItemButton.action = Action("swap item", .single) { [self] in
            metering.clearMessage()
            ybrid?.swapItem{ _ in view.swapItemButton.completed() }
        }
        view.itemBackwardButton.action = Action("item backward", .multi ) { [self] in
            metering.enableOffset(false)
            metering.clearMessage()
            ybrid?.skipBackward() { _ in
                metering.enableOffset(true)
            }
        }
        view.windBackButton.action = Action( "wind back", .multi) { [self] in
            metering.enableOffset(false)
            metering.clearMessage()
            ybrid?.wind(by: -15.0) { _ in
                metering.enableOffset(true)
            }
        }
        view.windToLiveButton.action = Action( "wind to live", .single ) { [self] in
            metering.enableOffset(false)
            metering.clearMessage()
            ybrid?.windToLive{ _ in
                view.windToLiveButton.completed()
                metering.enableOffset(true)
            }
        }
        view.windForwardButton.action = Action("wind forward", .multi) { [self] in
            metering.enableOffset(false)
            metering.clearMessage()
            ybrid?.wind(by: +15.0) { _ in metering.enableOffset(true) }
        }
        view.itemForwardButton.action = Action( "item forward", .multi) { [self] in
            metering.enableOffset(false)
            metering.clearMessage()
            ybrid?.skipForward() { _ in metering.enableOffset(true) }
        }
        
        // other actions, no buttons
        interactions.channelSelector?.defineAction(onChannelSelected: onChannelSelected)
        view.maxRateSlider.addTarget(self, action: #selector(onMaxRateSelected), for: .touchUpInside)
    }
    
    func onChannelSelected(channel: String?) {
        Logger.shared.notice("service \(channel ?? "(nil)") selected")
        guard let ybrid = ybrid, let service = channel else {
            return
        }
        Logger.shared.debug("swap service to \(service) triggered")
        interactions.channelSelector?.enable(false)
        ybrid.swapService(to: service) { (changed) in
            Logger.shared.debug("swap service \(changed ? "" : "not ")completed")
            self.interactions.channelSelector?.enable(true)
        }
    }
    
    @objc func onMaxRateSelected() {
        guard let maxRateValue = interactions.view?.maxRateSlider.value else {
            return
        }
        let selectedRate =  bitRatesRange.lowerBound + Int32(maxRateValue * Float(bitRatesRange.upperBound -  bitRatesRange.lowerBound))

        Logger.shared.debug("selected bit-rate is \(selectedRate)")
        ybrid?.maxBitRate(to: selectedRate)
    }

    func onToggle(endpoint:MediaEndpoint) {
    
        useControl(endpoint) {(control) in
            guard control.mediaEndpoint == endpoint else {
                Logger.shared.notice("aborting \(control.mediaEndpoint.uri)")
                return
            }
            
            switch control.state  {
            case .stopped, .pausing:
                control.play()
            case .playing:
                control.canPause ? control.pause() : control.stop()
            case .buffering:
                control.stop()
            @unknown default:
                fatalError("unknown player state \(control.state )")
            }

        }
        return
    }
    
    func useControl(_ endpoint:MediaEndpoint, callback: @escaping (PlaybackControl) -> ()) {
        
        if let currentControl = control, currentControl.mediaEndpoint == endpoint {
            callback(currentControl)
            return
        }
        
        if let existingControl = self.cachedControls[endpoint] {
            Logger.shared.debug("already created control for \(endpoint.uri)")
            control = existingControl
            callback(existingControl)
            return
        }

        interactions.enable(false)
        do {
            try AudioPlayer.open(for: endpoint, listener: self,
                                 playbackControl: { (control:PlaybackControl) in
                self.cachedControls[endpoint] = control
                self.control = control
                callback(control)
                self.interactions.enable(true)
               },
               ybridControl: { (ybridControl:YbridControl) in
                self.cachedControls[endpoint] = ybridControl
                self.control = ybridControl
                callback(ybridControl)
                self.interactions.enable(true)
               })
        } catch {
            Logger.shared.error("no audio control for \(endpoint.uri)")
            self.control = nil
            interactions.enable(false)
            return
        }
     }
    
    
    // MARK: AudioPlayerListener

    func stateChanged(_ state: PlaybackState) {
        guard self.state == state else {
             /// ignore events from the last player
            Logger.shared.notice("ignoring \(state), current control is \(String(describing: self.state))")
            return
        }

        Logger.shared.debug("state changed to \(state)")

        switch state {
        case .stopped:
            interactions.view?.showPlay()
            metadatas.reset()
        case .pausing:
            interactions.view?.showPlay()
        case .buffering:
            interactions.view?.showBuffering()
        case .playing:
            if control?.canPause == true {
                interactions.view?.showPause()
            } else {
                interactions.view?.showStop()
            }
        @unknown default:
            Logger.shared.error("state changed to unknown \(state)")
        }
    }
    
    func metadataChanged(_ metadata:Metadata) {
        if self.state == .stopped {
            metadatas.show(title: nil)
        } else {
            metadatas.show(title: metadata.displayTitle)
        }
        metadatas.show(service: metadata.service)
        
        if let serviceId = metadata.service?.identifier {
            interactions.selectChannel(serviceId)
        }
    }
    
    func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        switch severity {
        case .fatal:
            metering.showMessage(.red, exception.message ?? exception.failureReason ?? "unknown error" )
            
        case .recoverable:
            metering.showMessage(.systemOrange, exception.message ?? "waiting")
            DispatchQueue.global().async { sleep(5)
                self.metering.clearMessage()
            }
            
        case .notice:
            metering.showMessage(.systemGreen, exception.message ?? "")
            DispatchQueue.global().async { sleep(5)
                self.metering.clearMessage()
            }
            
        @unknown default:
            Logger.shared.error("unknown error: severity \(severity), \(exception.localizedDescription)")
        }
    }
    func playingSince(_ seconds: TimeInterval?) {
        metering.show(playingSince: seconds)
    }
    func durationReadyToPlay(_ seconds: TimeInterval?) {
        metering.show(readyToPlay: seconds)
    }
    func durationConnected(_ seconds: TimeInterval?) {
        metering.show(connected: seconds)
    }
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        metering.show(bufferAveraged: averagedSeconds)
        metering.show(bufferCurrent: currentSeconds)
    }
    
    // MARK: YbridControlListener
    
    func offsetToLiveChanged(_ offset:TimeInterval?) {
        metering.show(offsetToLive: offset)
    }
    
    func servicesChanged(_ services: [Service]) {
        let ids = services.map{ $0.identifier }
        interactions.setChannels(ids)
    }
    
    func swapsChanged(_ swapsLeft: Int) {
        metering.show(swapsLeft: swapsLeft)
    }

    func bitRateChanged(currentBitsPerSecond: Int32?, maxBitsPerSecond: Int32?) {
        var maxKbps:Int32? = nil
        if let maxBps = maxBitsPerSecond, bitRatesRange.contains(maxBps) {
            let kbps = Int32(maxBps/1000)
            Logger.shared.info("max bit-rate is \(kbps) kbps")
            maxKbps = kbps
        }
        metering.show(maxRate: maxKbps)
        
        var currentKbps:Int32? = nil
        if let currentBps = currentBitsPerSecond, bitRatesRange.contains(currentBps) {
            let kbps =  Int32(currentBps/1000)
            Logger.shared.info("current bit-rate is \(kbps) kbps")
            currentKbps = kbps
        }
        metering.show(currentRate: currentKbps)
    }
    
}

// MARK: used in item groups

extension UILabel {
    func show(_ text:String?) {
        DispatchQueue.main.async {
            self.attributedText = nil
            self.text = text
        }
    }
    func show(colored text:NSAttributedString?) {
        DispatchQueue.main.async {
            self.text = nil
            self.attributedText = text
        }
    }
}

extension UIColor {
   convenience init(red: Int, green: Int, blue: Int) {
       assert(red >= 0 && red <= 255, "Invalid red component")
       assert(green >= 0 && green <= 255, "Invalid green component")
       assert(blue >= 0 && blue <= 255, "Invalid blue component")

       self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
   }

   convenience init(rgb: Int) {
       self.init(
           red: (rgb >> 16) & 0xFF,
           green: (rgb >> 8) & 0xFF,
           blue: rgb & 0xFF
       )
   }
}

extension TimeInterval {
    
    var hmsS:String {
        let date = Date(timeIntervalSince1970: self)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC+00")
        if isLess(than: 60) {
            formatter.dateFormat = "s.S' s'"
        } else if isLess(than: 3600) {
            formatter.dateFormat = "m'm 'ss's'"
        } else {
            formatter.dateFormat = "h'h 'mm'm'"
        }
        return formatter.string(from: date)
    }
    
    var hmmssS:String {
        let date = Date(timeIntervalSince1970: -self)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC+00")
        formatter.dateFormat = "-H:mm:ss.S"
        return formatter.string(from: date)
    }
    
    var sSSS:String {
        return String(format: "%.3f s", self)
    }
    
    var sSS:String {
        return String(format: "%.2f s", self)
    }
    
    var sS:String {
        return String(format: "%.1f s", self)
    }
}

