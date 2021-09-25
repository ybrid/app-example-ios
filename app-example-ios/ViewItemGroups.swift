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

// groups of ui elements

class MetadataItems {
    private static let metadataColor = UIColor(rgb: 0x00f000) // green

    weak var view:ViewController?
    
    // MARK: creation
    init(view:ViewController) {
        self.view = view
        initialiteFields()
        initializeValues()
    }
    
    fileprivate func initialiteFields() {
        guard let view = view else {
            return // todo error
        }
        let items = [view.broadcaster, view.genre, view.playingTitle]
        DispatchQueue.main.async {
            items.forEach { item in
                item?.textColor = MetadataItems.metadataColor
            }
        }
    }
    
    private func initializeValues() {
        show(title: nil)
        show(station: nil)
    }
    
    // MARK:
    func attach(_ control:SimpleControl) {
        initializeValues()
    }
    func detach() {
    }
    
    func reset() {
        show(title: nil)
    }
    
    func show(title: String?) {
        view?.playingTitle.show(title)
    }
    func show(station: Station?) {
        view?.broadcaster.show(station?.name)
        view?.genre.show(station?.genre)
    }
}

class InteractionItems {
    private static let interactionsColor = UIColor(rgb:0xf000f0)
    weak var view:ViewController?

    var channelSelector:ChannelSelector?
    var channelPicker = UIPickerView()


    var audio:AudioController? { get {
        return view?.audioController
    }}

    init(view:ViewController) {
        self.view = view
        let items:[UILabel] = [view.maxRateLabel]
        DispatchQueue.main.async {
            items.forEach { item in
                item.textColor = InteractionItems.interactionsColor
            }
        }

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
        initializeActions()
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
            self.view?.maxRateLabel.text = "max bit-rate"
        }
    }



    private func initializeActions() {

//        self.view?.togglePlay.action = Action("toggle", .always) { [self] in
//            guard let audio = audioController else { return }
//            if let control = audio?.control, !control.running {
//                audio.metering.clearMessage()
//            }
//            onToggle()
//        }

        view?.swapItemButton.action = Action("swap item", .single) { [self] in
            audio?.metering.clearMessage()
            audio?.ybrid?.swapItem{ _ in self.view?.swapItemButton.completed() }
        }
        view?.itemBackwardButton.action = Action("item backward", .multi ) { [self] in
            audio?.metering.enableOffset(false)
            audio?.metering.clearMessage()
            audio?.ybrid?.skipBackward() { _ in
                audio?.metering.enableOffset(true)
            }
        }
        view?.windBackButton.action = Action( "wind back", .multi) { [self] in
            audio?.metering.enableOffset(false)
            audio?.metering.clearMessage()
            audio?.ybrid?.wind(by: -15.0) { _ in
                audio?.metering.enableOffset(true)
            }
        }
        view?.windToLiveButton.action = Action( "wind to live", .single ) { [self] in
            audio?.metering.enableOffset(false)
            audio?.metering.clearMessage()
            audio?.ybrid?.windToLive{ _ in
                self.view?.windToLiveButton.completed()
                audio?.metering.enableOffset(true)
            }
        }
        view?.windForwardButton.action = Action("wind forward", .multi) { [self] in
            audio?.metering.enableOffset(false)
            audio?.metering.clearMessage()
            audio?.ybrid?.wind(by: +15.0) { _ in audio?.metering.enableOffset(true) }
        }
        view?.itemForwardButton.action = Action( "item forward", .multi) { [self] in
            audio?.metering.enableOffset(false)
            audio?.metering.clearMessage()
            audio?.ybrid?.skipForward() { _ in audio?.metering.enableOffset(true) }
        }
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

class MeteringItems {
    private static let meteringColor = UIColor(rgb:0x00f8f8) // cyan
    weak var view:ViewController?
    
    init(view:ViewController) {
        self.view = view
        let items:[UILabel] = [
            view.offsetS,
            view.offsetLabel,
            view.playedSince,
            view.playingSinceLabel,
            view.currentBitRate,
            view.currentBitRateLabel,
            view.readyLabel,
            view.ready,
            view.connectedLabel,
            view.connected,
            view.bufferCurrent,
            view.bufferCurrentLabel,
            view.bufferAveraged,
            view.bufferAveragedLabel
        ]
        DispatchQueue.main.async {
            items.forEach { item in
                item.textColor = MeteringItems.meteringColor
            }
        }
        initializeValues()
    }
    func attach(_ control:SimpleControl) {
        initializeValues()
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
    
    func clearMessage() {
        DispatchQueue.main.async {
            self.view?.problem.text = nil
        }
    }
    
    func showMessage(_ color: UIColor, _ text:String) {
        DispatchQueue.main.async {
            self.view?.problem.textColor = color
            self.view?.problem.text = text
        }
    }
    
    func enableOffset(_ enable:Bool) {
        /// Disabled visualization for timeshifts by doing nothing here.
        /// unitl points in time for audioComplete are more reliable.
//        DispatchQueue.main.async {
//            self.offsetS.alpha = enable ? 1.0 : 0.5
//        }
    }
    
    func resetValues() {
        show(playingSince: 0)
        show(readyToPlay: nil)
        show(connected: nil)
        show(bufferCurrent: nil)
        show(bufferAveraged: nil)
        show(currentRate: nil)
        clearMessage()
    }
    
    private func initializeValues() {
        show(playingSince: 0)
        show(readyToPlay: nil)
        show(connected: nil)
        show(bufferCurrent: nil)
        show(bufferAveraged: nil)
        show(currentRate: nil)
        clearMessage()
    }
    
    private func visible(_ playback:Bool, _ ybrid:Bool) {
        DispatchQueue.main.async { [self] in
            view?.offsetS.isHidden = !ybrid
            view?.offsetLabel.isHidden = !ybrid
            view?.currentBitRate.isHidden = !ybrid
            view?.currentBitRateLabel.isHidden = !ybrid
        }
    }
    
    private func enable(_ playback:Bool, _ ybrid:Bool) {
        DispatchQueue.main.async { [self] in
            view?.offsetS.isEnabled = ybrid
            view?.offsetLabel.isEnabled = ybrid
            view?.currentBitRate.isEnabled = ybrid
            view?.currentBitRateLabel.isEnabled = ybrid
        }
    }
    
    func show(playingSince seconds: TimeInterval?) {
        view?.playedSince.show(seconds?.hmsS)
    }
    func show(readyToPlay seconds: TimeInterval?) {
        view?.ready.show(seconds?.sSSS)
    }
    func show(connected seconds: TimeInterval?) {
        view?.connected.show(seconds?.sSSS)
    }
    func show(bufferCurrent seconds: TimeInterval?) {
        view?.bufferCurrent.show(seconds?.sSS)
    }
    func show(bufferAveraged seconds: TimeInterval?) {
        view?.bufferAveraged.show(seconds?.sS)
    }
    func show(currentRate kbps: Int32?) {
        if let curr = kbps {
            view?.currentBitRate.show("\(curr) kbit/s")
        } else {
            view?.currentBitRate.show(nil)
        }
    }
    
    func show(offsetToLive seconds: TimeInterval?) {
        view?.offsetS.show(seconds?.hmmssS)
    }
    func show(swapsLeft:Int) {
        DispatchQueue.main.async {
            self.view?.swapItemButton.isEnabled = swapsLeft != 0
        }
    }
    
}


extension UILabel {
    func show(_ text:String?) {
        DispatchQueue.main.async {
            self.text = text
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
