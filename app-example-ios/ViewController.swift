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


class ViewController: UIViewController {

    // MARK: ui outlets

    @IBOutlet weak var metadataArea: MetadataItems!
    @IBOutlet weak var urlPicker: UIPickerView!
    @IBOutlet weak var urlField: UrlField!
    @IBOutlet weak var broadcaster: UILabel!
    @IBOutlet weak var genre: UILabel!

    @IBOutlet weak var playingTitle: UILabel!
    @IBOutlet weak var problem: UILabel!
    
    @IBOutlet weak var channelPickerFrame: UIButton!
    @IBOutlet weak var togglePlay: ActionButton!
    @IBOutlet weak var swapItemButton: ActionButton!
    
    @IBOutlet weak var itemBackwardButton: ActionButton!
    @IBOutlet weak var windBackButton: ActionButton!
    @IBOutlet weak var windForwardButton: ActionButton!
    @IBOutlet weak var windToLiveButton: ActionButton!
    @IBOutlet weak var itemForwardButton: ActionButton!

    @IBOutlet weak var offsetS: UILabel!
    @IBOutlet weak var offsetLabel: UILabel!
    @IBOutlet weak var playedSince: UILabel!
    @IBOutlet weak var playingSinceLabel: UILabel!
    
    @IBOutlet weak var maxRateSlider: UISlider!
    @IBOutlet weak var maxRateLabel: UILabel!
    @IBOutlet weak var currentBitRate: UILabel!
    @IBOutlet weak var currentBitRateLabel: UILabel!
    
    @IBOutlet weak var ready: UILabel!
    @IBOutlet weak var readyLabel: UILabel!
    @IBOutlet weak var connected: UILabel!
    @IBOutlet weak var connectedLabel: UILabel!
    


    @IBOutlet weak var bufferCurrent: UILabel!
    @IBOutlet weak var bufferCurrentLabel: UILabel!
    @IBOutlet weak var bufferAveraged: UILabel!
    @IBOutlet weak var bufferAveragedLabel: UILabel!
    
    @IBOutlet weak var sdkVersion: UILabel!
    @IBOutlet weak var appVersion: UILabel!
    
    private var uriSelector:MediaSelector?


    // MARK: media endpoint selection
    
    var endpoint:MediaEndpoint? {
        didSet {
            if oldValue == endpoint {
                return
            }
            
            Logger.shared.info("endpoint changed to \(endpoint?.uri ?? "(nil)")")
            
            DispatchQueue.main.async {
                self.problem.text = nil
            }
            guard let endpoint = endpoint else {
                audioController?.control = nil
                return
            }
            
            audioController?.useControl(endpoint){_ in }
        }
    }
    
    var audioController:AudioController?
    
    // MARK: main method
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //  Logger.verbose = true
        
        view.layoutIfNeeded()
        hideKeyboardWhenTappedAround()
        
        initializeGui()
        initializeActions()
        audioController = AudioController(view: self)
        
        /// picking preset media or custom url
        uriSelector = MediaSelector(urlPicker: urlPicker, urlField: urlField) { (endpoint) in
            self.endpoint = endpoint
        }
        let initialSelectedRow = 0
        urlPicker.selectRow(initialSelectedRow, inComponent: 0, animated: true)
        uriSelector?.pickerView(urlPicker, didSelectRow: initialSelectedRow, inComponent: 0)
    }
    
    override func didReceiveMemoryWarning() {
        Logger.shared.notice()
        if PlayerContext.handleMemoryLimit() {
            Logger.shared.error("player handeled memory limit of \(PlayerContext.memoryLimitMB) MB")
        }
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioController?.cachedControls.forEach { (endpoint,player) in
            Logger.shared.info("closing player for endpoint \(endpoint.uri)")
            player.close()
        }
    }

    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        audioController?.interactions.channelPicker.frame = channelPickerFrame.frame
    }
    
    // MARK: on pressing play/stop/pause
    
    func doToggle() {

        guard let endpoint = endpoint else {
            Logger.shared.error("no endpoint to toggle")
            return
        }
        
        if let control = audioController?.control,
           !control.running {
            DispatchQueue.main.async {
                self.problem.text = nil
            }
        }
        
        audioController?.useControl(endpoint) {(control) in
            guard control.mediaEndpoint == self.endpoint else {
                Logger.shared.notice("aborting \(control.mediaEndpoint.uri)")
                return
            }
            self.audioController?.toggle()
        }
        return
    }
    
    // MARK: user actions
    
    /// edit custom url
    @IBAction func urlEditChanged(_ sender: Any) {
        let valid = uriSelector?.urlEditChanged() ?? true
        audioController?.interactions.enable(valid)
    }

    @IBAction func maxBitRateSelected(_ sender: Any) {
         
        let selectedRate =  bitRatesRange.lowerBound + Int32(maxRateSlider.value * Float(bitRatesRange.upperBound -  bitRatesRange.lowerBound))
 
        Logger.shared.debug("selected bit-rate is \(selectedRate)")
        audioController?.ybrid?.maxBitRate(to: selectedRate)
    }
    
    
    private let playImage = UIImage(named: "play")!
    private let pauseImage = UIImage(named: "pause")!.scale(factor: 0.9)
    private let stopImage = UIImage(named: "stop")!.scale(factor: 0.8)
    func setStopped() {
        changeButton(togglePlay, image:playImage)
    }
    func setPlaying(canPause:Bool) {
        changeButton(togglePlay, image: (canPause ? pauseImage : stopImage))
    }
    func setBuffering() {
        // \u{25cf} Black Circle
        changeButton(togglePlay, text:"● ● ●")
    }
    func setPausing() {
        changeButton(togglePlay, image:playImage)
    }
    
    // MARK: initializations
    
    private func initializeActions() {
        togglePlay.action = Action("toggle", .always) {
            self.doToggle()
        }
        
        DispatchQueue.main.async { [self] in
            initialize(button: swapItemButton, image: "swapItem", scale: 0.5, "swap item", behaviour: .single) {
                audioController?.ybrid?.swapItem{ _ in swapItemButton.completed() }
            }
            initialize(button: itemBackwardButton, image: "itemBackward", scale: 0.5, "item backward", behaviour: .multi ) {
                enableOffset(false)
                audioController?.ybrid?.skipBackward() { _ in enableOffset(true) }
            }
            initialize(button: windBackButton, image: "windBack", scale: 0.4, "wind back", behaviour: .multi) {
                enableOffset(false)
                audioController?.ybrid?.wind(by: -15.0) { _ in enableOffset(true) }
            }
            initialize(button: windToLiveButton, image:  "windToLive", scale: 0.9, "wind to live", behaviour: .single ) {
                enableOffset(false)
                audioController?.ybrid?.windToLive{ _ in windToLiveButton.completed(); enableOffset(true) }
            }
            initialize(button: windForwardButton, image: "windForward", scale: 0.4, "wind forward", behaviour: .multi) {
                enableOffset(false)
                audioController?.ybrid?.wind(by: +15.0) { _ in self.enableOffset(true) }
            }
            initialize(button: itemForwardButton, image: "itemForward", scale: 0.5, "item forward", behaviour: .multi) {
                enableOffset(false)
                audioController?.ybrid?.skipForward() { _ in self.enableOffset(true) }
            }
        }
    }
    
    private func initializeGui() {
        
        setStopped()
        
        DispatchQueue.main.async { [self] in
            
            initialize(label: problem)
            initialize(label: playedSince, monospaced: true)
            initialize(label: ready, monospaced: true)
            initialize(label: connected, monospaced: true)
            initialize(label: bufferAveraged, monospaced: true)
            initialize(label: bufferCurrent, monospaced: true)
            initialize(label: offsetS, monospaced: true)
            initialize(label: currentBitRate, monospaced: true)

            appVersion.text = "demo-app\n" + getBundleInfo(id: Bundle.main.bundleIdentifier ?? "io.ybrid.example-player-ios")
            sdkVersion.text = "player-sdk\n" + getBundleInfo(id:"io.ybrid.player-sdk-swift")
        }
    }
    
    // MARK: helpers
    
    private func initialize(label: UILabel, monospaced:Bool = false) {
        if monospaced {
            label.font = label.font.monospacedDigitFont
        }
        label.text = nil
    }
    private func getBundleInfo(id:String) -> String {
        guard let bundle = Bundle(identifier: id) else {
            Logger.shared.error("no bundle with id \(id)")
            return "(no bundle)"
        }
        guard let info = bundle.infoDictionary else {
            Logger.shared.error("no dictionary for bundle id \(id)")
            return "(no info)"
        }
        Logger.shared.debug("infoDictionary is '\(info)'")
        
        let version = info["CFBundleShortVersionString"] as! String
        let name = info["CFBundleName"] as! String
        let build = info["CFBundleVersion"] as! String
        Logger.shared.info("using \(name) \(version) (build \(build))")
        
        return "\(version) (\(build))"
    }
    
    private func initialize(button: ActionButton, image:String, scale:Float, _ actionString:String, behaviour:Action.behaviour, _ action: @escaping () -> () ) {
        let itemImage = UIImage(named: image)!.scale(factor: scale)
        button.setImage(itemImage, for: .normal)
        button.action = Action(actionString, behaviour, action)
    }
    
    private func changeButton(_ button:UIButton, image:UIImage) {
        DispatchQueue.main.async {
            button.setImage(image, for: .normal)
            button.setImage(image.withGrayscale, for: .disabled)
            button.setTitle(nil, for: .normal)
            button.setTitle(nil, for: .disabled)
        }
    }
    
    private func changeButton(_ button:UIButton, text:String) {
        DispatchQueue.main.async {
            button.setImage(nil, for: .normal)
            button.setImage(nil, for: .disabled)
            button.setTitle(text, for: .normal)
            button.setTitle(text, for: .disabled)
        }
    }
    

    // MARK: helpers acting on ui elements
    
    func enableOffset(_ enable:Bool) {
        /// Disabled visualization for timeshifts by doing nothing here.
        /// unitl points in time for audioComplete are more reliable.
//        DispatchQueue.main.async {
//            self.offsetS.alpha = enable ? 1.0 : 0.5
//        }
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

extension TimeInterval {
    var hmsSManually:String {
        if isLess(than: 60) {
            return String(format: "%.1f s", self)
        }
        if isLess(than: 3600) {
            let min = Int(self / 60)
            return String(format: "%dm %02ds", min, Int(self - Double(min * 60)))
        }
        let hour = Int(self / 3600)
        let min = Int(self / 60) - hour * 60
        return String(format: "%dh %02dm", hour, min)
    }
    
    var hmsS:String {
        let date = Date(timeIntervalSince1970: self)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC+00")
        if isLess(than: 60) {
            formatter.dateFormat = "s.S' s'"
        } else if isLess(than: 3600) {
            formatter.dateFormat = "m'm 'ss's'"
        } else {
            formatter.dateFormat = "h'h 'mm'm'"
        }
        return formatter.string(from: date)
    }
    
    var hmmssS:String {
        let date = Date(timeIntervalSince1970: -self)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC+00")
        formatter.dateFormat = "-H:mm:ss.S"
        return formatter.string(from: date)
    }
    
    var sSSS:String {
        return String(format: "%.3f s", self)
    }
    
    var sSS:String {
        return String(format: "%.2f s", self)
    }
    
    var sS:String {
        return String(format: "%.1f s", self)
    }
}
