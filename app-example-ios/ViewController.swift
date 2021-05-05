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


class ViewController: UIViewController, AudioPlayerListener {
    
    
    // MARK: ui outlets
    
    @IBOutlet weak var urlPicker: UIPickerView!
    @IBOutlet weak var urlField: UrlField!
    
    @IBOutlet weak var broadcaster: UILabel!
    @IBOutlet weak var genre: UILabel!
    
    @IBOutlet weak var playingTitle: UILabel!
    @IBOutlet weak var problem: UILabel!
    @IBOutlet weak var togglePlay: UIButton!
    @IBOutlet weak var playedSince: UILabel!
    @IBOutlet weak var ready: UILabel!
    @IBOutlet weak var connected: UILabel!
    @IBOutlet weak var bufferAveraged: UILabel!
    @IBOutlet weak var bufferCurrent: UILabel!
    
    
    var player:AudioPlayer?
    var endpoint:MediaEndpoint? {
        didSet {
            if oldValue == endpoint {
                return
            }
            
            Logger.shared.info("endpoint changed to \(endpoint?.uri ?? "(nil)")")
            
            var running = false
            if let player = player, player.state != .stopped {
                running = player.state == .playing
                player.stop()
            }
            genre.text = ""
            broadcaster.text = ""
            togglePlay.isEnabled = endpoint != nil
            
            guard let endpoint = endpoint else {
                return
            }
            
            guard let player = cachedPlayer[endpoint] else {
                newPlayer(endpoint) { (player) in
                    self.player = player
                    if running {
                        self.doToggle(player)
                    }
                    self.cachedPlayer[endpoint] = player
                }
                return
            }
            self.player = player
            if running {
                self.doToggle(player)
            }
        }
    }
    
    private var cachedPlayer:[MediaEndpoint:AudioPlayer] = [:]
    private var uriSelector:MediaSelector?
    
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
        
        urlPicker.delegate = uriSelector
        urlField.delegate = uriSelector
        
        let initialSelectedRow = 1
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
        cachedPlayer.forEach { (endpoint,player) in
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
        
        guard let _ = cachedPlayer[endpoint] else {
            newPlayer(endpoint) {(player) in
                self.player = player
                self.doToggle(player)
                self.cachedPlayer[endpoint] = player
            }
            return
        }
        
        if let player = self.player {
            doToggle(player)
            return
        }
        
        newPlayer(endpoint) { (player) in
            self.player = player
            self.doToggle(player)
            self.cachedPlayer[endpoint] = player
        }
    }
    
    /// edit custom url
    @IBAction func urlEditChanged(_ sender: Any) {
        let valid = uriSelector?.urlEditChanged() ?? true
        togglePlay.isEnabled = valid
    }
    
    fileprivate func newPlayer(_ endpoint:MediaEndpoint, callback: @escaping (AudioPlayer) -> ()) {
        self.togglePlay.isEnabled = false
        self.playingTitle.text = nil
        DispatchQueue.main.async {
            guard let player = endpoint.audioPlayer(listener:  self) else {
                Logger.shared.error("no player for \(endpoint.uri)")
                self.togglePlay.isEnabled = true
                return
            }
            callback(player)
            self.togglePlay.isEnabled = true
        }
        return
    }
    
    fileprivate func doToggle(_ player:AudioPlayer) {

        switch player.state  {
        case .stopped, .pausing:
            self.problem.text = nil
            player.play()
        case .playing:
            player.canPause ? player.pause() : player.stop()
        case .buffering:
            player.stop()
        @unknown default:
            fatalError("unknown player state \(player.state )")
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
        }
    }
    
    // MARK: MediaEndpointListener
    
    
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
    
    let playImage = UIImage(named: "play")!
    let pauseImage = UIImage(named: "pause")!.scale(factor: 0.9)
    let stopImage = UIImage(named: "stop")!.scale(factor: 0.8)
    func stateChanged(_ state: PlaybackState) {
        guard player?.state == state else {
            /// ignore events from the last player
            return
        }
        DispatchQueue.main.async {
            Logger.shared.debug("state changed to \(state)")
            switch state {
            case .stopped:
                self.togglePlay.setTitle("", for: .normal)
                self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)
                
                self.playingTitle.text = ""
                
            case .pausing:
                self.togglePlay.setTitle("", for: .normal)
                self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)
            case .buffering:
                self.togglePlay.setTitle("● ● ●", for: .normal) // \u{25cf} Black Circle
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
