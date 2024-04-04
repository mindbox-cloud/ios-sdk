# Example app with SPM for Mindbox SDK for iOS

This is an example of SDK [integration](https://developers.mindbox.ru/docs/ios-sdk-integration) 

## Getting started

### Launching the application
The app has integration via cocoapods, but you can use SPM if you need.
#### Cocoapods:
1. [Clone ios-sdk repository](https://github.com/mindbox-cloud/ios-sdk).
2. Make sure you have CocoaPods installed or install it according to the instructions.
3. Go to `ios-sdk/Example/`
4. Install the pods.
  ```ruby
  pod update
  ```
  Or
  ```ruby
  pod install
  ```
5. Go to `ios-sdk/Example/Example.xcworkspace`.
6. Run file `Example.xcworkspace`.
#### SPM:
1. To deintegrate cocoapods you can use next comands:
   - `sudo gem install cocoapods-deintegrate`
   - `pod deintegrate`
   - `rm Podfile`
   - `rm Podfile.lock`
   - `rm Example.xcworkspace`
   - `rm -rf Pods`
2. Launch `Example.xcodeproj`.
3. [Read this](https://developers.mindbox.ru/docs/add-ios-sdk) and follow the initialization instructions via SPM. 

Now you can test the in-app on the simulator. 
In our admin panel there are already 3 ready-made in-apps that you can look at. 
To run the application on a real device and try push notifications, follow the instructions below.

### Setting up a Example application with your personal account (to run on a real device)

1. Change [team](https://developers.mindbox.ru/docs/ios-get-keys) and bundle identifiers and App Group name for next targets:
  - ExampleApp
  - MindboxNotificationServiceExtension
  - MindboxNotificationContentExtension
2. [Configure your endpoints](https://developers.mindbox.ru/docs/add-ios-integration).
3. Change domain and endpoints in the `AppDelegate.swift` to yours.

### SDK functionality testing

1. To check innap when opening:
  - [Read this](https://help.mindbox.ru/docs/in-app-what-is).
  - Open app.
2. To check the inapp anywhere in the application:
  - [Read this](https://help.mindbox.ru/docs/in-app-location).
  - Replace `operationSystemName` in `showInAppWithExecuteSyncOperation` and `showInAppWithExecuteAsyncOperation` in MainViewModel.
  - Click to the button `Show in-app` opposite the selected operation.
3. To check push notifications:
  - [Read this](https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced)
  - Send a notification from your account.
4. To check rich notifications:
  - [Read this](https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced)
  - Send a notification from your account.

### Additionally
  - Currently the In-App only comes once per session.
  - There are comments and links in the ExampleApp code that can help you.
