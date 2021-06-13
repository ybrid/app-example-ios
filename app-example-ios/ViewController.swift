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
    
    @IBOutlet weak var channelPickerFrame: UIButton!
    @IBOutlet weak var togglePlay: UIButton!
    @IBOutlet weak var swapItemButton: UIButton!
    
    @IBOutlet weak var itemBackwardButton: UIButton!
    @IBOutlet weak var windBackButton: UIButton!
    @IBOutlet weak var windForwardButton: UIButton!
    @IBOutlet weak var windToLiveButton: UIButton!
    @IBOutlet weak var itemForwardButton: UIButton!
    
    @IBOutlet weak var offsetS: UILabel!
    @IBOutlet weak var offsetLabel: UILabel!
    @IBOutlet weak var playedSince: UILabel!
    @IBOutlet weak var ready: UILabel!
    @IBOutlet weak var connected: UILabel!
    @IBOutlet weak var bufferAveraged: UILabel!
    @IBOutlet weak var bufferCurrent: UILabel!
    
    @IBOutlet weak var sdkVersion: UILabel!
    @IBOutlet weak var appVersion: UILabel!
    
    
    private var uriSelector:MediaSelector?
    var channelPicker = UIPickerView()
    private var channelSelector:ChannelSelector?
    
    private var feedback:UserFeedback?
    
    // MARK: initialization
    
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
    
    private func setStaticFieldAttributes() {
        DispatchQueue.main.async { [self] in
            
            sdkVersion.text = "sdk\n" + getBundleInfo(id:"io.ybrid.player-sdk-swift")
            
            appVersion.text = "app\n" + getBundleInfo(id: Bundle.main.bundleIdentifier ?? "io.ybrid.example-player-ios")
            
            togglePlay.setTitle("", for: .disabled)
            
            let swapItemImage = UIImage(named: "swapItem")!.scale(factor: 0.5)
            swapItemButton.setImage(swapItemImage, for: .normal)
            let itemBackwardImage = UIImage(named: "itemBackward")!.scale(factor: 0.5)
            itemBackwardButton.setImage(itemBackwardImage, for: .normal)
            let windBackImage = UIImage(named: "windBack")!.scale(factor: 0.4)
            windBackButton.setImage(windBackImage, for: .normal)
            let windToLiveImage = UIImage(named: "windToLive")!.scale(factor: 0.9)
            windToLiveButton.setImage(windToLiveImage, for: .normal)
            let windForwardImage = UIImage(named: "windForward")!.scale(factor: 0.4)
            windForwardButton.setImage(windForwardImage, for: .normal)
            let itemForwardImage = UIImage(named: "itemForward")!.scale(factor: 0.5)
            itemForwardButton.setImage(itemForwardImage, for: .normal)
            
            initialize(label: playedSince, monospaced: true)
            initialize(label: ready, monospaced: true)
            initialize(label: connected, monospaced: true)
            initialize(label: bufferAveraged, monospaced: true)
            initialize(label: bufferCurrent, monospaced: true)
            initialize(label: offsetS, monospaced: true)
        }
    }
    
    private func initialize(label: UILabel, monospaced:Bool = false) {
        if monospaced {
            label.font = label.font.monospacedDigitFont
        }
        label.text = nil
    }
    
    private func resetMonitorings() {
        DispatchQueue.main.async { [self] in
            broadcaster.text = nil
            genre.text = nil
            playingTitle.text = nil
            problem.text = nil
            playingSince(0)
            durationReadyToPlay(nil)
            durationConnected(nil)
            bufferSize(averagedSeconds: nil, currentSeconds: nil)
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
                    self.ybridControls(visible: false)
                    
                }
                return
            }
            
            Logger.shared.debug("control changed to \(type(of: current))")
            DispatchQueue.main.async {
                self.playbackControls(enable: true)
                if let ybridControl = current as? YbridControl {
                    self.ybridControls(visible: true)
                    ybridControl.select()
                } else {
                    self.ybridControls(visible: false)
                }
                    
            }
        }
    }

    // MARK: main
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        Logger.verbose = true
        Logger.shared.notice("using \(AudioPlayer.versionString)")

        hideKeyboardWhenTappedAround()
        view.layoutIfNeeded()
        
        /// setting states of  fields
        setStaticFieldAttributes()
        resetMonitorings()
        ybridControls(visible: false)
        
        /// picking preset media or custom url
        uriSelector = MediaSelector(urlPicker: urlPicker, urlField: urlField) { (endpoint) in
            self.endpoint = endpoint
        }
        let initialSelectedRow = 0
        urlPicker.selectRow(initialSelectedRow, inComponent: 0, animated: true)
        uriSelector?.pickerView(urlPicker, didSelectRow: initialSelectedRow, inComponent: 0)
        
        /// picking the first service of ybrid bucket
        channelSelector = ChannelSelector(channelPicker, font: (urlField as UITextField).font!) { (channel) in
            Logger.shared.notice("channel \(channel ?? "(nil)") selected")
            if let ybrid = self.currentControl as? YbridControl,
               let service = channel {
                ybrid.swapService(to: service)
            }
        }
        channelPicker.
        channelPicker.frame = channelPickerFrame.frame
        view.addSubview(channelPicker)
        channelPicker.selectRow(0, inComponent: 0, animated: true)

        if #available(iOS 10.0, *) {
            feedback = UserFeedback()
        }
//        YbridAudioPlayer.acousticInteractionFeedback = true
//        Ramp.active = true
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

    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        channelPicker.frame = channelPickerFrame.frame
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
       
    // touch down
    
    @IBAction func swapItemTouchDown(_ sender: Any) {
        feedback?.haptic()
    }
    @IBAction func itemBackTouchDown(_ sender: Any) {
        feedback?.haptic()
    }
    @IBAction func windBackTouchDown(_ sender: Any) {
        feedback?.haptic()
    }
    @IBAction func windToLiveTouchDown(_ sender: Any) {
        feedback?.haptic()
    }
    @IBAction func windForwardTouchDown(_ sender: Any) {
        feedback?.haptic()
    }
    @IBAction func itemForwardTouchDown(_ sender: Any) {
        feedback?.haptic()
    }
    
    // touch up
    
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
            self.swapItemButton.isEnabled = enable
        }
    }
    
    private func ybridControls(visible:Bool) {
        let hidden = !visible
        DispatchQueue.main.async {
            self.offsetS.isHidden = hidden
            self.offsetLabel.isHidden = hidden
            self.windBackButton.isHidden = hidden
            self.windToLiveButton.isHidden = hidden
            self.windForwardButton.isHidden = hidden
            self.itemBackwardButton.isHidden = hidden
            self.itemForwardButton.isHidden = hidden
            self.swapItemButton.isHidden = hidden
            self.channelPicker.isHidden = hidden
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
    
    func servicesChanged(_ services: [Service]) {
        self.channelSelector?.setChannels(ids: services.map{ $0.identifier })
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

                self.playingTitle.text = nil
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
            if self.currentControl?.state != .stopped,
               let title = metadata.displayTitle {
                self.playingTitle.text = title
            } else {
                self.playingTitle.text = nil
            }
            
            if let station = metadata.station {
                self.broadcaster.text = station.name
                self.genre.text = station.genre
            } else {
                self.broadcaster.text = nil
                self.genre.text = nil
            }

            if let serviceId = metadata.activeService?.identifier {
                self.channelSelector?.set(serviceId)
            }
        }
    }
    
    func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        DispatchQueue.main.async { [self] in
            switch severity {
            case .fatal: problem.textColor = .red
                problem.text = exception.message ?? exception.failureReason
            case .recoverable: problem.textColor = .systemOrange
                problem.text = exception.message
                DispatchQueue.global().async {
                    sleep(5)
                    DispatchQueue.main.async {
                        problem.text = nil
                    }
                }
            case .notice: problem.textColor = .systemGreen
                problem.text = exception.message
                DispatchQueue.global().async {
                    sleep(5)
                    DispatchQueue.main.async {
                        problem.text = nil
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
                self.playedSince.text = nil
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
                self.ready.text = nil
            }
        }
    }
    func durationConnected(_ seconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let connectS = seconds {
                self.connected.text = connectS.sSSS
            } else {
                self.connected.text = nil
            }
        }
    }
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        DispatchQueue.main.async {
            if let averaged = averagedSeconds {
                self.bufferAveraged.text = averaged.sS
            } else {
                self.bufferAveraged.text = nil
            }
            if let current = currentSeconds {
                self.bufferCurrent.text = current.sSS
            } else {
                self.bufferCurrent.text = nil
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
