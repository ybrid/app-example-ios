//
// UseYbridPlayerTests.swift
// app-example-sdk-swiftUITests
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

//
// This test class explains how to use YbridPlayerSDK.
//

import XCTest
import YbridPlayerSDK

class UseYbridPlayerTests: XCTestCase {

    override func setUpWithError() throws {
        Logger.verbose = true
    }
 
    // of course you may choose your own radio station here
    let endpoint = MediaEndpoint(mediaUri: "https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid")
   
    /*
    Let the player play your radio.
    
    You should hear sound.
     
    Player actions (play and stop) operate asynchronously.
    Stop may take a second to clean up properly.
    */
    func test01_PlaySomeSeconds() {
        let player = AudioPlayer.open(for: endpoint, listener: nil)!
        player.play()
        sleep(5)
        player.stop()
        sleep(1) // If the process is killed too early you may hear crackling.
    }

    /*
     Let the player play your radio and ensure expected playback states.

     Connecting to the network depends on the infrastructure.
     Getting the player ready to play is rather quick.
     In this test we assume it takes less than 3 seconds all together.
     */
    func test02_PlayerStates() {
        let player = AudioPlayer.open(for: endpoint, listener: nil)!
        XCTAssertEqual(player.state, PlaybackState.stopped)
        player.play()
        XCTAssertEqual(player.state, PlaybackState.buffering)
        sleep(3)
        XCTAssertEqual(player.state, PlaybackState.playing)
        player.stop()
        XCTAssertEqual(player.state, PlaybackState.playing)
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.stopped)
    }

    /*
     Implement audio player listener to be called back.
     Filter console output by '-- ' and watch.

     Make sure the listener stays alive because internally its held as a weak reference.
     */
    let playerListener = TestAudioPlayerListener()
    func test03_ListenToPlayer() {
        let player = AudioPlayer.open(for: endpoint, listener: playerListener)!
        player.play()
        sleep(3)
        player.stop()
        sleep(1) // if not, the player listener may be gone before it recieves stateChanged to '.stopped'
    }

    /*
     You want to see a problem?
     Filter the console output by '-- '
     
     You can always query statusCode for detailed information
     */
    func test04_ErrorWithPlayer() {
        let badEndpoint = MediaEndpoint(mediaUri: "https://cast.ybrid.io/bad/url")
        let player = AudioPlayer.open(for: badEndpoint, listener: playerListener)!
        XCTAssertEqual(0, playerListener.statusCode)
        player.play()
        XCTAssertEqual(0, playerListener.statusCode)
        XCTAssertEqual(player.state, PlaybackState.buffering)
        XCTAssertEqual(0, playerListener.statusCode)
        sleep(1)
        XCTAssertNotEqual(0, playerListener.statusCode)
        XCTAssertEqual(player.state, PlaybackState.stopped)

        XCTAssertEqual(302, playerListener.statusCode) // see code AudioPipeline.ErrorKind.cannotProcessMimeType
    }

    
    /*
     The audio codec opus is supported
     */
    func test05_PlayOpus() {
        let opusEndpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        let player = AudioPlayer.open(for: opusEndpoint, listener: playerListener)!
        player.play()
        sleep(6)
        player.stop()
        sleep(1)
    }
    
    
    /*
     HttpSessions on urls that offer "expected content length != -1"
     to be identified as on demand files. They can be paused.
     Because all actions are asynchronous assertions are 1 second later.
     */
    func test06_OnDemandPlayPausePlayPauseStop() {
        let media = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        let player = AudioPlayer.open(for: media, listener: playerListener)!
        XCTAssertFalse(player.canPause)
        player.play()
        XCTAssertEqual(player.state, PlaybackState.buffering)
        sleep(3)
        XCTAssertTrue(player.canPause)
        XCTAssertEqual(player.state, PlaybackState.playing)
        player.pause()
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.pausing)
        player.play()
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.playing)
        player.pause()
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.pausing)
        player.stop()
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.stopped)
    }
}

