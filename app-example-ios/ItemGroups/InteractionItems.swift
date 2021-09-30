//
// InteractionItems.swift
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

class InteractionItems {
    private static let interactionsColor = UIColor(rgb:0xf000f0)
    weak var view:ViewController?

    var channelSelector:ChannelSelector?
    var channelPicker = UIPickerView()

    init(view:ViewController) {
        self.view = view
        let items:[UILabel] = [view.maxRateLabel]
        DispatchQueue.main.async {
            items.forEach { item in
                item.textColor = InteractionItems.interactionsColor
            }
        }

        channelSelector = ChannelSelector(channelPicker, font: (view.urlField as UITextField).font!, onChannelSelected: nil)

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
    func setChannels(_ ids: [String]) {
        channelSelector?.setChannels(ids: ids)
    }
    func selectChannel(_ serviceId: String) {
        channelSelector?.setSelection(to: serviceId)
    }
    
    
    
    private func initialize() {
    }

    private func enable(_ playback:Bool, _ ybrid:Bool) {
        DispatchQueue.main.async { [self] in
            view?.togglePlay.isEnabled = playback

            view?.windBackButton.isEnabled = ybrid
            view?.windForwardButton.isEnabled = ybrid
            view?.windToLiveButton.isEnabled = ybrid
            view?.itemBackwardButton.isEnabled = ybrid
            view?.itemForwardButton.isEnabled = ybrid
            view?.swapItemButton.isEnabled = ybrid
            view?.maxRateSlider.isEnabled = ybrid
            view?.maxRateLabel.isEnabled = ybrid
            channelSelector?.enable(ybrid)
        }
    }

    private func visible(_ playback:Bool, _ ybrid:Bool) {
        DispatchQueue.main.async { [self] in
            view?.windBackButton.isHidden = !ybrid
            view?.windForwardButton.isHidden = !ybrid
            view?.windToLiveButton.isHidden = !ybrid
            view?.itemBackwardButton.isHidden = !ybrid
            view?.itemForwardButton.isHidden = !ybrid
            view?.swapItemButton.isHidden = !ybrid
            view?.maxRateSlider.isHidden = !ybrid
            view?.maxRateLabel.isHidden = !ybrid
            channelSelector?.pView?.isHidden = !ybrid
        }
    }
}
