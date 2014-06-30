![NWPusher icon](Touch/Icon@2x.png)

Pusher
======

*iOS/OS X application and library for playing with the Apple Push Notification Service (APNS).*

<img src="Docs/osx.png" alt="Pusher OS X" width="591"/>


Installation
------------
Install the Mac app using [Homebrew cask](https://github.com/phinze/homebrew-cask):

```shell
brew cask install pusher
```

Or download the latest `Pusher.app` binary:

- [Download latest binary](https://github.com/noodlewerk/NWPusher/releases/latest)

Alternatively, you can include NWPusher as a library, using [CocoaPods](http://cocoapods.org/):

```ruby
pod 'NWPusher', '~> 0.4.3'
```

Or simply include the source files you need. NWPusher has a modular architecture and does not have any external dependencies, so use what you like.


About
-----
Testing push notifications for your iOS app can be a pain. You might consider setting up your own server or use one of the many push webservices online. Either way it's a lot of work to get all these systems connected properly.

Enter *Pusher*, a Mac and iPhone app for sending push notifications *directly* to the *Apple Push Notification Service*. No need to set up a server or create an account online. You only need the SSL certificate and a device token to start pushing directly from your Mac, or even from an iPhone!

Pusher comes with a small library for both OS X and iOS, that provides various tools for sending notifications programmatically. On OS X it can use the keychain to retrieve push certificates and keys. Pusher can also be used without keychain, using a PKCS #12 file.


Features
--------
Mac OS X application for sending push notifications through the APN service:
- Takes *certificates and keys* directly from the *keychain*
- Fully customizable *payload* with *syntax checking*
- Allows setting *expiration* and *priority*
- *Stores device tokens* so you don't have to copy-paste them every time
- Handles *PKCS #12* files (.p12)
- Automatic configuration for *sandbox*
- Reports *detailed error messages* returned by APNS
- Reads from *feedback service*

OS X/iOS library for sending pushes from your own application:
- Modular, no dependencies, use what you like
- Detailed error handling
- iOS compatible, so you can also push directly from your iPhone :o
- Demo applications for both platforms


Getting started
---------------
Before you can start sending push notification payloads, there are a few hurdles to take. First you'll need to obtain the *Apple Push Services SSL Certificate* of the app you want to send notifications to. This certificate is used by Pusher to set up the SSL connection through which the payloads will be sent to Apple.

Second you'll need the *device token* of the device you want to send your payload to. Every device has its own unique token that can only be obtained from within the app. While this might sound very complicated, it all comes down to just a few clicks on Apple's Dev Center website, some gray hairs, and a bit of patience.

### Certificate
Let's start with the SSL certificate. The goal is to get both the certificate *and* the private key into your OS X keychain. If someone else already generated this certificate, you'll need to ask him or her to export these into a PKCS12 file. If there is no certificate generated yet, you can generate the certificate and the private key in the following steps:

1. Log in to [Apple's Dev Center](https://developer.apple.com)
2. Go to the *Provisioning Portal* or *Certificates, Identifiers & Profiles*
3. Go to *Certificates* and create a *Apple Push Notification service SSL*
4. From here on you will be guided through the certificate generation process.

Keep in mind that you will eventually be downloading a certificate, which you will need to install in your keychain together with the private key. This should look something like this:

<img src="Docs/keychain1.png" alt="Keychain export" width="681"/>

Both can be exported into a PKCS12 file, which allows you to share these with fellow developers:

<img src="Docs/keychain2.png" alt="PKCS12 file" width="679"/>

### Device token
Now you need to obtain a device token, which is a 64 character hex string. This should be done from within the iOS app you're going to push to. Add the following lines to your application delegate:

```objective-c
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [UIApplication.sharedApplication  registerForRemoteNotificationTypes:
        UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge
        | UIRemoteNotificationTypeSound];
}

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)token
{
    NSLog(@"Device token: %@", token);
}

- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"Failed to get token: %@", error);
}

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)notification
{
    NSLog(@"Received push notification: %@", notification);
}
```

Now, when you run the application, the 64 character push string will be logged to the console.

### Push from OS X
With the SSL certificate and private key in the keychain and the device token on the pasteboard, you're finally ready to send some push notifications. Let's start by sending a notification using the Pusher OS X app. Open the Pusher Xcode project and run the PusherMac target:

<img src="Docs/osx.png" alt="Pusher OS X" width="591"/>

The combo box at the top lists the available SSL certificates in the keychain. Select the certificate you want to use and paste the device token of the device you're pushing to. The text field below shows the JSON formatted payload text that you're sending. Read more about this format in the Apple documentation under *Apple Push Notification Service*.

Now before you press *Push*, make sure the application you're *sending to* is in the *background*, e.g. by pressing the home button. This way you're sure the app is not going to interfere with the message, yet. Press push, wait a few seconds, and see.

If things are not working as expected, send me a message on GitHub or post an issue.

### Push from iOS
The ultimate experience is of course pushing from an iPhone to an iPhone, directly. This can be done with the Pusher iOS app. Before you run the PusherTouch target, make sure to include the *certificate, private key, and device token* inside the app. Take the PKCS12 file that you exported earlier and include it in the PusherTouch bundle. Then go to `NWAppDelegate.m` in the `Touch` folder and configure `pkcs12FileName`, `pkcs12Password`, and `deviceToken`. Now run the PusherTouch target:

<img src="Docs/ios.png" alt="Pusher iOS" width="414"/>

If everything is set up correctly, you only need to *Connect* and *Push*. Then you should receive the `Testing..` push message on the device.

Again, if things are not working as expected, send me a message on GitHub or post an issue.

Consult Apple's documentation for more info on the APNS architecture: [Apple Push Notification Service](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/ApplePushService.html)

Pushing from code
-----------------
Pusher can also be used as a library to send notifications programmatically. The included Xcode project provides examples for both OS X and iOS. The easiest way to include NWPusher is through CocoaPods:

```ruby
pod 'NWPusher', '~> 0.4.3'
```

Alternatively you can include just the files you need from the `Classes` folder. Make sure you link with `Foundation.framework` and `Security.framework`.

Before any notification can be sent, you first need to create a connection. When this connection is established, any number of payload can be sent.

*Note that Apple doesn't like it when you create a connection for every push.* Therefore be careful to reuse a connection as much as possible in order to prevent Apple from blocking.

To create a connection directly from a PKCS12 (.p12) file:

```objective-c
    NSURL *url = [NSBundle.mainBundle URLForResource:@"pusher.p12" withExtension:nil];
    NSData *pkcs12 = [NSData dataWithContentsOfURL:url];
    NWPusher *pusher = [[NWPusher alloc] init];
    NWError connect = [pusher connectWithPKCS12Data:pkcs12 password:@"pa$$word"];
    if (connect != kNWSuccess) {
        NSLog(@"Unable to connect: %@", [NWErrorUtil stringWithError:connect]);
    }
```

When pusher is successfully connected, send a payload to your device:

```objective-c
    NSString *payload = @"{\"aps\":{\"alert\":\"Testing..\"}}";
    NSString *token = @"0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF";
    NWError push = [pusher pushPayload:payload token:token identifier:rand()];
    if (push != kNWSuccess) {
        NSLog(@"Unable to sent: %@", [NWErrorUtil stringWithError:push]);
    }
```

After a second or so, we can take a look to see if the notification was accepted by Apple:

```objective-c
    NSUInteger identifier = 0;
    NWError apnError = kNWSuccess;
    NWError fetch = [pusher fetchFailedIdentifier:&identifier apnError:apnError];
    if (fetch != kNWSuccess) {
        NSLog(@"Unable to read response: %@", [NWErrorUtil stringWithError:push]);
    } else if (apnError != kNWSuccess) {
        NSLog(@"Notification with identifier %i rejected: %@", (int)identifier, [NWErrorUtil stringWithError:apnError]);
    }
```

Alternatively on OS X you can also use the keychain to obtain the SSL certificate. In that case first collect all certificates:

```objective-c
    NSArray *certificates = nil;
    NWError keychain = [NWSecTools keychainCertificates:&certificates];
    if (keychain != kNWSuccess) {
        NSLog(@"Unable to access keychain: %@", [NWErrorUtil stringWithError:keychain]);
    }
```

After selecting the right certificate, obtain the identity from the keychain:

```objective-c
    NWIdentityRef identity = nil;
    NWError ident = [NWSecTools keychainIdentityWithCertificate:certificate identity:&identity];
    if (ident != kNWSuccess) {
        NSLog(@"Unable to create identity: %@", [NWErrorUtil stringWithError:ident]);
    }
```

Take a look at the example project for variations on this approach.

Consult Apple's documentation for more info on the client-server communication: [Provider Communication](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/CommunicatingWIthAPS.html)

Feedback Service
----------------
The feedback service is part of the Apple Push Notification Service. The feedback service is basically a list containing device tokens that became invalid. Apple recommends that you read from the feedback service once every 24 hours, and no longer send notifications to listed devices. Communication with the feedback service can be done with the `NWPushFeedback` class. First connect using one of the `-connect*` methods:

```objective-c
    NSURL *url = [NSBundle.mainBundle URLForResource:@"pusher.p12" withExtension:nil];
    NSData *pkcs12 = [NSData dataWithContentsOfURL:url];
    NWPushFeedback *feedback = [[NWPushFeedback alloc] init];
    NWError connect = [feedback connectWithPKCS12Data:pkcs12 password:@"pa$$word"];
    if (connect != kNWSuccess) {
        NSLog(@"Unable to connect to feedback service: %@", [NWErrorUtil stringWithError:connect]);
    }
```

When connected read the device token and date of invalidation:

```objective-c
    NSString *token = nil;
    NSDate *date = nil;
    NWError read = [feedback readToken:&token date:&date];
    if (read == kNWErrorReadClosedGraceful) {
        NSLog(@"All tokens have been read, connection closed");
    } else if (read != kNWSuccess) {
        NSLog(@"Unable to read feedback: %@", [NWErrorUtil stringWithError:read]);
    } else {
        NSLog(@"Feedback service invalidated token: %@ on date: %@", token, date);
    }
```

Apple closes the connection after the last device token is read. Use `-readTokenDatePairs:max:` to read all device tokens in one method call.

Troubleshooting
---------------
Apple's Push Notification Service is not very forgiving in nature. If things are done in the wrong order or data is formatted incorrectly the service will refuse to deliver any notification, but generally provides few clues about went wrong and how to fix it. In the worst case, it simply disconnects without even notifying the client.

Some tips on what to look out for:

- A device token is unique to both the device, the developer's certificate, and to whether the app was built with a production or development (sandbox) certificate. Therefore make sure that the push certificate matches the app's provisioning profile exactly. This doesn't mean the tokens are always different; device tokens can be the same for different bundle identifiers.

- There are two channels through which Apple responds to sent notifications: the notification connection and the feedback connection. Both operate asynchronously, so for example after the second push has been sent, we might get a response to the first push, saying it has an invalid payload. Use a new identifier for every notification so these responses can be linked to the right notification.

Consult Apple's documentation for more troubleshooting tips: [Troubleshooting Push Notifications](https://developer.apple.com/library/mac/technotes/tn2265/_index.html)

License
-------
Pusher is licensed under the terms of the BSD 2-Clause License, see the included LICENSE file.


Authors
-------
- [Noodlewerk](http://www.noodlewerk.com/)
- [Leonard van Driel](http://www.leonardvandriel.nl/)
