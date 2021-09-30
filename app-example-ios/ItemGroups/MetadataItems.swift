//
// MetadataItems.swift
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


class MetadataItems {
    private static let metadataColor = UIColor(rgb: 0x00f000) // green
    weak var view:ViewController?
    
    // MARK: creation
    init(view:ViewController) {
        self.view = view
        initialiteFields()
        initializeValues()
    }
    
    private func initialiteFields() {
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
    
    func show(current: Item?, next: Item?) {
        let totalText = NSMutableAttributedString()
        if let current = current {
            totalText.append(getAttributedText(current))
        }
        // "->" U+2192 (8594)
        totalText.append( NSMutableAttributedString(string:"\n\u{2192} ",  attributes: [NSAttributedString.Key.foregroundColor : UIColor.lightGray]))
        if let next = next {
            totalText.append(getAttributedText(next))
        }
 
        view?.playingTitle.show(colored: totalText)
    }

    private func getAttributedText(_ item:Item )-> NSAttributedString {
        let itemText = NSMutableAttributedString()
        switch item.type {
        case .MUSIC:
            itemText.append(NSMutableAttributedString(string: item.title ?? "", attributes: [NSAttributedString.Key.foregroundColor : MetadataItems.metadataColor]))
            itemText.append(NSMutableAttributedString(string: " by ", attributes: [NSAttributedString.Key.foregroundColor : UIColor.systemGreen]))
            itemText.append(NSMutableAttributedString(string: item.artist ?? "", attributes: [NSAttributedString.Key.foregroundColor : MetadataItems.metadataColor]))
        case .VOICE:
            itemText.append(NSMutableAttributedString(string: item.title ?? "", attributes: [NSAttributedString.Key.foregroundColor : UIColor.brown]))
        case .NEWS, .WEATHER, .TRAFFIC:
            itemText.append(NSMutableAttributedString(string: item.title ?? "", attributes: [NSAttributedString.Key.foregroundColor : UIColor.blue]))
        default:
            itemText.append(NSMutableAttributedString(string: item.displayTitle, attributes: [NSAttributedString.Key.foregroundColor : MetadataItems.metadataColor]))
        }
        return itemText
    }
}
