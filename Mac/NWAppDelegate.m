//
//  NWAppDelegate.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWAppDelegate.h"
#import "NWPusher.h"
#import "NWSecTools.h"
#import "NWLCore.h"


@implementation NWAppDelegate {
    IBOutlet NSPopUpButton *_certificatePopup;
    IBOutlet NSComboBox *_tokenCombo;
    IBOutlet NSTextView *_payloadField;
    IBOutlet NSTextField *_countField;
    IBOutlet NSTextField *_infoField;
    IBOutlet NSButton *_pushButton;
    IBOutlet NSButton *_reconnectButton;
    
    NWPusher *_pusher;
    NSDictionary *_configuration;
    NSArray *_certificates;
    NSUInteger _index;
}


#pragma mark - Application delegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NWLog(@"Application did finish launching");
    NWLAddPrinter("NWPusher", NWPusherPrinter, 0);
    NWLPrintInfo();
    
    [self loadCertificatesFromKeychain];
    [self loadConfiguration];
    
    NSString *payload = [_configuration valueForKey:@"payload"];
    _payloadField.string = payload.length ? payload : @"";
    _payloadField.font = [NSFont fontWithName:@"Courier" size:10];
    _payloadField.enabledTextCheckingTypes = 0;
    [self textDidChange:nil];
    _index = 1;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NWLRemovePrinter("NWPusher");
    NWLog(@"Application will terminate");
    [_pusher disconnect]; _pusher = nil;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
    return YES;
}


#pragma mark - UI events

- (IBAction)certificateSelected:(NSPopUpButton *)sender
{
    if (_certificatePopup.indexOfSelectedItem) {
        id certificate = [_certificates objectAtIndex:_certificatePopup.indexOfSelectedItem - 1];
        [self selectCertificate:certificate];
    } else {
        [self selectCertificate:nil];
    }
}

- (void)textDidChange:(NSNotification *)notification
{
    NSUInteger length = _payloadField.string.length;
    _countField.stringValue = [NSString stringWithFormat:@"%lu", length];
    _countField.textColor = length > 256 ? NSColor.redColor : NSColor.darkGrayColor;
}

- (IBAction)push:(NSButton *)sender
{
    if (_pusher) {
        [self push];
    } else {
        NWLogWarn(@"No certificate selected");
    }
}

- (IBAction)reconnect:(NSButton *)sender
{
    if (_pusher) {
        [self reconnect];
    } else {
        NWLogWarn(@"No certificate selected");
    }
}


#pragma mark - Actions

- (void)loadConfiguration
{
    NSURL *defaultURL = [NSBundle.mainBundle URLForResource:@"configuration" withExtension:@"plist"];
    _configuration = [NSDictionary dictionaryWithContentsOfURL:defaultURL];
    NSURL *libraryURL = [[NSFileManager.defaultManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *configURL = [libraryURL URLByAppendingPathComponent:@"Pusher" isDirectory:YES];
    if (configURL) {
        NSError *error = nil;
        BOOL exists = [NSFileManager.defaultManager createDirectoryAtURL:configURL withIntermediateDirectories:YES attributes:nil error:&error];
        NWLogWarnIfError(error);
        if (exists) {
            NSURL *plistURL = [configURL URLByAppendingPathComponent:@"configuration.plist"];
            NSDictionary *config = [NSDictionary dictionaryWithContentsOfURL:plistURL];
            if ([config isKindOfClass:NSDictionary.class]) {
                NWLogInfo(@"Read configuration from ~/Library/Pusher/configuration.plist");
                _configuration = config;
            } else if (![NSFileManager.defaultManager fileExistsAtPath:plistURL.path]){
                [_configuration writeToURL:plistURL atomically:NO];
                NWLogInfo(@"Created default configuration in ~/Library/Pusher/configuration.plist");
            } else {
                NWLogInfo(@"Unable to read configuration from ~/Library/Pusher/configuration.plist");
            }
        }
    }
}

- (void)loadCertificatesFromKeychain
{
    NSArray *certs = [NWSecTools keychainCertificates];
    if (!certs.count) {
        NWLogWarn(@"No push certificates in keychain.");
    }
    certs = [certs sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        BOOL adev = [NWSecTools isDevelopmentCertificate:(__bridge SecCertificateRef)(a)];
        BOOL bdev = [NWSecTools isDevelopmentCertificate:(__bridge SecCertificateRef)(b)];
        if (adev != bdev) {
            return adev ? NSOrderedAscending : NSOrderedDescending;
        }
        NSString *aname = [NWSecTools identifierForCertificate:(__bridge SecCertificateRef)(a)];
        NSString *bname = [NWSecTools identifierForCertificate:(__bridge SecCertificateRef)(b)];
        return [aname compare:bname];
    }];
    _certificates = certs;
    
    [_certificatePopup removeAllItems];
    [_certificatePopup addItemWithTitle:@"Select Push Certificate"];
    for (id c in _certificates) {
        BOOL development = [NWSecTools isDevelopmentCertificate:(__bridge SecCertificateRef)(c)];
        NSString *name = [NWSecTools identifierForCertificate:(__bridge SecCertificateRef)(c)];
        [_certificatePopup addItemWithTitle:[NSString stringWithFormat:@"%@ (%@)", name, development ? @"development" : @"production"]];
    }
}

- (NSArray *)tokensForCertificate:(id)certificate
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    BOOL development = [NWSecTools isDevelopmentCertificate:(__bridge SecCertificateRef)certificate];
    NSString *identifier = [NWSecTools identifierForCertificate:(__bridge SecCertificateRef)certificate];
    for (NSDictionary *dict in [_configuration valueForKey:@"tokens"]) {
        NSArray *identifiers = [dict valueForKey:@"identifiers"];
        BOOL match = !identifiers;
        for (NSString *i in identifiers) {
            if ([i isEqualToString:identifier]) {
                match = YES;
                break;
            }
        }
        if (match) {
            NSArray *tokens = development ? [dict valueForKey:@"development"] : [dict valueForKey:@"production"];
            if (tokens.count) {
                [result addObjectsFromArray:tokens];
            }
        }
    }
    return result;
}

- (void)selectCertificate:(id)certificate
{
    if (_pusher) {
        [_pusher disconnect]; _pusher = nil;
        _pushButton.enabled = NO;
        _reconnectButton.enabled = NO;
        NWLogInfo(@"Disconnected from APN");
    }
    
    NSArray *tokens = [self tokensForCertificate:certificate];
    [_tokenCombo removeAllItems];
    //_tokenCombo.stringValue = @"";
    [_tokenCombo addItemsWithObjectValues:tokens];
    
    if (certificate) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NWPusher *p = [[NWPusher alloc] init];
            BOOL sandbox = [NWSecTools isDevelopmentCertificate:(__bridge SecCertificateRef)(certificate)];
            NWPusherResult connected = [p connectWithCertificateRef:(__bridge SecCertificateRef)(certificate) sandbox:sandbox];
            if (connected == kNWPusherResultSuccess) {
                NWLogInfo(@"Connected established to APN%@", sandbox ? @" (sandbox)" : @"");
                _pusher = p;
                _pushButton.enabled = YES;
                _reconnectButton.enabled = YES;
            } else {
                NWLogWarn(@"Unable to connect: %@", [NWPusher stringFromResult:connected]);
                [p disconnect];
                [self deselectCombo];
            }
        });
    }
}

- (void)push
{
    NSString *payload = _payloadField.string;
    NSString *token = _tokenCombo.stringValue;
    NSUInteger identifier = [self pushPayloadString:payload tokenString:token block:^(NWPusherResult result) {
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

- (void)reconnect
{
    NWLogInfo(@"Reconnecting..");
    _pushButton.enabled = NO;
    _reconnectButton.enabled = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NWPusherResult connected = [_pusher reconnect];
        if (connected == kNWPusherResultSuccess) {
            NWLogInfo(@"Reconnected");
            _pushButton.enabled = YES;
            _reconnectButton.enabled = YES;
        } else {
            NWLogWarn(@"Unable to reconnect: %@", [NWPusher stringFromResult:connected]);
        }
    });
}

- (void)deselectCombo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_certificatePopup selectItemAtIndex:0];
    });
}


#pragma mark - NWLogging

- (void)log:(NSString *)message warning:(BOOL)warning
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _infoField.textColor = warning ? NSColor.redColor : NSColor.blackColor;
        _infoField.stringValue = message;
    });
}

static void NWPusherPrinter(NWLContext context, CFStringRef message, void *info) {
    BOOL warning = strncmp(context.tag, "warn", 5) == 0;
    NWAppDelegate *delegate = NSApplication.sharedApplication.delegate;
    [delegate log:(__bridge NSString *)(message) warning:warning];
}

@end
