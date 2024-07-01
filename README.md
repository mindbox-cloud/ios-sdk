[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Mindbox.svg)](https://cocoapods.org/pods/Mindbox)

# Mindbox SDK for iOS

The Mindbox SDK allows developers to integrate mobile push notifications, in-app messages, and client events into your iOS projects.

## Getting Started

These instructions will help you integrate the Mindbox SDK into your iOS app.

### Installation

Follow the installation process detailed [here](https://developers.mindbox.ru/docs/ios-sdk-integration). Overview:

1. Add the Mindbox SDK to your Podfile:
    ```markdown
   pod 'Mindbox'
   pod 'MindboxNotifications'
    ```

2. Install the pods:
   ```markdown
    pod install
    ```

### Initialization

Initialize the Mindbox SDK in your AppDelegate or SceneDelegate. Refer to the documentation [here](https://developers.mindbox.ru/docs/ios-sdk-initialization) for more details.

### Operations

Learn how to send events to Mindbox. Create a new Operation class object and set the respective parameters. Check the [documentation](https://developers.mindbox.ru/docs/ios-integration-of-actions) for more details.

### Push Notifications

Mindbox SDK aids in handling push notifications. Configuration and usage instructions can be found in the SDK documentation [here](https://developers.mindbox.ru/docs/ios-send-push-notifications-appdelegate) and [here](https://developers.mindbox.ru/docs/ios-send-rich-push-appdelegate).

## Troubleshooting

An [Example of integration](https://github.com/mindbox-cloud/ios-sdk/tree/develop/Example) is provided in case of any issues.

## Further Help

In need of further assistance? Feel free to contact us.

## License

This library is available as open source under the explicit terms of the [License](https://github.com/mindbox-cloud/ios-sdk/blob/develop/LICENSE.md).

For a better understanding of these content, we suggest reading the referenced [iOS SDK](https://developers.mindbox.ru/docs/ios-sdk-integration) documentation.
