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


class ViewController: UIViewController, AudioPlayerListener, YbridControlListener {

    // MARK: ui outlets

    @IBOutlet weak var urlPicker: UIPickerView!
    @IBOutlet weak var urlField: UrlField!
    
    @IBOutlet weak var broadcaster: UILabel!
    @IBOutlet weak var genre: UILabel!

    @IBOutlet weak var playingTitle: UILabel!
    @IBOutlet weak var problem: UILabel! { didSet { problem.text = nil }}
    
    @IBOutlet weak var togglePlay: UIButton!
    @IBOutlet weak var swapItemButton: UIButton!
    
    @IBOutlet weak var itemBackwardButton: UIButton!
    @IBOutlet weak var windBackButton: UIButton!
    @IBOutlet weak var windForwardButton: UIButton!
    @IBOutlet weak var windToLiveButton: UIButton!
    @IBOutlet weak var itemForwardButton: UIButton!
    
    @IBOutlet weak var offsetS: UILabel! { didSet { offsetS.text = nil }}
    @IBOutlet weak var offsetLabel: UILabel!
    @IBOutlet weak var playedSince: UILabel! { didSet { playedSince.text = nil }}
    @IBOutlet weak var ready: UILabel! { didSet { ready.text = nil }}
    @IBOutlet weak var connected: UILabel! { didSet { connected.text = nil }}
    @IBOutlet weak var bufferAveraged: UILabel! { didSet { bufferAveraged.text = nil }}
    @IBOutlet weak var bufferCurrent: UILabel! { didSet { bufferCurrent.text = nil }}
    
    private var uriSelector:MediaSelector?
 
    // MARK: initialization
    
    private func setStaticFieldAttributes() {
        DispatchQueue.main.async {
            self.playingTitle.lineBreakMode = .byWordWrapping
            self.playingTitle.numberOfLines = 0
            
            self.togglePlay.setTitle("", for: .disabled)
            
            let swapItemImage = UIImage(named: "swapItem")!.scale(factor: 0.7)
            self.swapItemButton.setImage(swapItemImage, for: .normal)
            let itemBackwardImage = UIImage(named: "itemBackward")!.scale(factor: 0.5)
            self.itemBackwardButton.setImage(itemBackwardImage, for: .normal)
            let windBackImage = UIImage(named: "windBack")!.scale(factor: 0.4)
            self.windBackButton.setImage(windBackImage, for: .normal)
            let windToLiveImage = UIImage(named: "windToLive")!.scale(factor: 0.9)
            self.windToLiveButton.setImage(windToLiveImage, for: .normal)
            let windForwardImage = UIImage(named: "windForward")!.scale(factor: 0.4)
            self.windForwardButton.setImage(windForwardImage, for: .normal)
            let itemForwardImage = UIImage(named: "itemForward")!.scale(factor: 0.5)
            self.itemForwardButton.setImage(itemForwardImage, for: .normal)
            
            self.playedSince.font = self.playedSince.font.monospacedDigitFont
            self.ready.font = self.ready.font.monospacedDigitFont
            self.connected.font = self.connected.font.monospacedDigitFont
            self.bufferAveraged.font = self.bufferAveraged.font.monospacedDigitFont
            self.bufferCurrent.font = self.bufferCurrent.font.monospacedDigitFont
        }
    }
    
    private func resetMonitorings() {
        DispatchQueue.main.async {
            self.broadcaster.text = nil
            self.genre.text = nil
            self.playingTitle.text = nil
            self.problem.text = nil
            self.playingSince(0)
            self.durationReadyToPlay(nil)
            self.durationConnected(nil)
            self.bufferSize(averagedSeconds: nil, currentSeconds: nil)
        }
    }
    
    // MARK: media selection
    
    var endpoint:MediaEndpoint? {
        didSet {
            if oldValue == endpoint {
                return
            }
            
            Logger.shared.info("endpoint changed to \(endpoint?.uri ?? "(nil)")")
            
            var oldPlaying = false
            if oldValue != nil, let oldPlayer = cachedControls[oldValue!], oldPlayer.state != .stopped {
                oldPlaying = oldPlayer.state == .playing
                oldPlayer.stop()
            }
            currentControl = nil
            
            guard let endpoint = endpoint else {
                return
            }
            
            guard let control = cachedControls[endpoint] else {
                newControl(endpoint) { (control) in
                    if oldPlaying {
                        self.doToggle(control)
                    }
                }
                return
            }
            
            currentControl = control
            if oldPlaying {
                self.doToggle(control)
            }
        }
    }
    
    
   // MARK: media controls
    
    private var cachedControls:[MediaEndpoint:PlaybackControl] = [:]
    
    private var currentControl:PlaybackControl? {
        didSet {
            guard let current = currentControl else {
                Logger.shared.notice("control changed to (nil)")
                DispatchQueue.main.async {
                    self.resetMonitorings()
                    self.togglePlay.setTitle(nil, for: .normal)
                    self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)
                    self.playbackControls(enable: false)
                    self.timeshift(visible: false)
                }
                return
            }
            
            Logger.shared.debug("control changed to \(type(of: current))")
            DispatchQueue.main.async {
                self.playbackControls(enable: true)
                self.timeshift(visible: current is YbridControl)
            }
        }
    }

    
    // MARK: main
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
                Logger.verbose = true
        Logger.shared.notice("using \(AudioPlayer.versionString)")

        
        uriSelector = MediaSelector(urlPicker: urlPicker, urlField: urlField, endpoint: { (endpoint) in
            self.endpoint = endpoint
        })
        
        hideKeyboardWhenTappedAround()
        setStaticFieldAttributes()
        self.view.layoutIfNeeded()
        
        urlPicker.delegate = uriSelector
        urlField.delegate = uriSelector
        
        let initialSelectedRow = 0
        urlPicker.dataSource = uriSelector?.pickerData
        urlPicker.selectRow(initialSelectedRow, inComponent: 0, animated: true)
        uriSelector?.pickerView(urlPicker, didSelectRow: initialSelectedRow, inComponent: 0)
        
        
        resetMonitorings()
        timeshift(visible: false)
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
        cachedControls.forEach { (endpoint,player) in
            Logger.shared.info("closing player for endpoint \(endpoint.uri)")
            player.close()
        }
    }

    
    // MARK: user actions
    
    /// toggle play or stop
    @IBAction func toggle(_ sender: Any) {
        print("toggle called")
        guard let endpoint = endpoint else {
            return
        }
        
        guard let controller = cachedControls[endpoint] else {
            newControl(endpoint) {(controller) in
                self.doToggle(controller) // run it
            }
            return
        }
        
        doToggle(controller)
    }
    
    /// edit custom url
    @IBAction func urlEditChanged(_ sender: Any) {
        let valid = uriSelector?.urlEditChanged() ?? true
        playbackControls(enable: valid)
    }
    

    @IBAction func swapItem(_ sender: Any) {
        print("swap item called")
        guard let ybrid = currentControl as? YbridControl else {
            return
        }
        ybrid.swapItem()
    }
    
    @IBAction func windBack(_ sender: Any) {
        print("wind back called")
        guard let ybrid = currentControl as? YbridControl else {
            return
        }
        ybrid.wind(by: -15.0)
    }
    
    @IBAction func windForward(_ sender: Any) {
        print("wind forward called")
        guard let ybrid = currentControl as? YbridControl else {
            return
        }
        ybrid.wind(by: 15.0)
    }

    
    @IBAction func windToLive(_ sender: Any) {
        print("wind to live called")
        guard let ybrid = currentControl as? YbridControl else {
            return
        }
        ybrid.windToLive()
    }

    @IBAction func itemBackward(_ sender: Any) {
        print("item backward called")
        guard let ybrid = currentControl as? YbridControl else {
            return
        }
        ybrid.skipBackward(nil)//ItemType.NEWS)
    }
    @IBAction func itemForward(_ sender: Any) {
        print("item forward called")
        guard let ybrid = currentControl as? YbridControl else {
            return
        }
        ybrid.skipForward(nil)//ItemType.MUSIC)
    }

    // MARK: helpers
    
    private func playbackControls(enable:Bool) {
//        let running = (currentControl?.state == .playing || currentControl?.state == .buffering)
        DispatchQueue.main.async {
            self.togglePlay.isEnabled = enable
            self.windBackButton.isEnabled = enable //&& running
            self.windForwardButton.isEnabled = enable //&& running
            self.windToLiveButton.isEnabled = enable //&& running
            self.itemBackwardButton.isEnabled = enable
            self.itemForwardButton.isEnabled = enable
        }
    }
    
    private func timeshift(visible:Bool) {
        let hidden = !visible
        DispatchQueue.main.async {
            self.offsetS.isHidden = hidden
            self.offsetLabel.isHidden = hidden
            self.windBackButton.isHidden = hidden
            self.windToLiveButton.isHidden = hidden
            self.windForwardButton.isHidden = hidden
            self.itemBackwardButton.isHidden = hidden
            self.itemForwardButton.isHidden = hidden
        }
    }
    
    fileprivate func newControl(_ endpoint:MediaEndpoint, callback: @escaping (PlaybackControl) -> ()) {
        self.playbackControls(enable: false)
        self.playingTitle.text = nil
        
        DispatchQueue.global().async {
        do {
            try AudioPlayer.open(for: endpoint, listener: self,
               playbackControl: { (control) in
                self.cachedControls[endpoint] = control
                self.currentControl = control
                callback(control)
               },
               ybridControl: { (ybridControl) in
                self.cachedControls[endpoint] = ybridControl
                self.currentControl = ybridControl
                callback(ybridControl)
               })
        } catch {
            Logger.shared.error("no player for \(endpoint.uri)")
            self.playbackControls(enable: false)
            return
        }}
    }
    
    fileprivate func doToggle(_ player:PlaybackControl) {

        switch player.state  {
        case .stopped, .pausing:
            DispatchQueue.main.async {
                self.problem.text = nil
            }
            player.play()
        case .playing:
            player.canPause ? player.pause() : player.stop()
        case .buffering:
            player.stop()
        @unknown default:
            fatalError("unknown player state \(player.state )")
        }
    }
    
    
    // MARK: YbridControlListener
    
    func offsetToLiveChanged(_ offset:TimeInterval?) {
        DispatchQueue.main.async {
            if let seconds = offset {
                self.offsetS.text =  seconds.hmmssS
            } else {
                self.offsetS.text = nil
            }
        }
    }

    // MARK: AudioPlayerListener
    private let playImage = UIImage(named: "play")!
    private let pauseImage = UIImage(named: "pause")!.scale(factor: 0.9)
    private let stopImage = UIImage(named: "stop")!.scale(factor: 0.8)
    func stateChanged(_ state: PlaybackState) {
        guard currentControl?.state == state else {
            /// ignore events from the last player
            return
        }

        DispatchQueue.main.sync {
            Logger.shared.debug("state changed to \(state)")
            self.playbackControls(enable: true)
            
            switch state {
            case .stopped:
                self.togglePlay.setTitle(nil, for: .normal)
                self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)

                self.playingTitle.text = ""
            case .pausing:
                self.togglePlay.setTitle(nil, for: .normal)
                self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)
            case .buffering:
                self.togglePlay.setTitle("● ● ●", for: .normal) // \u{25cf} Black Circle
                self.togglePlay.setImage(nil, for: UIControl.State.normal)
            case .playing:
                self.togglePlay.setTitle(nil, for: .normal)
                if let control = self.currentControl, control.canPause {
                    self.togglePlay.setImage(self.pauseImage, for: UIControl.State.normal)
                } else {
                    self.togglePlay.setImage(self.stopImage, for: UIControl.State.normal)
                }
            @unknown default:
                Logger.shared.error("state changed to unknown \(state)")
            }

        }
    }
    
    func metadataChanged(_ metadata:Metadata) {
        DispatchQueue.main.async {
            if let title = metadata.displayTitle {
                self.playingTitle.text = title
            } else {
                self.playingTitle.text = ""
            }
            
            if let station = metadata.station {
                self.broadcaster.text = station.name
                self.genre.text = station.genre
            } else {
                self.broadcaster.text = ""
                self.genre.text = ""
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
                        self.problem.text = ""
                    }
                }
            @unknown default:
                Logger.shared.error("unknown error: severity \(severity), \(exception.localizedDescription)")
            }
        }
    }
    
     
    func playingSince(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            guard let playedS = seconds else {
                self.playedSince.text = ""
                return
            }
            self.playedSince.text = playedS.hmsS
        }
    }

    
    func durationReadyToPlay(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let readyS = seconds {
                self.ready.text = readyS.sSSS
            } else {
                self.ready.text = ""
            }
        }
    }
    func durationConnected(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let connectS = seconds {
                self.connected.text = connectS.sSSS
            } else {
                self.connected.text = ""
            }
        }
    }
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let averaged = averagedSeconds {
                self.bufferAveraged.text = averaged.sS
            } else {
                self.bufferAveraged.text = ""
            }
            if let current = currentSeconds {
                self.bufferCurrent.text = current.sSS
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
