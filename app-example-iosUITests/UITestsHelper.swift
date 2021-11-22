//
// UITestsHelper.swift
// app-example-swiftUITests
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

import Foundation
import YbridPlayerSDK
import XCTest


extension Logger {
    static let testing: Logger = Logger(category: "testing")
}

extension TimeInterval {
    var S:String {
        return String(format: "%.3f s", self)
    }

    var us:Int {
        return Int(self * 1_000_000)
    }
}

class TestAudioPlayerListener : AbstractAudioPlayerListener {

    var bufferDuration:TimeInterval?
    var bufferS:Int { get {
        guard let duration = bufferDuration else {
            return 0
        }
        return Int(duration) + 1
    }}
    
    
    var logPlayingSince = true
    var logBufferSize = true
    var logMetadata = true

    func reset() {
        queue.async {
            self.metadatas.removeAll()
            self.errors.removeAll()
            self.bufferDuration = 0.0
        }
    }
    
    let queue = DispatchQueue.init(label: "io.ybrid.testing.metatdatas")
    
    var metadatas:[Metadata] = []
    override func metadataChanged(_ metadata: Metadata) {
        super.metadataChanged(metadata)
        if logMetadata {
            Logger.testing.info("-- metadata changed, display title is '\(metadata.displayTitle)'")
        }
        queue.async {
            self.metadatas.append(metadata)
        }
    }
    
    var errors:[AudioPlayerError] = []
    override func error(_ severity:ErrorSeverity, _ error: AudioPlayerError) {
        super.error(severity, error)
        queue.async {
            self.errors.append(error)
        }
    }
    
    
    override func playingSince(_ seconds: TimeInterval?) {
        guard logPlayingSince else {
            return
        }
        if let duration = seconds {
            Logger.testing.notice("-- playing for \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset playing duration ")
        }
    }

    override func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        if let bufferLength = currentSeconds {
            self.bufferDuration = bufferLength
            guard logBufferSize else {
                return
            }
            Logger.testing.notice("-- currently buffered \(bufferLength.S) seconds of audio")
        }
    }
}


class AbstractAudioPlayerListener : AudioPlayerListener {

    func stateChanged(_ state: PlaybackState) {
        Logger.testing.notice("-- player is \(state)")
    }
    func error(_ severity:ErrorSeverity, _ exception: AudioPlayerError) {
        Logger.testing.notice("-- error \(severity): \(exception.localizedDescription)")
    }

    func metadataChanged(_ metadata: Metadata) {}
    func playingSince(_ seconds: TimeInterval?) {}

    func durationReadyToPlay(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- begin playing audio after \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset buffered until playing duration ")
        }
    }

    func durationConnected(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- recieved first data from url after \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset recieved first data duration ")
        }
    }

    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {}
}

class TimingListener : AudioPlayerListener {
    func cleanUp() {
        buffers.removeAll()
        errors.removeAll()
    }
    
    var buffers:[TimeInterval] = []
    func stateChanged(_ state: PlaybackState) {}
    func metadataChanged(_ metadata: Metadata) {}
    func playingSince(_ seconds: TimeInterval?) {}
    func durationReadyToPlay(_ seconds: TimeInterval?) {}
    func durationConnected(_ seconds: TimeInterval?) {}
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        if let current = currentSeconds {
            buffers.append(current)
        }
    }
    
    var errors:[AudioPlayerError] = []
    func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        errors.append(exception)
    }
}

class Poller {
    func wait(_ control:PlaybackControl, until:PlaybackState, maxSeconds:Int) {
        let took = wait(max: maxSeconds) {
            return control.state == until
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "not \(until) within \(maxSeconds) s")
    }
    
    
    func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) {
        let took = wait(max: maxSeconds) {
            return control.state == until
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "not \(until) within \(maxSeconds) s")
    }

    func wait(max maxSeconds:Int, until:() -> (Bool)) -> Int {
        var seconds = 0
        while !until() && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertTrue(until(), "condition not satisfied within \(maxSeconds) s")
        return seconds
    }
}

class TestYbridPlayerListener : TestAudioPlayerListener, YbridControlListener {
    
    var logOffset = true
    var logBitrate = true
    var logSwapsLeft = true
    
    override func reset() {
        queue.async { [self] in
            offsets.removeAll()
            services.removeAll()
            swaps.removeAll()
            bitrates.removeAll()
        }
    }
    
    var offsets:[TimeInterval] = []
    var services:[[Service]] = []
    var swaps:[Int] = []
    var bitrates:[(current:Int32?,limit:Int32?)] = []
    
    // getting the latest recieved values for ...
    
    var offsetToLive:TimeInterval? { get {
        queue.sync {
            return offsets.last
        }
    }}
    var swapsLeft:Int? { get {
        queue.sync {
            return swaps.last
        }
    }}
    var maxBitRate:Int32? { get {
        queue.sync {
            return bitrates.last?.limit
        }
    }}
    var currentBitRate:Int32? { get {
        queue.sync {
            return bitrates.last?.current
        }
    }}
    
    
    var maxRateNotifications:Int { get {
        queue.sync {
            return bitrates.map{ $0.limit }.filter{ $0 != nil }.count
        }
    }}
    
    func isItem(_ type:ItemType) -> Bool {
        queue.sync {
            if let currentType = metadatas.last?.current.type {
                return type == currentType
            }
            return false
        }
    }
    
    func isItem(of types:[ItemType]) -> Bool {
        queue.sync {
            if let currentType = metadatas.last?.current.type {
                return types.contains(currentType)
            }
            return false
        }
    }
    
    
    func offsetToLiveChanged(_ offset:TimeInterval?) {
        guard let offset = offset else { XCTFail(); return }
        if logOffset {
            Logger.testing.info("-- offset is \(offset.S)")
        }
        queue.async {
            self.offsets.append(offset)
        }
    }

    func servicesChanged(_ services: [Service]) {
        Logger.testing.info("-- provided service ids are \(services.map{$0.identifier})")
        queue.async {
            self.services.append(services)
        }
    }
    
    func swapsChanged(_ swapsLeft: Int) {
        if logSwapsLeft {
            Logger.testing.info("-- swaps left \(swapsLeft)")
        }
        queue.async {
            self.swaps.append(swapsLeft)
        }
    }
    
    func bitRateChanged(currentBitsPerSecond: Int32?, maxBitsPerSecond: Int32?) {
        if logBitrate {
            Logger.testing.info("-- bit rate current \(currentBitsPerSecond ?? -1), max \(maxBitsPerSecond ?? -1)")
        }
        queue.async {
            self.bitrates.append((currentBitsPerSecond,maxBitsPerSecond))
        }
    }
    
    override func metadataChanged(_ metadata: Metadata) {
        Logger.testing.info("-- service \(String(describing: metadata.service.identifier))")
        super.metadataChanged(metadata)
    }
}



class Trace {
    let name:String
    private var triggered:Date? = nil
    private var completed:Date? = nil
    var changed:Bool = false
    var valid:Bool { get {
        return triggered != nil && completed != nil
    }}
    var tookS:TimeInterval { get {
        guard valid else {
            return -1
        }
        return completed!.timeIntervalSince(triggered!)
    }}
    init(_ name:String) {
        self.name = name
        self.triggered = Date()
    }
    func complete(_ changed:Bool) {
        self.completed = Date()
        self.changed = changed
    }
}
class ActionsTrace {
    private var actions:[Trace] = []
    
    init() {}
    func reset() { actions.removeAll() }
    func append(_ trace:Trace) { actions.append(trace) }
    
    func checkTraces(expectedActions:Int) -> [(String,TimeInterval)] {
          
        guard actions.count == expectedActions else {
            XCTFail("expecting \(expectedActions) completed actions, but were \(actions.count)")
            return []
        }
        
        let actionsTook:[(String,TimeInterval)] = actions.filter{
             return $0.valid
        }.map{
            let actionTookS = $0.tookS
            Logger.testing.debug("\($0.changed ? "" : "not ")\($0.name) took \(actionTookS.S)")
            return ($0.name,actionTookS)
        }
        return actionsTook
    }

    func check(confirm:Int, mustBeCompleted:Bool = true, maxDuration:TimeInterval) {
          
        XCTAssertEqual(actions.count,confirm, "expecting \(confirm) completed actions, but were \(actions.count)")
        
        actions.filter{
            if mustBeCompleted {
                XCTAssertTrue($0.valid, "expected valid, but was \($0) ")
            }
             return $0.valid
        }.forEach{
            Logger.testing.debug("\($0.changed ? "" : "not ")\($0.name) took \($0.tookS.S)")
            XCTAssertLessThan($0.tookS, maxDuration, "\($0.name) should take less than \(maxDuration.S), took \($0.tookS.S)")
        }
    }
    
}
