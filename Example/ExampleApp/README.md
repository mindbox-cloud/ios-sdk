# Example app with SPM for Mindbox SDK for iOS

This is an example of SDK [integration](https://developers.mindbox.ru/docs/ios-sdk-integration) with SPM.

## Getting started

### Launching the application

1. [Clone this repository](https://github.com/mindbox-cloud/ios-sdk/tree/feature/MBX-3197-ExampleAppSPM).
2. Go to `ios-sdk/Example/ExampleApp/ExampleApp.xcodeproj`
3. Run file `ExampleApp.xcodeproj`

### Setting up a test application with your personal account

1. Change [team](https://developers.mindbox.ru/docs/ios-get-keys) and bundle identifiers and App Group name for next targets:
  - ExampleApp
  - MindboxNotificationServiceExtension
  - MindboxNotificationContentExtension
2. [Configure your endpoints](https://developers.mindbox.ru/docs/add-ios-integration).
3. Change domain and endpoints in the `AppDelegate.swift` to yours.

### SDK functionality testing

1. To check innap when opening:
  - [Read this](https://help.mindbox.ru/docs/in-app-what-is)
  - Open app
2. To check the inapp anywhere in the application:
  - [Read this](https://help.mindbox.ru/docs/in-app-location)
  - Replace `operationSystemName` in `didTapButtonAsync` and `didTapButtonSync`
  - Click to the button `Show in-app (with executeAsyncOperation)` or `Show in-app (with executeSyncOperation)`
3. To check push notifications:
  - [Read this](https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced)
  - Send a notification from your account
4. To check rich notifications:
  - [Read this](https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced)
  - Send a notification from your account

### Additionally
  - Currently the In-App only comes once per session
  - There are comments and links in the ExampleApp code that can help you

