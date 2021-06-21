//
// UserFeedback.swift
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

class UserFeedback {
    
    static var soft = false
    
    var heavy:NSObject?
    var medium:NSObject?
    init() {
        if canHapticFeedback(), #available(iOS 10.0, *) {
            let generator1 = UIImpactFeedbackGenerator(style: .heavy)
            generator1.prepare()
            self.heavy = generator1
            let generator2 = UIImpactFeedbackGenerator(style: .medium)
            generator2.prepare()
            self.medium = generator2
        }
    }
    
    private func canHapticFeedback() -> Bool {
        guard let level = UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Int else {
            Logger.shared.info("haptic feedback is not supported on this device")
            return false
        }
        let active = level > 1
        Logger.shared.info("haptic feedback is \(active ? "":"in")active. Device supports level \(level).")
        return active
    }

    func haptic() {
        if #available(iOS 10.0, *) {
            if UserFeedback.soft, let generator = medium as? UIImpactFeedbackGenerator {
                generator.impactOccurred()
            } else {
                if let generator = heavy as? UIImpactFeedbackGenerator {
                    generator.impactOccurred()
                }
            }
        }
    }

}
