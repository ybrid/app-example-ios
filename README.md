# app-example-ios
This is an example app of using the audio player from [player-sdk-swift](https://github.com/ybrid/player-sdk-swift) for iOS. The xcode project in this repository is written in Swift 4 and runs the app on iPhones and iPads from iOS 9 to 14. 

# Running the app

## Preconditions
This example app should run with older versions of XCode according to the nature of envolved XCFrameworks. We use version 12.

## run in a simulator
Open app-example-ios.xcworkspace with XCode. Select scheme 'app-example-ios' and choose one of the iOS Simulators and press the 'play' button. 

## run on your device
Of course you can choose your own connected device as well. 


# Running Tests 
The scheme 'app-example-iosUITests' contains some test classes. Select the scheme, change to the 'Test navigator' tab and run one of the tests.

- 'UseYbridPlayerTests' is a tutorial. It explains how to use YbridPlayerSDK.
- 'YbridPlayerTests' covers the very basic use cases.
- 'PlayerToggleStressTests' takes about 7 Minutes. It toggles play and stop in decreasing time intervalls. It's purpose is to demonstrate robustness and watch memory usage.

You can run tests on connected devices as well.

**Sorry**, there is an issue with simulators using ios < 14 on macOS Big Sur (see [Known issues](https://github.com/ybrid/app-example-ios#known-issues) below).


# Update the player-sdk
If you want to update to the latest version of ```YbridPlayerSDK``` you need CocoaPod installed. Execute
```shell
pod update
```
on a terminal in the project's directory.


# Known issues
Since the update on macOS BigSur (and still in Version 11.3.1) there is a problem running the player with simulators on versions smaller than iOS 14. The problem is already reported on https://developer.apple.com/forums/thread/667921?login=true&page=1#650224022. I hope the issue will be fixed by apple...

# Further documentation
See [player-sdk-swift](https://github.com/ybrid/player-sdk-swift)

# Contributing
Because this is an example app for using player-sdk-swift, contributing should happen in that repository [player-sdk-swift](https://github.com/ybrid/player-sdk-swift)

# Licenses
This project and [player-sdk-swift](https://github.com/ybrid/player-sdk-swift) are under under MIT license. The player project depends on [ogg-swift](https://github.com/ybrid/ogg-swift) and [opus-swift](https://github.com/ybrid/opus-swift). Ogg and Opus carry BSD licenses, see 3rd party section in [LICENSE](https://github.com/ybrid/app-example-ios/blob/master/LICENSE) file.