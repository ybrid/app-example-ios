//
//  PlaybackEngine.swift
// player-sdk-swift
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

import AVFoundation

protocol Playback {
    func stop()
    func setListener(listener: BufferListener)
}

class PlaybackEngine : Playback {

    let engine:AVAudioEngine = AVAudioEngine() /// visible for unit testing
    let playerNode:AVAudioPlayerNode = AVAudioPlayerNode() /// visible for unit testing
    let sampleRate:Double /// visible for unit testing
    
    var playbackBuffer:PlaybackBuffer? /// visible for unit testing
    var timer:DispatchSourceTimer? /// visible for unit testing

    private let timerInterval:TimeInterval = 0.2
    private var metrics = Metrics()
    
    private weak var playerListener: AudioPlayerListener?
    init(format: AVAudioFormat,  listener: AudioPlayerListener?) {
        self.sampleRate = format.sampleRate
        self.playerListener = listener
        self.engine.attach(self.playerNode)
        // an interleaved format leads to exception with code=-10868 --> kAudioUnitErr_FormatNotSupported
        Logger.playing.debug("engine format is \(AudioPipeline.describeFormat(format)) ")
        self.engine.connect(self.playerNode, to: self.engine.mainMixerNode, format: format)
        self.engine.prepare()
        Logger.playing.debug("created with format \(AudioPipeline.describeFormat(format))")
    }
    
    deinit {
        Logger.playing.debug()
        self.engine.disconnectNodeInput(playerNode)
        self.engine.detach(playerNode)
    }
    
    // MARK: playback
    
    func start() -> PlaybackBuffer? {
        Logger.playing.debug()
        if playerNode.isPlaying { Logger.playing.notice("already playing!"); return playbackBuffer }
        
        change(volume: 0.0)
        
        do {
            try engine.start()
            playerNode.play()
        } catch {
            Logger.playing.error("failed to start engine: \(error.localizedDescription)")
        }
        
        let scheduling = PlaybackScheduling(playerNode, sampleRate: sampleRate)
        playbackBuffer = PlaybackBuffer(scheduling: scheduling, engine: self)
        
        startTimer()

        return playbackBuffer
    }
    
    func setListener(listener: BufferListener) {
        playbackBuffer?.listener = listener
    }
    
    func stop() {
        Logger.playing.debug()
        
        if let playingSince = playbackBuffer?.playingSince {
            self.playerListener?.playingSince(playingSince)
        }

        stopTimer()
        change(volume: 0)
        playerNode.stop()
        engine.stop()
    }
    
    func change(volume: Float) {
        playerNode.volume = volume
        if Logger.verbose { Logger.playing.debug("volume=\(volume)") }
    }

    // MARK: taking care of buffer
    
    private func startTimer() {
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + timerInterval, repeating: timerInterval)
        timer.setEventHandler(handler: { [weak self] in
            self?.tick()
        })

        timer.resume()
        self.timer = timer
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    @objc func tick() {
        playerListener?.playingSince(playbackBuffer?.playingSince)
        
        let bufferedS = playbackBuffer?.takeCare()
        let avrgBuffS = metrics.averagedBufferS(bufferedS)
        playerListener?.bufferSize(averagedSeconds: avrgBuffS, currentSeconds: bufferedS)
    }
    
    
    // MARK: helps averaging
    
    class Metrics {
        var averageS:Double = 3.0
        var buffers:[(at:Date,s:Double)] = []
        func averagedBufferS(_ currentBufferS:Double?) -> TimeInterval? {
            let now = Date()
            if let currentS = currentBufferS {
                buffers.append((now,currentS))
            }
            let timeThreshold = now.addingTimeInterval(TimeInterval.init(exactly: -averageS)!)
            while !buffers.isEmpty && buffers[0].at < timeThreshold  {
                buffers.removeFirst()
            }
            guard !buffers.isEmpty else { return nil }
            let totalBufferS = buffers.map { $0.s }.reduce(0.0, +)
            return totalBufferS / Double(buffers.count)
        }
    }
}
