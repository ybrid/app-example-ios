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


class AbstractAudioPlayerListener : AudioPlayerListener {

    func stateChanged(_ state: PlaybackState) {
        Logger.testing.notice("-- player is \(state)")
    }
    func error(_ severity:ErrorSeverity, _ exception: AudioPlayerError) {
        Logger.testing.notice("-- \(severity): \(exception.localizedDescription)")
    }
    
    func metadataChanged(_ metadata: Metadata) {}
    func playingSince(_ seconds: TimeInterval?) {}
    func durationReadyToPlay(_ seconds: TimeInterval?) {}
    func durationConnected(_ seconds: TimeInterval?) {}
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {}
}



class TestAudioPlayerListener : AbstractAudioPlayerListener {
    
    var statusCode:Int32 = 0
    var osCode:Int32 = 0
    
    override func error(_ severity: ErrorSeverity, _ error: AudioPlayerError) {
        super.error(severity, error)
        statusCode = error.code
        
        if let code = error.osstatus, code != 0 {
            osCode = code
        } else {
            osCode = 0
        }
    }
    override func metadataChanged(_ metadata: Metadata) {
        Logger.testing.notice("-- metadata changed: display title is \(metadata.displayTitle ?? "(nil)")")
    }
    
    override func playingSince(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- playing for \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset playing duration ")
        }
    }

    override func durationConnected(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- recieved first data from url after \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset recieved first data duration ")
        }
    }

    override func durationReadyToPlay(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- begin playing audio after \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset buffered until playing duration ")
        }
    }

    override func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        if let bufferLength = currentSeconds {
            Logger.testing.notice("-- currently buffered \(bufferLength.S) seconds of audio")
        }
    }
}


