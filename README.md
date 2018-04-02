# PinterestAuth

The complete documentation for the public APIs of the `PinterestAuth` framework which wraps Pinterest.com's Oauth2 authentication process.

# Getting Started

Include the library in your `Podfile` like so:

```ruby
pod 'PinterestAuth', :git => 'https://github.com/codebasesaga/PinterestAuth/PinterestAuth.git'
```

>Note: Since `PinterestAuth` is not officially published on CocoaPods, we have to specify its location with the url.

Then run the Install command in the CocoaPods app.

# Configuring your project

In your AppDelegate.swift, `import PinterestAuth`. Then in your `AppDelegate`'s `didFinishLaunching` method, configure `Auth` with your Pinterest app's client id and client secret (available [here](https://developers.pinterest.com/apps/)):

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    Auth.client_id = "YOUR_CLIENT_ID"
    Auth.client_secret = "YOUR_CLIENT_SECRET"

    return true
}
```

In your project configuration, in the Info tab of your app target, add a URL Type with the scheme `pdkYOURCLIENTID` like so:

![](https://raw.githubusercontent.com/codebasesaga/PinterestAuth/master/Resources/url_types.png)

>FYI: This is the url scheme that Pinterest will use to redirect the user back to your app after they have logged in. Pinterest generates this scheme for your app automatically and it cannot be changed.

You may now use `Auth.url` to redirect the user to Pinterest's login in Safari.

# Letting the user log in to Pinterest.com

In order to allow the user to log in to Pinterest, we must send them to Pinterest.com in a web browser as part of the Oauth2 standard process. You can ensure the user authenticate's with Pinterest for your app by sending them to `Auth.url`:

```swift
//Open Pinterest login in Safari.app
UIApplication.shared.open(Auth.url)
```

When the user finishes signing in they will be redirected back to your app. In order to handle this, you must implement `AppDelegate`'s `openUrl` method, and inside return `Auth.requestAccessToken(…)`:

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
   return Auth.requestAccessToken(with: url) { result in
       switch result {
       case .success:
           //Token is available
       case .failure(let error):
           //Handle the error
       }
   }
}
```

This will request an access token for your app which will become available in `Auth.token` upon success and may be used to make authenticated requests to the Pinterest API on behalf of the user.

# Checking if there is a logged in user

Before making requests with `Auth.token`, you should first verify that there is a token available:

```swift
if Auth.ed {
  //User is logged in and token is available.
}
```
