//
// YbridControlTests.swift
// player-sdk-swiftUITests
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

class YbridTimeshiftTests: XCTestCase {

    let liveOffsetRange_LostSign = TimeInterval(0.0) ..< TimeInterval(10.0)
    let maxWindResponseS = 3
    
    var player:YbridControl?
    let ybridPlayerListener = TestYbridPlayerListener()
    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        // don't log additional debug information in this tests
        Logger.verbose = false
        ybridPlayerListener.reset()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    override func tearDownWithError() throws {
        print( "offsets were \(ybridPlayerListener.offsets)")
    }
    
    func test01_NoInitialOffsetChange() throws {

        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in

                sleep(1)

                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)

        XCTAssertEqual(ybridPlayerListener.offsets.count, 0)
    }
    
    func test02_PlayOffsetChanges() throws {
        
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 1)
        ybridPlayerListener.offsets.forEach{
            XCTAssertTrue(liveOffsetRange_LostSign.contains(-$0))
        }
    }
    
    func test03_WindBackward120_WindForward60() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.wind(by: -120.0)
                wait(ybridPlayerListener, shifted: -120.0, maxSeconds: 4)
                sleep(4)
                
                ybridControl.wind(by: 60.0)
                wait(ybridPlayerListener, shifted: -60.0, maxSeconds: 4)
                sleep(4)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 2, "expected to be at least the initial and one more change of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: +60.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)")
    }
    
    
    func test04_Wind_Cannot() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.wind(by: -120.0)
                sleep(4)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 1, "expected to be only the initial change of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: 0.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)")
        
        guard let error = ybridPlayerListener.errors.last else {
            XCTFail( "expected an error message"); return
        }
        XCTAssertTrue(error.message?.contains("cannot wind ") == true, "human readably message expected" )
    }

    func test05_WindToLive() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.wind(by:-20.0)
                wait(ybridPlayerListener, shifted: -20.0, maxSeconds: maxWindResponseS)
                sleep(4)
                ybridControl.windToLive()
                wait(ybridPlayerListener, shifted: 0.0, maxSeconds: maxWindResponseS)
                sleep(4)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: maxWindResponseS)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 3, "expected to be at least the initial and two more changes of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        XCTAssertTrue(liveOffsetRange_LostSign.contains(-lastOffset), "\(-lastOffset) not within \(liveOffsetRange_LostSign)")
        
    }
    
    func test06_WindToDate_BeforeFullHourAdvertisement() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                let date = lastFullHour(secondsBefore:15)
                ybridControl.wind(to:date)
                wait(ybridControl, type: ItemType.ADVERTISEMENT, maxSeconds: 6)
                sleep(4)

                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: maxWindResponseS)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    
    func test07_SkipBackwardNews_SkipForwardMusic() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.skipBackward(ItemType.NEWS)
                wait(ybridControl, type: ItemType.NEWS, maxSeconds: 4)
                sleep(8)
  
                ybridControl.skipForward(ItemType.MUSIC)
                wait(ybridControl, type: ItemType.MUSIC, maxSeconds: 4)
                sleep(6)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    func test08_SkipBackwardItem_LastItemAgain() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.skipBackward()
                let type = ybridPlayerListener.metadatas.last?.current?.type
                XCTAssertNotNil(type)
                Logger.testing.notice("currently playing \(type ?? ItemType.UNKNOWN)")

                sleep(4)
  
                ybridControl.skipBackward()
                let typeNow = ybridPlayerListener.metadatas.last?.current?.type
                XCTAssertEqual(type, typeNow)
                Logger.testing.notice("again playing \(type ?? ItemType.UNKNOWN)")

                sleep(4)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
   
 
    func lastFullHour(secondsBefore:Int) -> Date {
        let date = Date()
        var components = Calendar.current.dateComponents([.minute, .second], from: date)
        let minute = components.minute ?? 0
        if minute > 0 {
            components.minute = -minute
        }
        let seconds = components.second ?? 0
        if seconds > 0 {
            components.second = -seconds - secondsBefore
        }
        return Calendar.current.date(byAdding: components, to: date)!
    }
    
    private func shift( _ range:Range<TimeInterval>, by:TimeInterval ) -> Range<TimeInterval> {
        let shiftedRange = range.lowerBound+by ..< range.upperBound+by
        return shiftedRange
    }

    private func wait(_ consumer:TestYbridPlayerListener, shifted: TimeInterval, maxSeconds:Int) {
        let shiftedRange_LostSign = shift(liveOffsetRange_LostSign, by: -shifted)
        let took = wait(max: maxSeconds) {
            guard let offset = consumer.offsetToLive else {
                return false
            }
            return isOffset(offset, shifted: shifted)
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "offset to live not \((-shiftedRange_LostSign.lowerBound).S) ..< \((-shiftedRange_LostSign.upperBound).S) within \(maxSeconds) s")
    }
    
    private func wait(_ control:YbridControl, type: ItemType, maxSeconds:Int) {

        let took = wait(max: maxSeconds) {
            return ybridPlayerListener.isItem(type)
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "item type is \(ybridPlayerListener.metadatas.last?.current?.type), not \(type)")
    }
    
    
    private func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) {
        let took = wait(max: maxSeconds) {
            return control.state == until
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "not \(until) within \(maxSeconds) s")
    }
    
    private func wait(max maxSeconds:Int, until:() -> (Bool)) -> Int {
        var seconds = 0
        while !until() && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertTrue(until(), "condition not satisfied within \(maxSeconds) s")
        return seconds
    }
    
    func isOffset(_ offset:TimeInterval, shifted:TimeInterval) -> Bool {
        let shiftedRange_LostSign = shift(liveOffsetRange_LostSign, by: -shifted)
        return shiftedRange_LostSign.contains(-offset)
    }
}

class TestYbridPlayerListener : AbstractAudioPlayerListener, YbridControlListener {
    

    func reset() {
        offsets.removeAll()
        errors.removeAll()
        metadatas.removeAll()
        services.removeAll()
    }
    
    var metadatas:[Metadata] = []
    var offsets:[TimeInterval] = []
    var errors:[AudioPlayerError] = []
    var services:[[Service]] = []
    var swaps:[Int] = []
    
    
    // the latest recieved value for offset
    var offsetToLive:TimeInterval? { get {
        return offsets.last
    }}
    
    // the latest value for swapsLeft
    var swapsLeft:Int? { get {
        return swaps.last
    }}
    
    
    func isItem(_ type:ItemType) -> Bool {
        if let currentType = metadatas.last?.current?.type {
            return type == currentType
        }
        return false
    }
    
    
    func offsetToLiveChanged(_ offset:TimeInterval?) {
        guard let offset = offset else { XCTFail(); return }
        Logger.testing.info("-- offset is \(offset.S)")
        offsets.append(offset)
    }

    func servicesChanged(_ services: [Service]) {
        Logger.testing.info("-- provided service ids are \(services.map{$0.identifier})")
        self.services.append(services)
    }
    
    func swapsChanged(_ swapsLeft: Int) {
        Logger.testing.info("-- swaps left \(swapsLeft)")
        self.swaps.append(swapsLeft)
    }
    
    override func metadataChanged(_ metadata: Metadata) {
        Logger.testing.notice("-- metadata: display title \(String(describing: metadata.displayTitle)), service \(String(describing: metadata.activeService?.identifier))")
        metadatas.append(metadata)

    }

    override func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        super.error(severity, exception)
        errors.append(exception)
    }

}
