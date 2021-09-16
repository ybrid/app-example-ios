//
// DevelopingPlayerTests.swift
// player-sdk-swiftUITests
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

import XCTest

import YbridPlayerSDK
import YbridOpus
import YbridOgg


class DevelopingPlayerTests: XCTestCase {
 
    func test01_LoggerNonVerbose() {
        XCTAssertFalse(Logger.verbose)
    }
    
    func test03_PlayerName() {
        guard let name = AudioPlayer.productName else {
            XCTFail("no AudioPlayer.productName")
            return
        }
        Logger.testing.notice("-- AudioPlayer.productName=\(name)")
        XCTAssertEqual("YbridPlayerSDK", name)
    }
    
    func test04_PlayerVersion() {
        guard let version = AudioPlayer.productVersion else {
            XCTFail("no AudioPlayer.productVersion")
            return
        }
        Logger.testing.notice("-- AudioPlayer.productVersion=\(version)")
        XCTAssertTrue(isVersionNumber(version), "\(version) is no version number")
        XCTAssertTrue(version.starts(with: "0."))
    }
    private func isVersionNumber(_ version:String) -> Bool {
        let pattern = "(\\d+)\\.(\\d+)\\.(\\d+)"
        return version.range(of: pattern, options: .regularExpression) != nil
    }
    
    func test05_PayerBuildNumber() {
        guard let build = AudioPlayer.productBuildNumber else {
            XCTFail("no AudioPlayer.productBuildNumber")
            return
        }
        Logger.testing.notice("-- AudioPlayer.productBuildNumber=\(build)")
        guard let number = Int(build) else {
            XCTFail("cannot convert \(build) to Int")
            return
        }
        XCTAssertGreaterThan(number, 0)
    }
    
      
    func test10_OpusBundleInfo() throws {
        guard let version = checkBundle(id: "io.ybrid.opus-swift", expectedName: "YbridOpus") else {
            XCTFail("version of bundle 'io.ybrid.opus-swift' expected")
            return
        }
        XCTAssertTrue(isVersionNumber(version), "\(version) is no version number")
        XCTAssertTrue(version.starts(with: "0."))
    }
    
    func test11_YbridOpusAvailable() {
        let versionString = String(cString: opus_get_version_string())
        print("-- opus_get_version_string() returns '\(versionString)\'")
        XCTAssertTrue(versionString.hasPrefix("libopus 1.3.1"))
    }
    
    func test20_OggBundleInfo() throws {
        guard let version = checkBundle(id: "io.ybrid.ogg-swift", expectedName: "YbridOgg") else {
            XCTFail("version of bundle 'io.ybrid.ogg-swift' expected"); return
        }
        XCTAssertTrue(isVersionNumber(version), "\(version) is no version number")
    }
    
    func test21_YbridOggAvailable() {
        var oggSyncState = ogg_sync_state()
        print("-- ogg_sync_state() is '\(oggSyncState)\'")
        XCTAssertNotNil(oggSyncState)
        XCTAssertEqual(0, oggSyncState.returned)
        ogg_sync_init(&oggSyncState)
        ogg_sync_clear(&oggSyncState)
        print("-- ogg_sync_state() is '\(oggSyncState)\'")
        XCTAssertEqual(0, oggSyncState.returned)
    }

    private func checkBundle(id:String, expectedName:String) -> String? {
       guard let bundle = Bundle(identifier: id) else {
           XCTFail("no bundle identifier '\(id)' found")
           return nil
       }
       guard let info = bundle.infoDictionary else {
           XCTFail("no infoDictionary on bundle '\(id)' found")
           return nil
       }
       print("-- infoDictionary is '\(info)'")
       
       let version = info["CFBundleShortVersionString"] as! String
       XCTAssertNotNil(version)

       let name = info["CFBundleName"] as! String
       XCTAssertEqual(expectedName, name)
       let copyright = info["NSHumanReadableCopyright"] as! String
       XCTAssertTrue(copyright.contains("nacamar"))
       
       let build = info["CFBundleVersion"] as! String
       print("-- version of \(name) is \(version) (build \(build))")
       
       return version
   }

    
}
