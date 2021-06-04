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
    
    let channels = ["c1", "c2", "c3"]
    let width:CGFloat = 50
    let height:CGFloat = 50
//    let view:UIPickerView
    
    init(_ view:UIPickerView, frame: CGRect? = nil) {
//        self.view = view
        super.init()
        view.delegate = self
        view.dataSource = self
        
        view.transform = CGAffineTransform(rotationAngle: -90 * (.pi/180))

        view.layer.backgroundColor = UIColor.darkGray.cgColor
        view.layer.borderColor = UIColor.blue.cgColor
        view.layer.borderWidth = 1.5
        if let frame = frame {
            view.frame = frame
        }
    }
    
    
//    init(frame: CGRect) {
//        view = UIPickerView()
//        super.init()
//        view.delegate = self
//        view.dataSource = self
//
//        view.transform = CGAffineTransform(rotationAngle: -90 * (.pi/180))
//
//        view.layer.backgroundColor = UIColor.darkGray.cgColor
//        view.layer.borderColor = UIColor.blue.cgColor
//        view.layer.borderWidth = 1.5
//
//        view.frame = frame
//    }
//
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//    }
    
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
        label.text = channels[row]
        label.textAlignment = .center
        view.addSubview(label)

        view.transform = CGAffineTransform(rotationAngle: 90 * (.pi/180))

        return view
    }
}
