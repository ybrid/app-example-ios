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
    let audioChange:()->()
    enum behaviour {
        case always
        case single
        case multi
    }
    let behave:behaviour
    init(_ name:String, _ behave:behaviour = .always, _ method: @escaping ()->()) {
        self.actionString = name
        self.behave = behave
        self.audioChange = method
    }
}


class ActionButton : UIButton {
    
    var action = Action("(no action)") {}
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
        addTarget(self, action: #selector(trigger), for: .touchUpInside)
    }
    
    @objc func shake() {
        UserFeedback.haptic.medium()
    }
    
    @objc func trigger() {
        if action.behave == .single {
            DispatchQueue.main.async {
                self.isEnabled = false
            }
        }

        Logger.shared.debug("\(action.actionString) triggered")
        action.audioChange()
    }

    func completed() {
        Logger.shared.debug("\(action.actionString) completed")
        if action.behave == .single {
            DispatchQueue.main.async {
                self.isEnabled = true
            }
        }
    }
    
}
