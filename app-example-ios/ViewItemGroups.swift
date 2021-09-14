//
// ViewItemGroups.swift
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

import UIKit
import YbridPlayerSDK

// just groups of ui elements

class MetadataItems {
    weak var view:ViewController?
    init(view:ViewController) {
        self.view = view
        initialize()
    }
    func attach(_ control:SimpleControl) {
        initialize()
    }
    func detach() {
    }
    
    func reset() {
        DispatchQueue.main.async {
            self.view?.playingTitle.text = nil
        }
    }
    
    private func initialize() {
        DispatchQueue.main.async {
            self.view?.broadcaster.text = nil
            self.view?.genre.text = nil
            self.view?.playingTitle.text = nil
        }
    }
}

class InteractionItems {
    weak var view:ViewController?
    
    var channelSelector:ChannelSelector?
    var channelPicker = UIPickerView()
    
    init(view:ViewController) {
        self.view = view

        channelSelector = ChannelSelector(channelPicker, font: (view.urlField as UITextField).font!) { (channel) in
            Logger.shared.notice("service \(channel ?? "(nil)") selected")
            if let ybrid = view.audioController?.ybrid,
               let service = channel {
                Logger.shared.debug("swap service to \(service) triggered")
                self.channelSelector?.enable(false)
                ybrid.swapService(to: service) { (changed) in
                    Logger.shared.debug("swap service \(changed ? "" : "not ")completed")
                    self.channelSelector?.enable(true)
                }
            }
        }
        channelPicker.frame = view.channelPickerFrame.frame
        view.view.addSubview(channelPicker)
        
        /// picking the first service of ybrid bucket, not the primary service
        channelPicker.selectRow(0, inComponent: 0, animated: true)
        
        initialize()
    }

    func attach(_ control:SimpleControl) {
        initialize()
        if let _ = control as? YbridControl? {
            visible(true, true)
            enable(true, true)
        } else {
            visible(true, false)
            enable(true, false)
        }
    }
    func detach() {
        visible(false, false)
        enable(false, false)
    }

    func enable(_ enable:Bool) {
        self.enable(enable,enable)
    }
    
    private func initialize() {
        DispatchQueue.main.async {
            self.view?.maxRateSlider.value = 1.0
            self.view?.bitRateLabel.text = "max bit-rate"
        }
    }
    
    private func enable(_ playback:Bool, _ ybrid:Bool) {
        DispatchQueue.main.async {
            self.view?.togglePlay.isEnabled = playback
            
            self.view?.windBackButton.isEnabled = ybrid
            self.view?.windForwardButton.isEnabled = ybrid
            self.view?.windToLiveButton.isEnabled = ybrid
            self.view?.itemBackwardButton.isEnabled = ybrid
            self.view?.itemForwardButton.isEnabled = ybrid
            self.view?.swapItemButton.isEnabled = ybrid
            self.view?.maxRateSlider.isEnabled = ybrid
            self.view?.bitRateLabel.isEnabled = ybrid
            self.channelSelector?.enable(ybrid)
        }
    }
    
    private func visible(_ playback:Bool, _ ybrid:Bool) {
        DispatchQueue.main.async {
            self.view?.windBackButton.isHidden = !ybrid
            self.view?.windForwardButton.isHidden = !ybrid
            self.view?.windToLiveButton.isHidden = !ybrid
            self.view?.itemBackwardButton.isHidden = !ybrid
            self.view?.itemForwardButton.isHidden = !ybrid
            self.view?.swapItemButton.isHidden = !ybrid
            self.view?.maxRateSlider.isHidden = !ybrid
            self.view?.bitRateLabel.isHidden = !ybrid

            self.channelSelector?.pView?.isHidden = !ybrid
        }
    }
}

class MeteringItems {
    weak var view:ViewController?
    weak var listener:AudioPlayerListener?
    
    init(view:ViewController) {
        self.view = view
        initialize()
    }
    func attach(_ control:SimpleControl) {
        initialize()
        if let _ = control as? YbridControl? {
            visible(true, true)
            enable(true, true)
        } else {
            visible(true, false)
            enable(true, false)
        }
    }
    func detach() {
        visible(false, false)
        enable(false, false)
    }
    private func initialize() {
        DispatchQueue.main.async {
            self.listener?.playingSince(0)
            self.listener?.durationReadyToPlay(nil)
            self.listener?.durationConnected(nil)
            self.listener?.bufferSize(averagedSeconds: nil, currentSeconds: nil)
            self.view?.currentBitRate.text = nil
        }
    }
    
    private func visible(_ playback:Bool, _ ybrid:Bool) {
        DispatchQueue.main.async {
            self.view?.offsetS.isHidden = !ybrid
            self.view?.offsetLabel.isHidden = !ybrid
            self.view?.currentBitRate.isHidden = !ybrid
            self.view?.currentBitRateLabel.isHidden = !ybrid
        }
    }
    
    private func enable(_ playback:Bool, _ ybrid:Bool) {
        DispatchQueue.main.async {
            self.view?.offsetS.isEnabled = ybrid
            self.view?.offsetLabel.isEnabled = ybrid
            self.view?.currentBitRate.isEnabled = ybrid
            self.view?.currentBitRateLabel.isEnabled = ybrid

        }
    }

    
    
}
