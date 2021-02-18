# app-example-ios
This is an example app of using the audio player [player-sdk-swift](https://github.com/ybrid/player-sdk-swift) for iOS. It is written in Swift 4 and runs on iPhones and iPads from iOS 9 to 14. 

# Running the app

## Preconditions
This example app should run with older versions of XCode according to the nature of envolved XCFrameworks. We use Version 12. 

## run in a simulator
Open app-example-ios.xcworkspace with XCode. Select scheme 'app-example-ios' and one of the iOS Simulators and press 'play'. 

## run on your device
Of course you can choose your own connected device as well. 


# How to use
After integrating player_sdk_swift in your own projekt (see [player-sdk-swift/README](https://github.com/ybrid/player-sdk-swift/blob/master/README.md#integration)) find a suitable place for the following lines of swift code.

```swift
import YbridPlayerSDK 

let url = URL.init(string: "https://stagecast.ybrid.io/adaptive-demo")!
let player = AudioPlayer(mediaUrl: url, listener: nil)
player.play()
...
```

## Tests 
Scheme 'app-example-iosUITests' contains some test classes. Select the scheme, change to the 'Test navigator' tab and run one of the tests.

- 'UseYbridPlayerTests' is a tutorial. It explains how to use YbridPlayerSDK.
- 'YbridPlayerTests' covers the basic use cases. Run it to make sure everything works fine.
- 'PlayerToggleStressTests' takes about 7 Minutes. It toggles play and stop in decreasing time intervalls. It's purpose is to demonstrate robustness and watch memory usage.

You can run tests on simulator or connected devices.

**Sorry**, there is an issue with simulators using ios < 14 on macOS Big Sur (see [Known issues](https://github.com/ybrid/app-example-ios#known-issues) below).


## Update the player-sdk
If you want to update to the latest version of ```player-sdk-swift``` you need cocoapod installed. Execute
```shell
pod update
```
on a terminal in the project's directory.


# Known issues
Since the update on macOS BigSur (and still in Version 11.2.1) there is a problem running the player with simulators on versions smaller than iOS 14. The problem is already reported on https://developer.apple.com/forums/thread/667921?login=true&page=1#650224022. I hope the issue will be fixed by apple...

# Further documentation
See [player-sdk-swift](https://github.com/ybrid/player-sdk-swift)

# Contributing
Because this is an example app for using player-sdk-swift, contributing should happen in that repository [player-sdk-swift](https://github.com/ybrid/player-sdk-swift)

# Licenses
This project and [player-sdk-swift](https://github.com/ybrid/player-sdk-swift) are under under MIT license. The player project depends on [ogg-swift](https://github.com/ybrid/ogg-swift) and [opus-swift](https://github.com/ybrid/opus-swift). Ogg and Opus carry BSD licenses, see 3rd party section in [LICENSE](https://github.com/ybrid/app-example-ios/blob/master/LICENSE) file.