//
// ViewController.swift
// app-example-ios
//
// Copyright (c) 2020 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import AVFoundation
import YbridPlayerSDK

class ViewController: UIViewController, AudioPlayerListener, UIPickerViewDataSource, UIPickerViewDelegate {

    var urls:[(String,String)] = [
        ("addradio-demo (ybrid)",   "https://stagecast.ybrid.io/adaptive-demo"),
        ("swr3 (ybrid)",    "https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid")
    ]
    
    var player:AudioPlayer?
    var streamUrl:String? {
        didSet {
            if oldValue != streamUrl {
                if player?.state != PlaybackState.stopped {
                    player?.stop()
                }
                Logger.shared.debug("url changed to \(streamUrl!)")
                player = createPlayer(streamUrl!)
                durationPlaying(0)
            }
        }
    }
    
    // MARK: ui outlets
    
    @IBOutlet weak var playingTitle: UILabel! {
        didSet {
            playingTitle.lineBreakMode = .byWordWrapping
            playingTitle.numberOfLines = 0
        }
    }
    @IBOutlet weak var problem: UILabel!
    @IBOutlet weak var togglePlay: UIButton!
    @IBOutlet weak var urlPicker: UIPickerView!
    @IBOutlet weak var playbackBufferS: UILabel! {
        didSet {
            playbackBufferS.font = playbackBufferS.font.monospacedDigitFont
        }
    }
    @IBOutlet weak var lastBufferS: UILabel! {
        didSet {
            lastBufferS.font = lastBufferS.font.monospacedDigitFont
        }
    }
    @IBOutlet weak var playedS: UILabel! {
        didSet {
            playedS.font = playedS.font.monospacedDigitFont
        }
    }
    @IBOutlet weak var connected: UILabel! {
        didSet {
            connected.font = connected.font.monospacedDigitFont
        }
    }
    @IBOutlet weak var ready: UILabel! {
        didSet {
            ready.font = ready.font.monospacedDigitFont
        }
    }
    
    // MARK: main
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.shared.notice("using \(AudioPlayer.versionString)")
        Logger.verbose = false
        
        urls.append(contentsOf: loadUrls(resource: "streams"))
        
        streamUrl = initializeUrlPicker(initialSelectedRow: 1)
        
        displayTitleChanged(nil)
        currentProblem(nil)
        durationBuffer(averagedSeconds: nil, currentSeconds: nil)
        durationConnected(nil)
        durationReady(nil)
        durationPlaying(0)
    }
    
    func loadUrls(resource:String) -> [(String,String)]{
        let pathToFile = Bundle.main.path(forResource: resource, ofType: "txt")
        var labelUrls:[(String,String)] = []
        if let path = pathToFile {
            let fileContent = try! String(contentsOfFile: path, encoding: String.Encoding.utf8)
            let dataArray = fileContent.components(separatedBy: "\n")
            for line in dataArray {
                let components = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard components.count == 2 else {
                    continue
                }
                let label=components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let url=components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                labelUrls.append((label,url))
            }
        }
        return labelUrls
    }
    
    fileprivate func createPlayer(_ mediaUrl: String) -> AudioPlayer {
        guard let url = URL.init(string: mediaUrl) else {
            fatalError("cannot create url from \(streamUrl!)")
        }
        return AudioPlayer(mediaUrl: url, listener: self)
    }
    
    fileprivate func initializeUrlPicker(initialSelectedRow: Int) -> String {
        urlPicker.delegate = self
        urlPicker.dataSource = self
        urlPicker.selectRow(initialSelectedRow, inComponent: 0, animated: true)
        return urls[initialSelectedRow].1
    }
    
    
    // MARK: user actions
    
    /// toggle play or stop
    @IBAction func toggle(_ sender: Any) {
        print("toggle called")
        if let state = player?.state, state == .stopped {
            currentProblem(nil)
            durationPlaying(0)
            player?.play()
        } else {
            player?.stop()
        }
    }
    
    /// select station
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        streamUrl = urls[row].1
        Logger.shared.notice("\(urls[row].0) selected")
    }
    

    // MARK: RadioPlayerDelegate
    
    func stateChanged(_ state: PlaybackState) {
        DispatchQueue.main.async {
            Logger.shared.debug("state changed to \(state)")
            switch state {
            case .buffering: self.buffering()
            case .stopped: self.stopped()
            case .playing: self.playing()
            @unknown default:
                Logger.shared.error("state changed to unknown \(state)")
            }
        }
    }
    
    fileprivate func stopped() {
        togglePlay.setTitle("play", for: .normal)
        displayTitleChanged(nil)
    }
    fileprivate func buffering() {
        togglePlay.setTitle("...", for: .normal)
        durationConnected(nil)
        durationReady(nil)
    }
    fileprivate func playing() {
        togglePlay.setTitle("stop", for: .normal)
    }
    
    func displayTitleChanged(_ title:String?) {
        DispatchQueue.main.async {
            if let title = title {
                self.playingTitle.text = title
            } else {
                self.playingTitle.text = ""
            }
        }
    }
    func currentProblem(_ text:String?) {
        DispatchQueue.main.async {
            if let text = text {
                self.problem.text = text
            } else {
                self.problem.text = ""
            }
        }
    }
    func durationBuffer(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let seconds = averagedSeconds {
                self.playbackBufferS.text = String(format: "%.1f s", seconds)
            } else {
                self.playbackBufferS.text = ""
            }
            if let lastS = currentSeconds {
                self.lastBufferS.text = String(format: "%.2f s", lastS)
            } else {
                self.lastBufferS.text = ""
            }
        }
    }
    func durationPlaying(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            guard let playedS = seconds else {
                self.playedS.text = ""
                return
            }
            
            if playedS.isLess(than: 60) {
                self.playedS.text = String(format: "%.1f s", playedS)
                return
            }
            if playedS.isLess(than: 3600) {
                let min = Int(playedS / 60)
                self.playedS.text = String(format: "%dm %02ds", min, Int(playedS - Double(min * 60)))
                return
            }
            let hour = Int(playedS / 3600)
            let min = Int(playedS / 60) - hour * 60
            self.playedS.text = String(format: "%dh %02dm", hour, min)
            return
        }
    }
    
    func durationConnected(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let connectS = seconds {
                self.connected.text = String(format: "%.3f s", connectS)
            } else {
                self.connected.text = ""
            }
        }
    }
    func durationReady(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let readyS = seconds {
                self.ready.text = String(format: "%.3f s", readyS)
            } else {
                self.ready.text = ""
            }
        }
    }
    
    // MARK: UIPicker stuff
    /// select / tap station
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return urls.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return urls[row].0
    }
 
}



fileprivate extension UIFont {
    var monospacedDigitFont: UIFont {
        let newFontDescriptor = fontDescriptor.monospacedDigitFontDescriptor
        return UIFont(descriptor: newFontDescriptor, size: 0)
    }
}

fileprivate extension UIFontDescriptor {
    var monospacedDigitFontDescriptor: UIFontDescriptor {
        let fontDescriptorFeatureSettings = [[UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
                                              UIFontDescriptor.FeatureKey.typeIdentifier: kMonospacedNumbersSelector]]
        let fontDescriptorAttributes = [UIFontDescriptor.AttributeName.featureSettings: fontDescriptorFeatureSettings]
        let fontDescriptor = self.addingAttributes(fontDescriptorAttributes)
        return fontDescriptor
    }
}
