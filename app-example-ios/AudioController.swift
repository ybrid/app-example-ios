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

import YbridPlayerSDK

extension PlaybackControl {
    var running:Bool { get {
        return self.state == .buffering || self.state == .playing
    }}
}

class AudioController: AudioPlayerListener, YbridControlListener {
    
    var state:PlaybackState { get {
        return control?.state ?? .stopped
    }}
    
    let metadata:MetadataItems
    let interactions:InteractionItems
    let metering:MeteringItems
 
    
    //  MARK: the model of this controller
    
    var control:PlaybackControl? {
        didSet {
            
            guard let control = control else {
                Logger.shared.notice("control changed to (nil)")
                
                if let oldControl = oldValue, oldControl.state != .stopped {
                    oldControl.stop()
                }
                
                interactions.detach()
                metadata.detach()
                metering.detach()
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
            
            Logger.shared.debug("control changing to \(type(of: control))")

            
            interactions.attach(control)
            metadata.attach(control)
            metering.attach(control)
            
            if let ybrid = control as? YbridControl {
                ybrid.select()
            }
            Logger.shared.debug("control changed to \(type(of: control))")
            if oldPlaying {
                control.play()
            }
        }
    }
    var cachedControls:[MediaEndpoint:PlaybackControl] = [:]

    var ybrid:YbridControl? { get {
        control as? YbridControl
    }}
    
    init(view:ViewController) {
        metadata = MetadataItems(view: view)
        interactions = InteractionItems(view: view)
        metering = MeteringItems(view: view)
        metering.listener = self
    }

    func useControl(_ endpoint:MediaEndpoint, callback: @escaping (PlaybackControl) -> ()) {
        
        if let existingControl = self.cachedControls[endpoint] {
            Logger.shared.debug("already created control for \(endpoint.uri)")
            control = existingControl
            callback(existingControl)
            return
        }
        
        interactions.enable(false)
        do {
            try AudioPlayer.open(for: endpoint, listener: self,
               playbackControl: { (control) in
                self.cachedControls[endpoint] = control
                self.control = control
                callback(control)
                self.interactions.enable(true)
               },
               ybridControl: { (ybridControl) in
                self.cachedControls[endpoint] = ybridControl
                self.control = ybridControl
                callback(ybridControl)
                self.interactions.enable(true)
               })
        } catch {
            Logger.shared.error("no player for \(endpoint.uri)")
            self.control = nil
            interactions.enable(true)
            return
        }
     }
    
     func toggle() {
        guard let player = control else {
            Logger.shared.error("no audio control to toggle")
            return
        }
        
        switch player.state  {
        case .stopped, .pausing:
            player.play()
        case .playing:
            player.canPause ? player.pause() : player.stop()
        case .buffering:
            player.stop()
        @unknown default:
            fatalError("unknown player state \(player.state )")
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
            self.interactions.view?.setStopped()
            metadata.reset()
        case .pausing:
            self.interactions.view?.setPausing()
        case .buffering:
            self.interactions.view?.setBuffering()
        case .playing:
            let canPause = self.control?.canPause
            self.interactions.view?.setPlaying(canPause: canPause ?? false)
        @unknown default:
            Logger.shared.error("state changed to unknown \(state)")
        }
    }
    
    func metadataChanged(_ metadata:Metadata) {
        DispatchQueue.main.async {
            if self.state != .stopped,
               let title = metadata.displayTitle {
                self.metadata.view?.playingTitle.text = title
            } else {
                self.metadata.view?.playingTitle.text = nil
            }
            
            if let station = metadata.station {
                self.metadata.view?.broadcaster.text = station.name
                self.metadata.view?.genre.text = station.genre
            } else {
                self.metadata.view?.broadcaster.text = nil
                self.metadata.view?.genre.text = nil
            }
        }

        if let serviceId = metadata.activeService?.identifier {
            self.interactions.channelSelector?.setSelection(to: serviceId)
        }
    }
    
    func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        DispatchQueue.main.async { [self] in
            switch severity {
            case .fatal: self.metadata.view?.problem.textColor = .red
                self.metadata.view?.problem.text = exception.message ?? exception.failureReason
            case .recoverable: self.metadata.view?.problem.textColor = .systemOrange
                self.metadata.view?.problem.text = exception.message
                DispatchQueue.global().async {
                    sleep(5)
                    DispatchQueue.main.async {
                        self.metadata.view?.problem.text = nil
                    }
                }
            case .notice: self.metadata.view?.problem.textColor = .systemGreen
                self.metadata.view?.problem.text = exception.message
                DispatchQueue.global().async {
                    sleep(5)
                    DispatchQueue.main.async {
                        self.metadata.view?.problem.text = nil
                    }
                }
            @unknown default:
                Logger.shared.error("unknown error: severity \(severity), \(exception.localizedDescription)")
            }
        }
    }
    
    func playingSince(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            guard let playedS = seconds else {
                self.metering.view?.playedSince.text = nil
                return
            }
            self.metering.view?.playedSince.text = playedS.hmsS
        }
    }
    
    func durationReadyToPlay(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let readyS = seconds {
                self.metering.view?.ready.text = readyS.sSSS
            } else {
                self.metering.view?.ready.text = nil
            }
        }
    }
    func durationConnected(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let connectS = seconds {
                self.metering.view?.connected.text = connectS.sSSS
            } else {
                self.metering.view?.connected.text = nil
            }
        }
    }
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let averaged = averagedSeconds {
                self.metering.view?.bufferAveraged.text = averaged.sS
            } else {
                self.metering.view?.bufferAveraged.text = nil
            }
            if let current = currentSeconds {
                self.metering.view?.bufferCurrent.text = current.sSS
            } else {
                self.metering.view?.bufferCurrent.text = nil
            }
        }
    }
    
    // MARK: YbridControlListener
    
    func offsetToLiveChanged(_ offset:TimeInterval?) {
        DispatchQueue.main.async {
            if let seconds = offset {
                self.metering.view?.offsetS.text =  seconds.hmmssS
            } else {
                self.metering.view?.offsetS.text = nil
            }
        }
    }
    
    func servicesChanged(_ services: [Service]) {
        let ids = services.map{ $0.identifier }
        self.interactions.channelSelector?.setChannels(ids: ids)
    }
    
    func swapsChanged(_ swapsLeft: Int) {
        DispatchQueue.main.async {
            self.interactions.view?.swapItemButton.isEnabled = swapsLeft != 0
        }
    }

    func bitRateChanged(currentBitsPerSecond: Int32?, maxBitsPerSecond: Int32?) {
        var maxKbps:Int32? = nil
        var maxRateValue:Float?
        if let maxBps = maxBitsPerSecond, bitRatesRange.contains(maxBps) {
            let kbps = Int32(maxBps/1000)
            Logger.shared.info("max bit-rate is \(kbps) kbps")
            maxKbps = kbps
            maxRateValue = Float(maxBps - bitRatesRange.lowerBound) / Float(bitRatesRange.upperBound - bitRatesRange.lowerBound)
        }
        
        var currentKbps:Int32? = nil
        if let currentBps = currentBitsPerSecond, bitRatesRange.contains(currentBps) {
            let kbps =  Int32(currentBps/1000)
            Logger.shared.info("current bit-rate is \(kbps) kbps")
            currentKbps = kbps
        }
        
        DispatchQueue.main.async {
            if let maxRateSliderValue = maxRateValue {
                self.interactions.view?.maxRateSlider.setValue(maxRateSliderValue, animated: false)
            }
            if let max = maxKbps {
                self.metering.view?.bitRateLabel.text = "max \(max) kbit/s"
            } else {
                self.metering.view?.bitRateLabel.text = "max bit-rate"
            }
            
            if let curr = currentKbps {
                self.metering.view?.currentBitRate.text = "\(curr) kbit/s"
            } else {
                self.metering.view?.currentBitRate.text = nil
            }
//            let coloredLabelText = self.coloredBitRatesText(currentKbps, maxKbps)
//            self.metering.view?.bitRateLabel.attributedText = coloredLabelText
        }
    }

    private func coloredBitRatesText(_ current:Int32?,_ maximum:Int32?) -> NSAttributedString {
        
        let currentRateColor = UIColor.green
        let maxRateColor = UIColor.magenta
        
        guard let cur = current else {
            var maxRateText = "max bit-rate"
            if let max = maximum {
                maxRateText = "max \(max) kbps"
            }
            return NSAttributedString(string:maxRateText, attributes: [NSAttributedString.Key.foregroundColor : maxRateColor])
        }
        
        guard let max = maximum else {
            let currentRateText = "\(cur) kbps"
            return NSAttributedString(string:currentRateText, attributes: [NSAttributedString.Key.foregroundColor : currentRateColor])
        }
        
        let totalText = NSMutableAttributedString(string:"\(cur)", attributes: [NSAttributedString.Key.foregroundColor : currentRateColor])
        totalText.append(NSAttributedString(string:" /\(max) kbps", attributes: [NSAttributedString.Key.foregroundColor : maxRateColor]))
        return totalText
    }
}


