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
    @IBOutlet weak var ready: UILabel!
    @IBOutlet weak var connected: UILabel!
    @IBOutlet weak var bufferAveraged: UILabel!
    @IBOutlet weak var bufferCurrent: UILabel!
    
    @IBOutlet weak var sdkVersion: UILabel!
    @IBOutlet weak var appVersion: UILabel!
    
    
    private var uriSelector:MediaSelector?
    private var channelPicker = UIPickerView()
    private var channelSelector:ChannelSelector?
    private var feedback:UserFeedback?
    
    // MARK: initialization
    
    private var ybrid:YbridControl? { get {
        currentControl as? YbridControl
    }}
    
    private func initializeElements() {
        DispatchQueue.main.async { [self] in
            
            togglePlay.setTitle("", for: .disabled)
            togglePlay.action = Action("toggle", .always, self.toggle)
            
            initialize(button: swapItemButton, image: "swapItem", scale: 0.5, "swap item", behaviour: .single) {
                ybrid?.swapItem{ _ in swapItemButton.completed() }
            }
            

            initialize(button: itemBackwardButton, image: "itemBackward", scale: 0.5, "item backward", behaviour: .multi ) {
                ybrid?.skipBackward()//ItemType.NEWS)
            }
            initialize(button: windBackButton, image: "windBack", scale: 0.4, "wind back", behaviour: .multi) {
                ybrid?.wind(by: -15.0)
            }
            initialize(button: windToLiveButton, image:  "windToLive", scale: 0.9, "wind to live", behaviour: .single ) {
                ybrid?.windToLive{ _ in windToLiveButton.completed() }
            }
            
            initialize(button: windForwardButton, image: "windForward", scale: 0.4, "wind forward", behaviour: .multi) {
                ybrid?.wind(by: +15.0)
            }
            initialize(button: itemForwardButton, image: "itemForward", scale: 0.5, "item forward", behaviour: .multi) {
                ybrid?.skipForward()//ItemType.MUSIC)
            }
            
            initialize(label: problem)
            initialize(label: playedSince, monospaced: true)
            initialize(label: ready, monospaced: true)
            initialize(label: connected, monospaced: true)
            initialize(label: bufferAveraged, monospaced: true)
            initialize(label: bufferCurrent, monospaced: true)
            initialize(label: offsetS, monospaced: true)
            
            appVersion.text = "demo-app\n" + getBundleInfo(id: Bundle.main.bundleIdentifier ?? "io.ybrid.example-player-ios")
            sdkVersion.text = "player-sdk\n" + getBundleInfo(id:"io.ybrid.player-sdk-swift")
        }
    }
    
    private func initialize(label: UILabel, monospaced:Bool = false) {
        if monospaced {
            label.font = label.font.monospacedDigitFont
        }
        label.text = nil
    }
    
    private func initialize(button: ActionButton, image:String, scale:Float, _ actionString:String, behaviour:Action.behaviour, _ action: @escaping () -> () ) {
        let itemImage = UIImage(named: image)!.scale(factor: scale)
        button.setImage(itemImage, for: .normal)
        button.action = Action(actionString, behaviour, action)
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
    
    private func resetValues() {
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
    
    // MARK: endpoint selection
    
    var endpoint:MediaEndpoint? {
        didSet {
            if oldValue == endpoint {
                return
            }
            
            Logger.shared.info("endpoint changed to \(endpoint?.uri ?? "(nil)")")
            
            var oldPlaying = false
            if oldValue != nil, let oldControl = cachedControls[oldValue!], oldControl.state != .stopped {
                oldPlaying = oldControl.state == .playing
                oldControl.stop()
            }
            
            guard let endpoint = endpoint else {
                currentControl = nil
                return
            }
            
            guard let control = cachedControls[endpoint] else {
                newControl(endpoint) { (control) in
                    guard control.mediaEndpoint == self.endpoint else {
                        Logger.shared.notice("aborting \(control.mediaEndpoint.uri)")
                        return
                    }
                    self.currentControl = control
                    if oldPlaying {
                        self.doToggle(control)
                    }
                }
                return
            }
            
            currentControl = control
            if oldPlaying {
                doToggle(control)
            }
        }
    }
    
    private var cachedControls:[MediaEndpoint:PlaybackControl] = [:]
    
    private var currentControl:PlaybackControl? {
        didSet {
            guard let current = currentControl else {
                Logger.shared.notice("control changed to (nil)")
                self.setStopped()
                self.resetValues()
                self.controls(enable: false)
                self.ybridControls(visible: false)
                return
            }
            
            Logger.shared.debug("control changed to \(type(of: current))")
            controls(enable: true)
            if let ybridControl = current as? YbridControl {
                ybridControl.refresh()
                ybridControls(visible: true)
            } else {
                ybridControls(visible: false)
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
        initializeElements()
        
        /// clearing values and states
        resetValues()
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
            Logger.shared.notice("service \(channel ?? "(nil)") selected")
            if let ybrid = self.ybrid,
               let service = channel {
                Logger.shared.debug("swap service to \(service) triggered")
                self.channelSelector?.enable(false)
                ybrid.swapService(to: service) { (changed) in
                    Logger.shared.debug("swap service \(changed ? "" : "not ")completed")
                    self.channelSelector?.enable(true)
                }
            }
        }
        channelPicker.frame = channelPickerFrame.frame
        view.addSubview(channelPicker)
        channelPicker.selectRow(0, inComponent: 0, animated: true)
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
    func toggle() {
        print("toggle called")
        guard let endpoint = endpoint else {
            return
        }
        
        guard let control = cachedControls[endpoint] else {
            newControl(endpoint) {(control) in
                guard control.mediaEndpoint == self.endpoint else {
                    Logger.shared.notice("aborting \(control.mediaEndpoint.uri)")
                    return
                }
                self.currentControl = control
                self.doToggle(control) // run it
            }
            return
        }
        
        doToggle(control)
    }
    
    /// edit custom url
    @IBAction func urlEditChanged(_ sender: Any) {
        let valid = uriSelector?.urlEditChanged() ?? true
        controls(enable: valid)
    }
       
 
    // MARK: helpers acting on ui elements
    
    private func controls(enable:Bool) {
        DispatchQueue.main.async {
            self.togglePlay.isEnabled = enable
            self.windBackButton.isEnabled = enable
            self.windForwardButton.isEnabled = enable
            self.windToLiveButton.isEnabled = enable
            self.itemBackwardButton.isEnabled = enable
            self.itemForwardButton.isEnabled = enable
            self.swapItemButton.isEnabled = enable
            self.channelSelector?.enable(enable)
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
        controls(enable: false)
        ybridControls(visible: false)
        resetValues()
        
        DispatchQueue.global().async {
        do {
            try AudioPlayer.open(for: endpoint, listener: self,
               playbackControl: { (control) in
                if let existingControl = self.cachedControls[endpoint] {
                    Logger.shared.notice("already created control for \(endpoint.uri)")
                    control.close()
                    callback(existingControl)
                    return
                }
                self.cachedControls[endpoint] = control
                callback(control)
               },
               ybridControl: { (ybridControl) in
                if let existingControl = self.cachedControls[endpoint] {
                    Logger.shared.notice("already created control for \(endpoint.uri)")
                    ybridControl.close()
                    callback(existingControl)
                    return
                }
                self.cachedControls[endpoint] = ybridControl
                callback(ybridControl)
               })
        } catch {
            Logger.shared.error("no player for \(endpoint.uri)")
            self.controls(enable: false)
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
    
    func swapsChanged(_ swapsLeft: Int) {
        DispatchQueue.main.async {
            self.swapItemButton.isEnabled = swapsLeft != 0
        }
    }


    // MARK: AudioPlayerListener

    func stateChanged(_ state: PlaybackState) {
        guard currentControl?.state == state else {
            /// ignore events from the last player
            Logger.shared.notice("ignoring \(state), current control is \(String(describing: currentControl?.state))")
            return
        }

        Logger.shared.debug("state changed to \(state)")

        DispatchQueue.main.sync { [self] in
            switch state {
            case .stopped:
                setStopped()
                self.playingTitle.text = nil
            case .pausing:
                setPausing()
            case .buffering:
                setBuffering()
            case .playing:
                setPlaying()
            @unknown default:
                Logger.shared.error("state changed to unknown \(state)")
            }

        }
    }
    private let playImage = UIImage(named: "play")!
    private func setStopped() {
        self.togglePlay.setTitle(nil, for: .normal)
        self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)
    }
    private let pauseImage = UIImage(named: "pause")!.scale(factor: 0.9)
    private let stopImage = UIImage(named: "stop")!.scale(factor: 0.8)
    private func setPlaying() {
        self.togglePlay.setTitle(nil, for: .normal)
        if let control = self.currentControl, control.canPause {
            self.togglePlay.setImage(self.pauseImage, for: UIControl.State.normal)
        } else {
            self.togglePlay.setImage(self.stopImage, for: UIControl.State.normal)
        }
    }
    private func setBuffering() {
        self.togglePlay.setTitle("● ● ●", for: .normal) // \u{25cf} Black Circle
        self.togglePlay.setImage(nil, for: UIControl.State.normal)
    }
    private func setPausing() {
        self.togglePlay.setTitle(nil, for: .normal)
        self.togglePlay.setImage(self.playImage, for: UIControl.State.normal)
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
                self.channelSelector?.setSelection(to: serviceId)
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
