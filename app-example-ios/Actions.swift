//
// Actions.swift
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


class Action {

    let actionString:String

    let method:()-> ()
    init(_ name:String, _ method: @escaping ()->()) {
        self.actionString = name
        self.method = method
    }
}


class ActionButton : UIButton {
    
    var onTouchDown = true { didSet {
        if oldValue != onTouchDown {
            removeTarget(self, action: #selector(execute), for: .allTouchEvents)
           setup()
        }
    }}
    
    let feedback = UserFeedback()    
    var action = Action("(no action)") {}
    enum behaviour {
        case single
        case multi
    }
    var behave:behaviour?
    
    override init(frame: CGRect) {
         super.init(frame: frame)
         setup()
     }

     required init?(coder: NSCoder) {
         super.init(coder: coder)
         setup()
     }
    
    func setup() {
        addTarget(self, action: #selector(shake), for: .touchDown)
        addTarget(self, action: #selector(execute), for: onTouchDown ? .touchDown : .touchUpInside)
    }
    
    @objc func shake() {
        feedback.haptic()
    }
    
    @objc func execute() {
        Logger.shared.debug("calling \(action.actionString)")
        if behave == .single {
            DispatchQueue.main.async {
                self.isEnabled = false
            }
        }
        action.method()
    }

    func carriedOut() {
        Logger.shared.debug("\(action.actionString) carried out")
        DispatchQueue.main.async {
            self.isEnabled = true
        }
    }
    
}
