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

import UIKit
import YbridPlayerSDK

class ChannelSelector:
    NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    
    var channels:[String] = []
    let componentsSize:CGSize
    let font:UIFont
    var userSelectedChannel:((String?) -> ())?
    weak var pView:UIPickerView?
    var selected:String?
    
    init(_ view:UIPickerView, font:UIFont, onChannelSelected: ((String?) -> ())? = nil ) {
        self.userSelectedChannel = onChannelSelected
        self.font = font
        self.componentsSize = CGSize(width: 54, height: 50)
        super.init()
        self.pView = view
        view.delegate = self
        view.dataSource = self
        view.transform = CGAffineTransform(rotationAngle: -90 * (.pi/180))
    }

    func defineAction(onChannelSelected:@escaping (String?) -> () ) {
        userSelectedChannel = onChannelSelected
    }
    

    
    /// on select channel
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {

        let oldValue = selected
        guard channels.count > 0 else {
            return
        }
        selected = channels[row]
        if selected != oldValue {
            UserFeedback.haptic.medium()
            userSelectedChannel?(selected)
        }
    }
    
    func setChannels(ids:[String]) {
        channels = ids
        DispatchQueue.main.async {
            self.pView?.reloadAllComponents()
        }
    }
    
    func setSelection(to id:String) {

        guard let index = channels.firstIndex(of: id) else {
            Logger.shared.error("unknown channel with id \(id)")
            return
        }
        guard let view = pView else {
            Logger.shared.error("no channel selector view")
            return
        }
        
        self.selected = id
        DispatchQueue.main.async {
            view.selectRow(index, inComponent: 0, animated: true)
        }
    }
    
    func enable(_ enable:Bool) {
        DispatchQueue.main.async {
            self.pView?.alpha = enable ? 1 : 0.6
            self.pView?.isUserInteractionEnabled = enable
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        channels.count
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return componentsSize.height
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return componentsSize.width
    }
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let view = UIView()
        view.transform = CGAffineTransform(rotationAngle: 90 * (.pi/180))
        view.frame = CGRect(x: 0, y: 0, width: componentsSize.width-2, height: componentsSize.height)
        
        let label = UILabel()
        label.frame = CGRect(x: 0, y: 10, width: componentsSize.width - 2, height: componentsSize.height-12)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0.0
        paragraphStyle.lineHeightMultiple = 0.6
        
        let font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.footnote).withSize(font.pointSize)
        
        let color = UIColor.magenta
//            UIColor(red: 234, green: 51, blue: 274, alpha: 1) // #EA33F7
        label.attributedText =
            NSAttributedString(string: channels[row], attributes: [
                NSAttributedString.Key.foregroundColor:color,
                NSAttributedString.Key.font:font,
                NSAttributedString.Key.paragraphStyle:paragraphStyle
            ])
        label.textAlignment = .center
        label.numberOfLines = 3
        label.lineBreakMode = NSLineBreakMode.byTruncatingMiddle
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        view.addSubview(label)

        return view
    }
}
