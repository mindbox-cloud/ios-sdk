# Example app for Mindbox SDK for iOS

This is an example of SDK [integration](https://developers.mindbox.ru/docs/ios-sdk).

## Getting started

### Launching the application

The app uses SPM to integrate the Mindbox SDK. Xcode will resolve and download the dependency when you open the project.

1. [Clone ios-sdk repository](https://github.com/mindbox-cloud/ios-sdk).
2. Open `ios-sdk/Example/Example.xcodeproj`.
3. To ensure you have the latest SDK version: **File → Packages → Update to Latest Package Versions**.
4. Build and run.

Now you can test the in-app on the simulator.
In our admin panel there are already 3 ready-made in-apps that you can look at.
To run the application on a real device and try push notifications, follow the instructions below.

### Setting up the Example application with your personal account (to run on a real device)

1. Change [team](https://developers.mindbox.ru/docs/ios-get-keys) and bundle identifiers and App Group name for next targets:
   - ExampleApp
   - MindboxNotificationServiceExtension
   - MindboxNotificationContentExtension
2. [Configure your endpoints](https://developers.mindbox.ru/docs/add-ios-integration).
3. Change domain and endpoints in the `AppDelegate.swift` to yours.

### SDK functionality testing

1. To check in-app when opening:
   - [Read this](https://help.mindbox.ru/docs/in-apps).
   - Open app.
2. To check the in-app anywhere in the application:
   - [Read this](https://help.mindbox.ru/docs/in-app-location).
   - Replace `operationSystemName` in `showInAppWithExecuteSyncOperation` and `showInAppWithExecuteAsyncOperation` in MainViewModel.
   - Click to the button `Show in-app` opposite the selected operation.
3. To check push notifications:
   - [Read this](https://developers.mindbox.ru/docs/mobile-push-check)
   - Send a notification from your account.
4. To check rich notifications:
   - [Read this](https://developers.mindbox.ru/docs/mobile-push-check)
   - Send a notification from your account.

### Additionally
- Currently the In-App only comes once per session.
- There are comments and links in the ExampleApp code that can help you.
