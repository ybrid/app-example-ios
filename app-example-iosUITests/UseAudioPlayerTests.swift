//
// UseAudioPlayerTests.swift
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

class UseAudioPlayerTests: XCTestCase {

    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        /// could log additional debug information in this tests
//        Logger.verbose = true
        
        playerListener.reset()
        
        /// recieving a player control is asynchrounous. So ending tests need to be synchronihzes manually.
        semaphore = DispatchSemaphore(value: 0)
    }
    override func tearDownWithError() throws {
        /// wait for signal() to end test
        _ = semaphore?.wait(timeout: .distantFuture)
    }
 
    /// of course you may choose your own radio station here
    let myEndpoint = MediaEndpoint(mediaUri: "https://democast.ybrid.io/adaptive-demo")
   

    /// see test03 and followings
    let playerListener = TestAudioPlayerListener()
    
    /*
    Let the player play your radio. You should hear sound.
     
    You act on the player control that is passed to you asynchronously.
     
    Player actions (play and stop) operate asynchronously.
    Stop could need a second to clean up. Otherwise it may not sound nice.
    */
    func test01_PlaySomeSeconds() throws {
        try AudioPlayer.open(for: myEndpoint, listener: nil) {
            (control) in
            
            control.play()
            sleep(6)
            control.stop() /// If the process is killed without stop()
            sleep(1) /// or immediately after stop you may hear crackling.
            
            self.semaphore?.signal() /// allow tear down to end test
        }
    }

    /*
     Let the player play your radio and ensure expected playback states.

     Connecting and setting up depends on the infrastructure.
     In this test we assume it takes no longer than 3 seconds.
     */
    func test02_PlayerStates() throws {
        
        try AudioPlayer.open(for: myEndpoint, listener: nil) {
            (control) in
 
            XCTAssertEqual(control.state, PlaybackState.stopped)
            control.play()
            XCTAssertEqual(control.state, PlaybackState.buffering)
            sleep(5)
            XCTAssertEqual(control.state, PlaybackState.playing)
            control.stop()
            XCTAssertEqual(control.state, PlaybackState.playing)
            sleep(1)
            XCTAssertEqual(control.state, PlaybackState.stopped)
            
            self.semaphore?.signal()
        }
    }

    /*
     Use your audio player listener to be called back.
     Filter console output by '-- ' and watch.

     Make sure the listener stays alive until it recieves stateChanged to '.stopped'.
     */
    func test03_ListenToPlayer() throws {
        
        try AudioPlayer.open(for: myEndpoint, listener: playerListener) {
            (control) in

            control.play()
            sleep(3)
            control.stop()
            sleep(1) /// if not, the player listener may be gone to early to recieve the stop event
            
            self.semaphore?.signal()
        }
    }

    /*
     Handling the problem "host not found".
     Filter the console output by '-- '
     
     You don't recieve a player control but
     - an exception and
     - listener.error lets you see all errors, warnings and notifications
     */
    func test04_Error_NoPlayer() throws {
        defer { self.semaphore?.signal() }
        
        let badEndpoint = MediaEndpoint(mediaUri:  "https://swr-swr3.cast.io/bad/url")
        do {
            try AudioPlayer.open(for: badEndpoint, listener: playerListener) {
                (control) in
                
                XCTFail("no player control expected")
                self.semaphore?.signal()
            }
        } catch {
            XCTAssertTrue(error is AudioPlayerError, "all known errors inherit from AudioPlayerError")
            XCTAssertTrue(error is SessionError, "AudioPlayerError of type SessionError expected. There is a problem establishing a session with the endpoint")
        }
        
        /// AudioPlayerListener.error(...) recieves errors as well, asynchronously
        sleep(1)
        XCTAssertEqual(playerListener.errors.count, 1)
        guard let lastError = playerListener.errors.last else {
            XCTFail(); return
        }
        XCTAssertNotEqual(0, lastError.code) /// error occured
        XCTAssertNotNil(lastError.osstatus) /// more info
        
        XCTAssertEqual(603, lastError.code) /// ErrorKind.serverError
        XCTAssertEqual(-1003, lastError.osstatus) /// host not found
        
        
    }

    /*
     Handling a problem on play().
     Filter the console output by '-- '
     
     listener.error lets you see all errors, warnings and notifications
     */
    func test05_Error_NoAudio() {
        
        let badEndpoint = MediaEndpoint(mediaUri:  "https://cast.ybrid.io/bad/url")
        
        do {
            try AudioPlayer.open(for: badEndpoint, listener: playerListener) {
                [self] (control) in
                defer { self.semaphore?.signal() }
                
                XCTAssertEqual(.icy, control.mediaProtocol) /// commincation with the endpoint is possible
                XCTAssertEqual(playerListener.errors.count, 0) /// no error yet
                
                control.play()
                sleep(2)
                
                XCTAssertEqual(playerListener.errors.count, 1)
                guard let lastError = playerListener.errors.last else {
                    XCTFail()
                    return
                }
                XCTAssertNotEqual(0, lastError.code) /// error occured
                XCTAssertEqual(303, lastError.code) /// ErrorKind.cannotResolveDecoder

                XCTAssertNil(lastError.osstatus)
            }
        } catch {
            XCTFail("no player control, something went wrong");
            self.semaphore?.signal(); return
        }
    }
    
    
    /*
     The audio codec opus is supported
     */
    func test06_PlayOpus() {
        let opusEndpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        do {
            try AudioPlayer.open(for: opusEndpoint, listener: playerListener) {
                (control) in
                
                control.play()
                sleep(6)
                control.stop()
                sleep(1) /// if not, the player listener may be gone to early to recieve the stop event
                
                self.semaphore?.signal()
            }
        } catch {
            XCTFail("no player control. Something went wrong");
            self.semaphore?.signal(); return
        }
    }
    
    /*
     HttpSessions on urls that offer no defined content length
     are identified as on demand files. They can be paused.
     Remember, all actions are asynchronous. So assertions in this test are delayed.
     */
    func test07_OnDemandPlayPausePlayPauseStop() {
        let onDemandEndpoint = MediaEndpoint(mediaUri:  "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        do {
            try AudioPlayer.open(for: onDemandEndpoint, listener: playerListener) {
                (control) in
                XCTAssertFalse(control.canPause)
                control.play()
                XCTAssertEqual(control.state, PlaybackState.buffering)
                sleep(5)
                XCTAssertTrue(control.canPause)
                XCTAssertEqual(control.state, PlaybackState.playing)
                control.pause()
                sleep(1)
                XCTAssertEqual(control.state, PlaybackState.pausing)
                control.play()
                sleep(1)
                XCTAssertEqual(control.state, PlaybackState.playing)
                control.pause()
                sleep(1)
                XCTAssertEqual(control.state, PlaybackState.pausing)
                control.stop()
                sleep(1)
                XCTAssertEqual(control.state, PlaybackState.stopped)
                
                self.semaphore?.signal()
            }
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore?.signal(); return
        }
    }
    
    /*
     listener.metadataChanged is called when metadata changes. In the beginning of streaming
     there ist always a change compared to nothing.
     */
    func test08_ListenToMetadata() {

        do {
            try AudioPlayer.open(for: myEndpoint, listener: playerListener) {
                [self] (control) in
                
                control.play()
                sleep(3)
                control.stop()
                sleep(1)
                
                XCTAssertGreaterThan(playerListener.metadatas.count, 0)
                guard playerListener.metadatas.count > 0 else {
                    XCTFail("expected at least one metadata called");
                    self.semaphore?.signal(); return
                }
                let metadata = playerListener.metadatas[0]
                XCTAssertNotNil(metadata.displayTitle)
                
                self.semaphore?.signal()
            }
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore?.signal(); return
        }
    }
    
    /*
     Use an endpoint that supports ybridV2 and implement the ybridControl callback.
     YbridControl's methods can shift time and alter the streamed audio content.
     
     The AudioCompleteCallback is called when the content change takes place.
     */
    func test09_UseYbridControl() {

        do {
            try AudioPlayer.open(for: ybridSwr3Endpoint, listener: nil, playbackControl: { _ in XCTFail("ybridControl should be called back"); self.semaphore?.signal() },
             ybridControl: {
                [self] (control) in /// called asychronously
               
                control.play()
                sleep(2)
                control.skipBackward(ItemType.NEWS) { (success) in
                    print("Now You listen to news. That's \(success).")
                    XCTAssertTrue(success)
                }
                sleep(10) /// listen to the news
                
                control.stop()
                sleep(1)
                self.semaphore?.signal()
            })
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore?.signal(); return
        }
    }

    /*
     Audio codecs AAC are supported up to profile HE-AAC_v2.
     
     Besides the first sine you should hear 4 different high frequencies.
     */
    func test10_PlayHEAACv2() {
        
        do {
            try AudioPlayer.open(for: aacHEv2Endpoint, listener: nil) {
                [self] (control) in
                
                control.play()
                sleep(6)
                control.stop()
                sleep(1)
                
                XCTAssertEqual(playerListener.errors.count, 0)
                playerListener.errors.forEach{ (error) in
                    XCTFail(error.message ?? error.localizedDescription)
                }
                
                self.semaphore?.signal()
            }
        } catch {
            XCTFail("no player control. Something went wrong");
            self.semaphore?.signal(); return
        }
    }
    
    /**
     FLAC with pink noise.
     */
    func test11_PlayFlac() {
        
        do {
            try AudioPlayer.open(for: flacOnDemandEndpoint, listener: playerListener) {
                [self] (control) in
                
                control.play()
                sleep(6)
                control.stop()
                sleep(1)
                
                XCTAssertEqual(playerListener.errors.count, 0)
                playerListener.errors.forEach{ (error) in
                    XCTFail(error.message ?? error.localizedDescription)
                }
                
                self.semaphore?.signal()
            }
        } catch {
            XCTFail("no player control. Something went wrong");
            self.semaphore?.signal(); return
        }
    }

}
