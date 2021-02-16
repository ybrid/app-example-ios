//
// YbridPlayerTests.swift
// app-example-iosUITests
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

import XCTest
import YbridPlayerSDK

extension UIDevice {
    static var isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()
}

struct Platform {

    static var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0
    }

}

class YbridPlayerTests: XCTestCase {

    let url = URL.init(string: "https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid")!
    let opus = URL.init(string:  "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")!
    
 

    override func setUpWithError() throws {
        if Platform.isSimulator {
            Logger.testing.notice("-- running on simulator")
        } else {
            Logger.testing.notice("-- running on real device")
        }
        /*
        if #available(iOS 10, macOS 10.12, *) {
             let app = XCUIApplication(bundleIdentifier: "io.ybrid.app-example-ios")
//            let app = XCUIApplication(bundleIdentifier: "app-example-iosUITests")
            let state = describeApplicationState(app.state)
            Logger.testing.notice("-- state of \(app.description) is \(state)")
            app.activate()
            Logger.testing.notice("-- state is \(describeApplicationState(app.state))")
            }
        */
    }
    
    @available(iOS 10, macOS 10.12, *)
    func describeApplicationState( _ state: XCUIApplication.State ) -> String {
        let result:String
        switch (state.rawValue) {
        case 0: result = "unknown"
        case 1: result = "notRunning"
        case 2: result = "runningBackgroundSuspended"
        case 3: result = "runningBackground"
        case 4: result = "runningForeground"
        default:  result = "(undefined)"
        }
        return result
    }
    

    
    func test00_VersionString() {
        Logger.verbose = true
        let version = AudioPlayer.versionString
        Logger.testing.notice("-- \(version)")
        XCTAssert(version.contains("YbridPlayerSDK"), "shoud contain YbridPlayerSDK")
    }
    
    func test01_Mp3() {
        Logger.verbose = true
        let player = AudioPlayer(mediaUrl: url, listener: nil)
        player.play()
        sleep(5)
        player.stop()
        sleep(1)
    }

    func test02_Opus() {
        Logger.verbose = false
        let player = AudioPlayer(mediaUrl: opus, listener: nil)
        player.play()
        sleep(5)
        player.stop()
        sleep(1)
    }

}
