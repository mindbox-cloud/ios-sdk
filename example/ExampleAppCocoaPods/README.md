#  Getting started

This is an example of SDK [integration](https://developers.mindbox.ru/docs/ios-sdk-integration) with [CocoaPods](https://cocoapods.org).

Make sure you have CocoaPods installed or install it according to the [instructions](https://guides.cocoapods.org/using/getting-started.html#getting-started).

## Steps to launch the application

1. Install the pods
  ```ruby
  pod update
  ```
  Or
  ```ruby
  pod install
  ```
2. Open `ExampleApp.xcworkspace`
3. Change [team](https://developers.mindbox.ru/docs/ios-get-keys) and bundle identifiers and App Group name for next targets:
  - ExampleApp
  - MindboxNotificationServiceExtension
  - MindboxNotificationContentExtension

  Tip: [The App Group name should be built using the template](https://developers.mindbox.ru/docs/ios-sdk-initialization#1-настройка-appgroups) `group.cloud.Mindbox.{application bundle id}`
  
4. [Configure your endpoints](https://developers.mindbox.ru/docs/add-ios-integration)
5. Set your domain and endpoints in the `AppDelegate.swift` in `initMindbox` function (Application -> AppDelegate.swift)
6. If you want to check the effect of [In-App targeting on an operation](https://help.mindbox.ru/docs/in-app-location), then [create an operation according to the instructions](https://help.mindbox.ru/docs/операции-v-основные-сведения) and enter the system name of the operation you created in the `ViewController.swift` file in the `triggerInApp` function.
7. Build and run application
8. After a few minutes, [check the presence of your user in the personal account of the admin panel](https://developers.mindbox.ru/docs/sdk-subscribe-customer).
9. [Launch the app and send notifications to your device](https://developers.mindbox.ru/docs/mobile-push-check#проверить-что-мобильное-push-уведомление-отправляется).
