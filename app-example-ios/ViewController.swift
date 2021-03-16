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
        // more radios are added from streams.txt
    ]
    
    var player:AudioPlayer?
    var mediaUrl:String? {
        didSet {
            if oldValue != mediaUrl {
                if player?.state != PlaybackState.stopped {
                    player?.stop()
                }
                Logger.shared.debug("url changed to \(mediaUrl!)")
                player = createPlayer(mediaUrl!)
                playingSince(0)
                noError()
            }
        }
    }
    
    // MARK: ui outlets
    
    @IBOutlet weak var urlPicker: UIPickerView!
    @IBOutlet weak var playingTitle: UILabel! {
        didSet {
            playingTitle.lineBreakMode = .byWordWrapping
            playingTitle.numberOfLines = 0
        }
    }
    @IBOutlet weak var problem: UILabel!
    @IBOutlet weak var togglePlay: UIButton!
    @IBOutlet weak var playedSince: UILabel! {
        didSet {
            playedSince.font = playedSince.font.monospacedDigitFont
        }
    }
    @IBOutlet weak var ready: UILabel! {
        didSet {
            ready.font = ready.font.monospacedDigitFont
        }
    }
    @IBOutlet weak var connected: UILabel! {
        didSet {
            connected.font = connected.font.monospacedDigitFont
        }
    }
    @IBOutlet weak var bufferAveraged: UILabel! {
        didSet {
            bufferAveraged.font = bufferAveraged.font.monospacedDigitFont
        }
    }
    @IBOutlet weak var bufferCurrent: UILabel! {
        didSet {
            bufferCurrent.font = bufferCurrent.font.monospacedDigitFont
        }
    }
    
    // MARK: main
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.verbose = true
        Logger.shared.notice("using \(AudioPlayer.versionString)")
        
        urls.append(contentsOf: loadUrls(resource: "streams"))
        
        mediaUrl = initializeUrlPicker(initialSelectedRow: 1)
        
        displayTitleChanged(nil)
        noError()
        playingSince(0)
        durationReadyToPlay(nil)
        durationConnected(nil)
        bufferSize(averagedSeconds: nil, currentSeconds: nil)
        
        // this is usually enough to see white text color in urlPicker - except fpr iOS 12.4
        // see workaround below (func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: ...)
        DispatchQueue.main.async {
            self.urlPicker.reloadAllComponents()
        }
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
            fatalError("cannot create url from \(mediaUrl)")
        }
        return AudioPlayer(mediaUrl: url, listener: self)
    }
    
    fileprivate func initializeUrlPicker(initialSelectedRow: Int) -> String {
        urlPicker.delegate = self
        urlPicker.dataSource = self
        urlPicker.selectRow(initialSelectedRow, inComponent: 0, animated: true)
        DispatchQueue.main.async {
            self.urlPicker.reloadAllComponents()
        }
        return urls[initialSelectedRow].1
    }
    
    
    // MARK: user actions
    
    /// toggle play or stop
    @IBAction func toggle(_ sender: Any) {
        print("toggle called")
        if let state = player?.state, state == .stopped {
            noError()
            playingSince(0)
            player?.play()
        } else {
            player?.stop()
        }
    }
    
    /// select station
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        Logger.shared.notice("\(urls[row].0) selected")
        mediaUrl = urls[row].1
    }
    

    private func noError() {
        self.problem.text = ""
    }
    
    // MARK: AudioPlayerListener
    
    func displayTitleChanged(_ title:String?) {
        DispatchQueue.main.async {
            if let title = title {
                self.playingTitle.text = title
            } else {
                self.playingTitle.text = ""
            }
        }
    }

    func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        DispatchQueue.main.async {
            switch severity {
            case .fatal: self.problem.textColor = .red
                self.problem.text = exception.message ?? exception.failureReason
            case .recoverable: self.problem.textColor = .systemOrange
                self.problem.text = exception.message
            case .notice: self.problem.textColor = .systemGreen
                self.problem.text = exception.message
                DispatchQueue.global().async {
                    sleep(5)
                    DispatchQueue.main.async {
                        self.noError()
                    }
                }
            @unknown default:
                Logger.shared.error("unknown error: severity \(severity), \(exception.localizedDescription)")
            }

        }
    }
    
    func stateChanged(_ state: PlaybackState) {
        DispatchQueue.main.async {
            Logger.shared.debug("state changed to \(state)")
            switch state {
            case .stopped:
                self.togglePlay.setTitle("play", for: .normal)
                self.displayTitleChanged(nil)
            case .buffering:
                self.togglePlay.setTitle("...", for: .normal)
                self.durationConnected(nil)
                self.durationReadyToPlay(nil)
            case .playing:
                self.togglePlay.setTitle("stop", for: .normal)
            @unknown default:
                Logger.shared.error("state changed to unknown \(state)")
            }
        }
    }

    func playingSince(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            guard let playedS = seconds else {
                self.playedSince.text = ""
                return
            }
            
            if playedS.isLess(than: 60) {
                self.playedSince.text = String(format: "%.1f s", playedS)
                return
            }
            if playedS.isLess(than: 3600) {
                let min = Int(playedS / 60)
                self.playedSince.text = String(format: "%dm %02ds", min, Int(playedS - Double(min * 60)))
                return
            }
            let hour = Int(playedS / 3600)
            let min = Int(playedS / 60) - hour * 60
            self.playedSince.text = String(format: "%dh %02dm", hour, min)
            return
        }
    }
    func durationReadyToPlay(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let readyS = seconds {
                self.ready.text = String(format: "%.3f s", readyS)
            } else {
                self.ready.text = ""
            }
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
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let averaged = averagedSeconds {
                self.bufferAveraged.text = String(format: "%.1f s", averaged)
            } else {
                self.bufferAveraged.text = ""
            }
            if let current = currentSeconds {
                self.bufferCurrent.text = String(format: "%.2f s", current)
            } else {
                self.bufferCurrent.text = ""
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
 
    
    // workaround
    // this is the only way I found to set the color of the url picker entries on iOS 12.4!
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let titleData = urls[row].0
        let pickerFont = (playedSince as UILabel).font!
//        Logger.shared.info("playingTitle has font \(pickerFont.fontName) with size \(pickerFont.pointSize)")
        let myTitle = NSAttributedString(string: titleData, attributes: [NSAttributedString.Key.font:UIFont(name: pickerFont.fontName, size: pickerFont.pointSize)!,NSAttributedString.Key.foregroundColor:UIColor.white])
        return myTitle
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
