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


class ViewController: UIViewController, AudioPlayerListener, UIPickerViewDelegate, UITextFieldDelegate {
    
    var player:AudioPlayer?
    var mediaUrl:URL? {
        didSet {
            if oldValue == mediaUrl {
                return
            }
            
            Logger.shared.debug("mediaUrl changed to \(mediaUrl?.absoluteString ?? "(nil)")")

            if player?.state != PlaybackState.stopped {
                player?.stop()
            }
            
            noError()
            playingSince(0)
            durationReadyToPlay(nil)
            durationConnected(nil)
            bufferSize(averagedSeconds: nil, currentSeconds: nil)
            
            guard let url = mediaUrl else {
                togglePlay.isEnabled = false
                return
            }
            togglePlay.isEnabled = true
            player = AudioPlayer(mediaUrl: url, listener: self)
//            player?.canPause = true
//            if let playbackUri = player?.session.playbackUri {
//                urlField.text = playbackUri
//            }
        }
    }
    
    // MARK: ui outlets
    
    @IBOutlet weak var urlPicker: UIPickerView!
    @IBOutlet fileprivate weak var urlField: UrlField!
    @IBOutlet weak var playingTitle: UILabel!
    @IBOutlet weak var problem: UILabel!
    @IBOutlet weak var togglePlay: UIButton!
    @IBOutlet weak var playedSince: UILabel!
    @IBOutlet weak var ready: UILabel!
    @IBOutlet weak var connected: UILabel!
    @IBOutlet weak var bufferAveraged: UILabel!
    @IBOutlet weak var bufferCurrent: UILabel!
    
    
    let pickerData = MediaPickerData()
    
    // MARK: main
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Logger.verbose = true
        Logger.shared.notice("using \(AudioPlayer.versionString)")
        
        hideKeyboardWhenTappedAround()
        setStaticFieldAttributes()
        
        urlPicker.delegate = self
        urlField.delegate = self
        
        let initialSelectedRow = 1
        urlPicker.dataSource = pickerData
        urlPicker.selectRow(initialSelectedRow, inComponent: 0, animated: true)
        pickerView(urlPicker, didSelectRow: initialSelectedRow, inComponent: 0)
        
        displayTitleChanged(nil)
        noError()
        playingSince(0)
        durationReadyToPlay(nil)
        durationConnected(nil)
        bufferSize(averagedSeconds: nil, currentSeconds: nil)
    }
    
    override func didReceiveMemoryWarning() {
        Logger.shared.notice()
        if PlayerContext.handleMemoryLimit() {
            Logger.shared.error("player handeled memory limit of \(PlayerContext.memoryLimitMB) MB")
        }
        super.didReceiveMemoryWarning()
    }
    
    private func noError() {
        DispatchQueue.main.async {
            self.problem.text = ""
        }
    }
    
    
    // MARK: user actions
    
    /// toggle play or stop
    @IBAction func toggle(_ sender: Any) {
        print("toggle called")
        guard let player = player else {
            return
        }
        switch player.state  {
        case .stopped, .pausing:
            player.play()
        case .playing:
            player.canPause ? player.pause() : player.stop()
        case .buffering:
            player.stop()
        @unknown default:
            fatalError("unknown player state \(player.state )")
        }
    }
    
    
    /// select station
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selected = pickerData.urls[row]
        Logger.shared.notice("\(selected.label) selected")
        
        DispatchQueue.main.async {
            self.urlField.text = selected.url
            if selected.editable {
                self.urlField.enable(placeholder: "enter URL here")
            } else {
                self.urlField.disable()
            }
            
            if self.urlField.isValidUrl {
                self.mediaUrl = self.urlField.url
            } else {
                self.mediaUrl = nil
                
            }
        }        
    }
    
    /// edit custom url
    @IBAction func urlEditChanged(_ sender: Any) {
        
        guard let text = urlField.text, !text.isEmpty else {
            let row = urlPicker.selectedRow(inComponent: 0)
            pickerData.urls[row].url = ""
            mediaUrl = nil
            return
        }
        
        togglePlay.isEnabled = urlField.isValidUrl
    }
    
    /// end edit url
    func textFieldDidEndEditing(_ textField: UITextField) {
        let row = urlPicker.selectedRow(inComponent: 0)
        
        if urlField.isValidUrl, let url = urlField.url {
            mediaUrl = url
            pickerData.urls[row].url = urlField.text ?? ""
        }
    }
    
    // MARK: initialization
    
    private func setStaticFieldAttributes() {
        DispatchQueue.main.async {
            self.playingTitle.lineBreakMode = .byWordWrapping
            self.playingTitle.numberOfLines = 0
            
            self.togglePlay.setTitleColor(UIColor.gray, for: UIControl.State.disabled)
            self.togglePlay.setImage(self.playImage.withGrayscale, for: UIControl.State.disabled)
            
            self.playedSince.font = self.playedSince.font.monospacedDigitFont
            self.ready.font = self.ready.font.monospacedDigitFont
            self.connected.font = self.connected.font.monospacedDigitFont
            self.bufferAveraged.font = self.bufferAveraged.font.monospacedDigitFont
            self.bufferCurrent.font = self.bufferCurrent.font.monospacedDigitFont
            
            // this is usually enough to see white text color in urlPicker - except fpr iOS 12.4
            // see workaround below (func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: ...)
            self.urlPicker.reloadAllComponents()
        }
    }
    // workaround
    // this is the only way I found to set the color of the url picker entries on iOS 12.4!
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title = pickerData.urls[row].label
        let pickerFont = (playedSince as UILabel).font!
        let myTitle = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font:UIFont(name: pickerFont.fontName, size: pickerFont.pointSize)!,NSAttributedString.Key.foregroundColor:UIColor.white])
        return myTitle
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
    
    let playImage = UIImage(named: "play")!
    let pauseImage = UIImage(named: "pause")!.scale(factor: 0.9)
    let stopImage = UIImage(named: "stop")!.scale(factor: 0.8)
    func stateChanged(_ state: PlaybackState) {
        DispatchQueue.main.async {
            Logger.shared.debug("state changed to \(state)")
            switch state {
            case .stopped:
                self.togglePlay.setTitle("", for: .normal)
                self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)
                
                self.displayTitleChanged(nil)
                
            case .pausing:
                self.togglePlay.setTitle("", for: .normal)
                self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)
            case .buffering:
                self.togglePlay.setTitle(". . .", for: .normal)
                self.togglePlay.setImage(nil, for: UIControl.State.normal)
            case .playing:
                self.togglePlay.setTitle("", for: .normal)
                if let player = self.player, player.canPause {
                    self.togglePlay.setImage(self.pauseImage, for: UIControl.State.normal)
                } else {
                    self.togglePlay.setImage(self.stopImage, for: UIControl.State.normal)
                }
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
}

fileprivate extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
}

struct MediaData {
    let label:String
    var url:String
    var editable:Bool = false
}

class MediaPickerData: NSObject, UIPickerViewDataSource {

    var urls:[MediaData] = [] // radios are added from streams.txt
    let customUrlLabel = "custom URL"
    
    override init() {
        super.init()
        if let pathToFile = Bundle.main.path(forResource: "streams", ofType: "txt") {
            urls.append(contentsOf: loadUrls(path: pathToFile))
        }
        urls.append(MediaData(label:customUrlLabel, url:"", editable: true))
    }
    
    private func loadUrls(path:String) -> [MediaData]{
        var labelUrls:[MediaData] = []
        let fileContent = try! String(contentsOfFile: path, encoding: String.Encoding.utf8)
        let dataArray = fileContent.components(separatedBy: "\n")
        for line in dataArray {
            let components = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard components.count == 2 else {
                continue
            }
            let label=components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let url=components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            labelUrls.append(MediaData(label:label,url:url))
        }
        return labelUrls
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return urls.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return urls[row].label
    }
    
}

fileprivate class UrlField: UITextField {

    func enable(placeholder: String) {
        self.isEnabled = true
        self.backgroundColor = UIColor(white: 0.4, alpha: 0.3 )
        self.textColor = UIColor.white
        self.attributedPlaceholder = NSAttributedString(string:placeholder, attributes: [NSAttributedString.Key.foregroundColor:UIColor.lightGray])
    }
    
    func disable() {
        self.isEnabled = false
        self.backgroundColor = UIColor(white: 0.0, alpha: 0.3 )
        self.textColor = UIColor.gray
    }
    
    var url:URL? { get {
        guard let text = text else {
            return nil
        }
        
        let urlString = text.trimmingCharacters(in: CharacterSet.whitespaces)
                            .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        if let urlEncoded = urlString, let url = URL(string: urlEncoded) {
            return url
        }
        return nil
    }}
    
    var isValidUrl:Bool {
        guard let url = url else { return false }
        if url.pathComponents[0].hasPrefix("icyx") {
            return true
        }
        return UIApplication.shared.canOpenURL(url)
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

extension UIImage {
    var withGrayscale: UIImage {
        guard let ciImage = CIImage(image: self, options: nil) else { return self }
        let paramsColor: [String: AnyObject] = [kCIInputBrightnessKey: NSNumber(value: 0.0), kCIInputContrastKey: NSNumber(value: 1.0), kCIInputSaturationKey: NSNumber(value: 0.0)]
        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: paramsColor)
        guard let processedCGImage = CIContext().createCGImage(grayscale, from: grayscale.extent) else { return self }
        return UIImage(cgImage: processedCGImage, scale: scale, orientation: imageOrientation)
    }

    func scale(factor: Float) -> UIImage {
        let scaledImage = UIImage( cgImage: self.cgImage!, scale: self.scale/CGFloat(factor), orientation: self.imageOrientation)
        return scaledImage
    }
}
