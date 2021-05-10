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

//
// This test class covers the basic use cases of YbridPlayerSDK.
//


import XCTest
import YbridPlayerSDK

struct Platform {
    static var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0
    }
}

class YbridPlayerTests: XCTestCase {

    let opus = URL.init(string:  "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")!
 
    override func setUpWithError() throws {
        if Platform.isSimulator {
            Logger.testing.notice("-- running on simulator")
        } else {
            Logger.testing.notice("-- running on real device")
        }
    }
    var player:AudioPlayer?

    override func tearDownWithError() throws {
        player?.close()
    }
    
    func test01_VersionString() {
        Logger.verbose = true
        let version = AudioPlayer.versionString
        Logger.testing.notice("-- \(version)")
        XCTAssert(version.contains("YbridPlayerSDK"), "should contain 'YbridPlayerSDK'")
    }
    
    func test02_Mp3() {
        Logger.verbose = true
        let url = URL.init(string: "https://stagecast.ybrid.io/swr3/mp3/mid")!
        player = AudioPlayer(mediaUrl: url, listener: nil)
        player?.play()
        _ = wait(until: .playing, maxSeconds: 10)
        sleep(6)
        player?.stop()
        sleep(1)
    }

    func test03_Opus() {
        Logger.verbose = true
        let playerListener = TestAudioPlayerListener()
        player = AudioPlayer(mediaUrl: opus, listener: playerListener)
        player?.play()
        _ = wait(until: .playing, maxSeconds: 10)
        sleep(6)
        player?.stop()
        sleep(1)
    }
    
    
    
    private func wait(until:PlaybackState, maxSeconds:Int) -> Int {
        guard let player = player else { XCTFail("no player"); return -1 }
        var seconds = 0
        while player.state != until && seconds < maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertEqual(until, player.state, "not \(until) within \(maxSeconds) s")
        return seconds
    }
}
