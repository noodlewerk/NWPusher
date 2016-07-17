//
//  NWAppDelegate.m
//  Pusher
//
//  Copyright (c) 2013 noodlewerk. All rights reserved.
//

#import "NWAppDelegate.h"
#import <PusherKit/PusherKit.h>

// TODO: Export your push certificate and key in PKCS12 format to pusher.p12 in the root of the project directory.
static NSString * const pkcs12FileName = @"pusher.p12";

// TODO: Set the password of this .p12 file below, but be careful *not* to commit passwords to a (public) repository.
static NSString * const pkcs12Password = @"pa$$word";

// TODO: Set the device token of the device you want to push to, see
//       `-application:didRegisterForRemoteNotificationsWithDeviceToken:` for more details.
static NSString * const deviceToken = @"ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789";

static NWPusherViewController *controller = nil;

@interface NWPusherViewController () <NWHubDelegate> @end

@implementation NWPusherViewController {
    UIButton *_connectButton;
    UITextField *_textField;
    UIButton *_pushButton;
    UILabel *_infoLabel;
    UISwitch *_sanboxSwitch;
    NWHub *_hub;
    NSUInteger _index;
    dispatch_queue_t _serial;
    
    NWIdentityRef _identity;
    NWCertificateRef _certificate;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    controller = self;
    NWLAddPrinter("NWPusher", NWPusherPrinter, 0);
    NWLPrintInfo();
    _serial = dispatch_queue_create("NWAppDelegate", DISPATCH_QUEUE_SERIAL);
    
    _connectButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _connectButton.frame = CGRectMake(20, 20, (self.view.bounds.size.width - 40)/2, 40);
    [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    [_connectButton addTarget:self action:@selector(connectButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_connectButton];
    
    _sanboxSwitch = [[UISwitch alloc] init];
    _sanboxSwitch.frame = CGRectMake((self.view.bounds.size.width + 40)/2, 20, 40, 40);
    [_sanboxSwitch addTarget:self action:@selector(sanboxCheckBoxDidPressed:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_sanboxSwitch];
    
    UILabel *sandboxLabel = [[UILabel alloc] init];
    sandboxLabel.frame = CGRectMake(CGRectGetMaxX(_sanboxSwitch.frame) + 10, 20, 80, 40);
    sandboxLabel.font = [UIFont systemFontOfSize:12];
    sandboxLabel.text = @"Use sandbox";
    [self.view addSubview:sandboxLabel];
    
    _textField = [[UITextField alloc] init];
    _textField.frame = CGRectMake(20, 70, self.view.bounds.size.width - 40, 26);
    _textField.text = @"Testing..";
    _textField.borderStyle = UITextBorderStyleBezel;
    [self.view addSubview:_textField];
    
    _pushButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _pushButton.frame = CGRectMake(20, 106, self.view.bounds.size.width - 40, 40);
    [_pushButton setTitle:@"Push" forState:UIControlStateNormal];
    [_pushButton addTarget:self action:@selector(push) forControlEvents:UIControlEventTouchUpInside];
    _pushButton.enabled = NO;
    [self.view addSubview:_pushButton];
    
    _infoLabel = [[UILabel alloc] init];
    _infoLabel.frame = CGRectMake(20, 156, self.view.bounds.size.width - 40, 60);
    _infoLabel.font = [UIFont systemFontOfSize:12];
    _infoLabel.numberOfLines = 0;
    [self.view addSubview:_infoLabel];
    
    NWLogInfo(@"Connect with Apple's Push Notification service");
    
    [self loadCertificate];
}

- (void)loadCertificate
{
    NSURL *url = [NSBundle.mainBundle URLForResource:pkcs12FileName withExtension:nil];
    NSData *pkcs12 = [NSData dataWithContentsOfURL:url];
    NSError *error = nil;
    
    NSArray *ids = [NWSecTools identitiesWithPKCS12Data:pkcs12 password:pkcs12Password error:&error];
    if (!ids) {
        NWLogWarn(@"Unable to read p12 file: %@", error.localizedDescription);
        return;
    }
    for (NWIdentityRef identity in ids) {
        NSError *error = nil;
        NWCertificateRef certificate = [NWSecTools certificateWithIdentity:identity error:&error];
        if (!certificate) {
            NWLogWarn(@"Unable to import p12 file: %@", error.localizedDescription);
            return;
        }
        
        _identity = identity;
        _certificate = certificate;
    }
}

- (IBAction)sanboxCheckBoxDidPressed:(UISwitch *)sender
{
    if (_certificate)
    {
        [self disconnect];
        [self connectToEnvironment:[self selectedEnvironmentForCertificate:_certificate]];
    }
}

- (NWEnvironment)selectedEnvironmentForCertificate:(NWCertificateRef)certificate
{
    return _sanboxSwitch.isOn ? NWEnvironmentSandbox : NWEnvironmentProduction;
}

- (NWEnvironment)preferredEnvironmentForCertificate:(NWCertificateRef)certificate
{
    NWEnvironmentOptions environmentOptions = [NWSecTools environmentOptionsForCertificate:certificate];
    
    return (environmentOptions & NWEnvironmentOptionSandbox) ? NWEnvironmentSandbox : NWEnvironmentProduction;
}

- (void)connectButtonPressed
{
    if (_hub)
    {
        [self disconnect];
        _connectButton.enabled = YES;
        [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        return;
    }

    NWEnvironment preferredEnvironment = [self preferredEnvironmentForCertificate:_certificate];
    
    [self connectToEnvironment:preferredEnvironment];
}

- (void)disconnect
{
    [self disableButtons];
    [_hub disconnect]; _hub = nil;
    NWLogInfo(@"Disconnected");
}

- (void)connectToEnvironment:(NWEnvironment)environment
{
    [self disableButtons];
    
    NWLogInfo(@"Connecting..");
    dispatch_async(_serial, ^{
        NSError *error = nil;
        
        NWHub *hub = [NWHub connectWithDelegate:self identity:_identity environment:environment error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (hub) {
                NSString *summary = [NWSecTools summaryWithCertificate:_certificate];
                NWLogInfo(@"Connected to APN: %@ (%@)", summary, descriptionForEnvironent(environment));
                _hub = hub;
                
                [_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
            } else {
                NWLogWarn(@"Unable to connect: %@", error.localizedDescription);
            }
            
            [self enableButtonsForCertificate:_certificate environment:environment];
        });
    });
}

- (void)push
{
    NSString *payload = [NSString stringWithFormat:@"{\"aps\":{\"alert\":\"%@\",\"badge\":1,\"sound\":\"default\"}}", _textField.text];
    NSString *token = deviceToken;
    NWLogInfo(@"Pushing..");
    dispatch_async(_serial, ^{
        NSUInteger failed = [_hub pushPayload:payload token:token];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_after(popTime, _serial, ^(void){
            NSUInteger failed2 = failed + [_hub readFailed];
            if (!failed2) NWLogInfo(@"Payload has been pushed");
        });
    });
}

- (void)notification:(NWNotification *)notification didFailWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"failed notification: %@ %@ %lu %lu %lu", notification.payload, notification.token, notification.identifier, notification.expires, notification.priority);
        NWLogWarn(@"Notification error: %@", error.localizedDescription);
    });
}

#pragma mark - BUtton states

- (void)disableButtons
{
    _pushButton.enabled = NO;
    _connectButton.enabled = NO;
    _sanboxSwitch.enabled = NO;
}

- (void)enableButtonsForCertificate:(NWCertificateRef)certificate environment:(NWEnvironment)environment
{
    NWEnvironmentOptions environmentOptions = [NWSecTools environmentOptionsForCertificate:certificate];
    
    BOOL shouldEnableEnvButton = (environmentOptions == NWEnvironmentOptionAny);
    BOOL shouldSelectSandboxEnv = (environment == NWEnvironmentSandbox);
    
    _pushButton.enabled = YES;
    _connectButton.enabled = YES;
    _sanboxSwitch.enabled = shouldEnableEnvButton;
    _sanboxSwitch.on = shouldSelectSandboxEnv;
}

#pragma mark - NWLogging

- (void)log:(NSString *)message warning:(BOOL)warning
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _infoLabel.textColor = warning ? UIColor.redColor : UIColor.blackColor;
        _infoLabel.text = message;
    });
}

static void NWPusherPrinter(NWLContext context, CFStringRef message, void *info) {
    BOOL warning = strncmp(context.tag, "warn", 5) == 0;
    [controller log:(__bridge NSString *)message warning:warning];
}

@end


@implementation NWAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    NWPusherViewController *controller = [[NWPusherViewController alloc] init];
    self.window.rootViewController = controller;
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
