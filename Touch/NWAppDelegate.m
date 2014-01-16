//
//  NWAppDelegate.m
//  Pusher
//
//  Copyright (c) 2013 noodlewerk. All rights reserved.
//

#import "NWAppDelegate.h"
#import "NWPusher.h"
#import "NWLCore.h"


static NSString * const pkcs12FileName = @"pusher.p12";
static NSString * const pkcs12Password = @"pusher";
static NSString * const deviceToken = @"ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789";

static NWPusherViewController *controller = nil;

@implementation NWPusherViewController {
    UIButton *_connectButton;
    UITextField *_textField;
    UIButton *_pushButton;
    UILabel *_infoLabel;
    NWPusher *_pusher;
    NSUInteger _index;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    controller = self;
    NWLAddPrinter("NWPusher", NWPusherPrinter, 0);
    NWLPrintInfo();
    
    _connectButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _connectButton.frame = CGRectMake(20, 20, self.view.bounds.size.width - 40, 40);
    [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    [_connectButton addTarget:self action:@selector(connect) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_connectButton];
    
    _textField = [[UITextField alloc] init];
    _textField.frame = CGRectMake(20, 70, self.view.bounds.size.width - 40, 26);
    _textField.text = @"You did it!";
    _textField.borderStyle = UITextBorderStyleBezel;
    [self.view addSubview:_textField];
    
    _pushButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _pushButton.frame = CGRectMake(20, 106, self.view.bounds.size.width - 40, 40);
    [_pushButton setTitle:@"Push" forState:UIControlStateNormal];
    [_pushButton addTarget:self action:@selector(push) forControlEvents:UIControlEventTouchUpInside];
    _pushButton.enabled = NO;
    [self.view addSubview:_pushButton];
    
    _infoLabel = [[UILabel alloc] init];
    _infoLabel.frame = CGRectMake(20, 156, self.view.bounds.size.width - 40, 26);
    _infoLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:_infoLabel];
    
    NWLogInfo(@"Connect with Apple's Push Notification service");
}

- (void)connect
{
    if (!_pusher) {
        NWLogInfo(@"Connecting..");
        _connectButton.enabled = NO;
        NWPusher *p = [[NWPusher alloc] init];
        NSURL *url = [NSBundle.mainBundle URLForResource:pkcs12FileName withExtension:nil];
        NSData *pkcs12 = [NSData dataWithContentsOfURL:url];
        [self connectWithPusher:p PKCS12Data:pkcs12 password:pkcs12Password sandbox:YES block:^(NWPusherResult response) {
            if (response == kNWPusherResultSuccess) {
                NWLogInfo(@"Connected to APN");
                _pusher = p;
                _pushButton.enabled = YES;
                [_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
            } else {
                NWLogWarn(@"Unable to connect: %@", [NWPusher stringFromResult:response]);
            }
            _connectButton.enabled = YES;
        }];
    } else {
        _pushButton.enabled = NO;
        [_pusher disconnect]; _pusher = nil;
        NWLogInfo(@"Disconnected");
        [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    }
}

- (void)connectWithPusher:(NWPusher *)pusher PKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox block:(void(^)(NWPusherResult response))block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NWPusherResult connected = [pusher connectWithPKCS12Data:data password:password sandbox:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) dispatch_async(dispatch_get_main_queue(), ^{block(connected);});
        });
    });
    
}

- (void)push
{
    NSString *payload = [NSString stringWithFormat:@"{\"aps\":{\"alert\":\"%@\"}}", _textField.text];
    NSUInteger identifier = [self pushPayloadString:payload tokenString:deviceToken block:^(NWPusherResult result) {
        if (result == kNWPusherResultSuccess) {
            NWLogInfo(@"Payload has been pushed");
        } else {
            NWLogWarn(@"Payload could not be pushed: %@", [NWPusher stringFromResult:result]);
        }
    }];
    NWLogInfo(@"Pushing payload #%i..", (int)identifier);
}

- (NSUInteger)pushPayloadString:(NSString *)payload tokenString:(NSString *)token block:(void(^)(NWPusherResult response))block
{
    NSUInteger identifier = ++_index;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NWPusherResult pushed = [_pusher pushPayloadString:payload tokenString:token identifier:identifier];
        if (pushed == kNWPusherResultSuccess) {
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                NSUInteger identifier2 = 0;
                NWPusherResult response = [_pusher fetchFailedIdentifier:&identifier2];
                if (identifier2 && identifier != identifier2) response = kNWPusherResultIDOutOfSync;
                if (block) dispatch_async(dispatch_get_main_queue(), ^{block(response);});
            });
        } else {
            if (block) dispatch_async(dispatch_get_main_queue(), ^{block(pushed);});
        }
    });
    return identifier;
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
    [controller log:(__bridge NSString *)(message) warning:warning];
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
