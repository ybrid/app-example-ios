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
    @IBOutlet weak var offsetS: UILabel! { didSet { offsetS.text = nil }}
    @IBOutlet weak var offsetLabel: UILabel!
    @IBOutlet weak var togglePlay: UIButton!
    @IBOutlet weak var playedSince: UILabel! { didSet { playedSince.text = nil }}
    @IBOutlet weak var ready: UILabel! { didSet { ready.text = nil }}
    @IBOutlet weak var connected: UILabel! { didSet { connected.text = nil }}
    @IBOutlet weak var bufferAveraged: UILabel! { didSet { bufferAveraged.text = nil }}
    @IBOutlet weak var bufferCurrent: UILabel! { didSet { bufferCurrent.text = nil }}
    
    private var uriSelector:MediaSelector?
 
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
            genre.text = ""
            broadcaster.text = ""
            togglePlay.isEnabled = endpoint != nil
            
            guard let endpoint = endpoint else {
                currentControl = nil
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
    
    private var cachedControls:[MediaEndpoint:PlaybackControl] = [:]
    
    private var currentControl:PlaybackControl? {
        didSet {
            guard let current = currentControl else {
                Logger.shared.notice("control changed to (nil)")
                DispatchQueue.main.async {
                    self.togglePlay.isEnabled = false
                    self.offsetLabel.isHidden = true
                }
                return
            }
            
            Logger.shared.debug("control changed to \(type(of: current))")
            
            if var ybrid = current as? YbridControl {
                ybrid.listener = self
            
                DispatchQueue.main.async {
                    self.togglePlay.isEnabled = true
                    self.offsetS.isHidden = false
                    self.offsetLabel.isHidden = false
                }
            } else {
                DispatchQueue.main.async {
                    self.togglePlay.isEnabled = true
                    self.offsetS.isHidden = true
                    self.offsetLabel.isHidden = true
                }
            }
        }
    }

    
    // MARK: main
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //        Logger.verbose = true
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
        togglePlay.isEnabled = valid
    }
    
    fileprivate func newControl(_ endpoint:MediaEndpoint, callback: @escaping (PlaybackControl) -> ()) {
        self.togglePlay.isEnabled = false
        self.playingTitle.text = nil
        
        DispatchQueue.global().async {
        do {
            try AudioPlayer.initialize(for: endpoint, listener: self,
               playbackControl: { (control, mediaProtocol) in
                self.cachedControls[endpoint] = control
                self.currentControl = control
                callback(control)
               },
               ybridControl: { (ybridControl) in
                let control = ybridControl as! PlaybackControl
                self.cachedControls[endpoint] = control
                self.currentControl = control
                callback(control)
               })
        } catch {
            Logger.shared.error("no player for \(endpoint.uri)")
            DispatchQueue.main.async {
                self.togglePlay.isEnabled = true
            }
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
    
    let playImage = UIImage(named: "play")!
    let pauseImage = UIImage(named: "pause")!.scale(factor: 0.9)
    let stopImage = UIImage(named: "stop")!.scale(factor: 0.8)
    func stateChanged(_ state: PlaybackState) {
        guard currentControl?.state == state else {
            /// ignore events from the last player
            return
        }
        DispatchQueue.main.sync {
            Logger.shared.debug("state changed to \(state)")
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

    // MARK: initialization
    
    private func setStaticFieldAttributes() {
        DispatchQueue.main.async {
            self.playingTitle.lineBreakMode = .byWordWrapping
            self.playingTitle.numberOfLines = 0
            
            self.togglePlay.setTitleColor(UIColor.gray, for: UIControl.State.disabled)
            self.togglePlay.setImage(self.playImage.withGrayscale, for: UIControl.State.disabled)
            self.togglePlay.setTitle("", for: .disabled)
            
            self.playedSince.font = self.playedSince.font.monospacedDigitFont
            self.ready.font = self.ready.font.monospacedDigitFont
            self.connected.font = self.connected.font.monospacedDigitFont
            self.bufferAveraged.font = self.bufferAveraged.font.monospacedDigitFont
            self.bufferCurrent.font = self.bufferCurrent.font.monospacedDigitFont
        }
    }
    
    // MARK: YbridControlListener
    
    func offsetToLiveChanged() {
        DispatchQueue.main.async {
            if let seconds = (self.currentControl as? YbridControl)?.offsetToLiveS  {
                self.offsetS.text =  seconds.hmsS
            } else {
                self.offsetS.text = nil
            }
        }
    }

    // MARK: AudioPlayerListener
    
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
    var hmsS:String {
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
