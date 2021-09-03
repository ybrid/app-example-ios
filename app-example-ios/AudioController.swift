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
import YbridPlayerSDK

class AudioController {
    
    var state:PlaybackState { get {
        return control?.state ?? .stopped
    }}
    
    var running:Bool { get {
        guard let player = control else {
            return false
        }
        return player.state == .buffering || player.state == .playing
    }}
    
    var control:PlaybackControl? {
        didSet {
            guard let control = control else {
                Logger.shared.notice("control changed to (nil)")
                view?.detach()
                return
            }
            
            Logger.shared.debug("control changed to \(type(of: control))")
            view?.attach(control: control)
        }
    }
    
    weak var view:ViewController?
    
    init(view:ViewController?,_ endpoint:MediaEndpoint, listener:AudioPlayerListener, callback: @escaping (AudioController) -> ()) {

        view?.detach()
        self.view = view
        
        do {
            try AudioPlayer.open(for: endpoint, listener: listener,
               playbackControl: { (control) in
                self.control = control
                callback(self)
               },
               ybridControl: { (ybridControl) in
                self.control = ybridControl
                callback(self)
               })
        } catch {
            Logger.shared.error("no player for \(endpoint.uri)")
            self.control = nil
            callback(self)
            return
        }
    }

     func toggle() {
        guard let player = control else {
            // todo
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
}
