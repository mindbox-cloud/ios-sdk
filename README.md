[![Swift Package Manager Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swiftpackageindex.com/mindbox-cloud/ios-sdk)

# Mindbox SDK for iOS

The Mindbox SDK allows developers to integrate mobile push notifications, in-app messages, and client events into your iOS projects.

## Getting Started

These instructions will help you integrate the Mindbox SDK into your iOS app.

### Installation (Swift Package Manager — recommended)

Follow the installation process detailed [here](https://developers.mindbox.ru/docs/ios-sdk). Overview:

1. In Xcode, go to **File → Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/mindbox-cloud/ios-sdk
   ```
3. Add `Mindbox` to your main app target.
4. Add `MindboxNotificationsService` to your Notification Service Extension target.
5. Add `MindboxNotificationsContent` to your Notification Content Extension target.

### Installation (CocoaPods)

CocoaPods is still supported. Add to your Podfile:

```ruby
pod 'Mindbox'
pod 'MindboxNotifications'
```

### Migrating from CocoaPods to SPM

If you are currently using CocoaPods and want to switch to SPM:

1. Deintegrate CocoaPods:
   ```bash
   pod deintegrate
   rm -rf Pods Podfile Podfile.lock
   ```
   If your `.xcworkspace` was created by CocoaPods (contains only your project and `Pods.xcodeproj`), remove it as well:
   ```bash
   rm -rf YourApp.xcworkspace
   ```
2. Open your `.xcodeproj` (not `.xcworkspace`).
3. Verify no CocoaPods remnants:
   - Each target → **Build Phases** → no `[CP]` phases should remain.
   - Each target → **General** → **Frameworks, Libraries** → no `Pods_*.framework`.
   - Project → **Build Settings** → search "Pods" → no xcconfig references.
4. Add the SDK via SPM (see Installation above).
5. Build and verify all targets compile.

> **Note:** Your app data is not affected by this migration. Core Data stores are saved in the App Group container independently of the dependency manager.

### Initialization

Initialize the Mindbox SDK in your AppDelegate or SceneDelegate. Refer to the documentation [here](https://developers.mindbox.ru/docs/ios-sdk-initialization) for more details.

### Operations

Learn how to send events to Mindbox. Create a new Operation class object and set the respective parameters. Check the [documentation](https://developers.mindbox.ru/docs/ios-sdk-events) for more details.

### Push Notifications

Mindbox SDK aids in handling push notifications. Configuration and usage instructions can be found in the SDK documentation [here](https://developers.mindbox.ru/docs/ios-quick-setup-push-notifications) and [here](https://developers.mindbox.ru/docs/ios-rich-push-notifications).

## Troubleshooting

An [Example of integration](https://github.com/mindbox-cloud/ios-sdk/tree/develop/Example) is provided in case of any issues.

## Further Help

In need of further assistance? Feel free to contact us.

## License

This library is available as open source under the explicit terms of the [License](https://github.com/mindbox-cloud/ios-sdk/blob/develop/LICENSE.md).

For a better understanding of these content, we suggest reading the referenced [iOS SDK](https://developers.mindbox.ru/docs/ios-sdk) documentation.
