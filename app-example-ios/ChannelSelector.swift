//
// ChannelSelector.swift
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

class ChannelSelector:
    NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    
    var channels:[String] = []
    let width:CGFloat = 50
    let height:CGFloat = 50
    let font:UIFont
    let setSelectedChannel:(String?) -> ()
    weak var view:UIPickerView?
    
    init(_ view:UIPickerView, font:UIFont, onChannelSelected:@escaping (String?) -> () ) {
        self.setSelectedChannel = onChannelSelected
        self.font = font
        super.init()
        self.view = view
        view.delegate = self
        view.dataSource = self
        view.transform = CGAffineTransform(rotationAngle: -90 * (.pi/180))
//        view.layer.backgroundColor = UIColor.black.cgColor
        view.layer.borderColor = UIColor.purple.cgColor
        view.layer.borderWidth = 0.5
    }
    
    /// on select station
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selected = channels[row]

        if isValid {
            setSelectedChannel(selected)
        } else {
            setSelectedChannel(nil)
        }
        
    }
    
    var isValid:Bool { get {
        return true
    }}
    
    
    func setChannels(ids:[String]) {
        channels = ids
        view?.reloadAllComponents()
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        channels.count
    }
    
//    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        return channels[row]
//    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return height
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return width
    }
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let view = UIView()
        view.frame = CGRect(x: 0, y: 0, width: width, height: height)

        let label = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: width, height: height)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0.0
        paragraphStyle.lineHeightMultiple = 0.8
        let font = UIFont(name: font.fontName, size: font.pointSize-2)!
        label.attributedText =
            NSAttributedString(string: channels[row], attributes: [
                NSAttributedString.Key.foregroundColor : UIColor.white,
                NSAttributedString.Key.font:font,
                NSAttributedString.Key.paragraphStyle:paragraphStyle
            ])
        label.lineBreakMode =  NSLineBreakMode.byTruncatingHead
        label.textAlignment = .center
        label.numberOfLines = 3
        view.addSubview(label)

        view.transform = CGAffineTransform(rotationAngle: 90 * (.pi/180))

        return view
    }
    
//    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
//        return NSAttributedString(string: channels[row], attributes: [NSAttributedString.Key.foregroundColor : UIColor.white])
//    }
}
