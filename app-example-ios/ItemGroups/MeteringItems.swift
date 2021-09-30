//
// MeteringItems.swift
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
//            self.view?.offsetS.alpha = enable ? 1.0 : 0.5
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
        clearMaxRate()
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
    func show(maxRate kbps: Int32?) {
        if let max = kbps {
            view?.maxRateLabel.show("max \(max) kbit/s")
            DispatchQueue.main.async {
                let maxRateValue = Float(max*1000 - bitRatesRange.lowerBound) / Float(bitRatesRange.upperBound - bitRatesRange.lowerBound)
                self.view?.maxRateSlider.setValue(maxRateValue, animated: false)
            }
        } else {
            view?.maxRateLabel.show("max bit-rate")
        }
    }
    func clearMaxRate() {
        DispatchQueue.main.async {
            self.view?.maxRateSlider.value = 1.0
            self.view?.maxRateLabel.text = "max bit-rate"
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
