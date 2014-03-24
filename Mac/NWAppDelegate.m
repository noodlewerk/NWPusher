//
//  NWAppDelegate.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWAppDelegate.h"
#import "NWHub.h"
#import "NWNotification.h"
#import "NWSecTools.h"
#import "NWLCore.h"


@interface NWAppDelegate () <NWHubDelegate> @end

@implementation NWAppDelegate {
    IBOutlet NSPopUpButton *_certificatePopup;
    IBOutlet NSComboBox *_tokenCombo;
    IBOutlet NSTextView *_payloadField;
    IBOutlet NSTextField *_countField;
    IBOutlet NSTextField *_infoField;
    IBOutlet NSButton *_pushButton;
    IBOutlet NSButton *_reconnectButton;
    IBOutlet NSPopUpButton *_expiryPopup;
    IBOutlet NSPopUpButton *_priorityPopup;

    NWHub *_hub;
    NSDictionary *_configuration;
    NSArray *_certificateIdentityPairs;
    NSUInteger _lastSelectedIndex;
    
    dispatch_queue_t _serial;
}


#pragma mark - Application delegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NWLog(@"Application did finish launching");
    NWLAddPrinter("NWPusher", NWPusherPrinter, 0);
    NWLPrintInfo();
    _serial = dispatch_queue_create("NWAppDelegate", DISPATCH_QUEUE_SERIAL);
    
    _certificateIdentityPairs = @[];
    [self loadCertificatesFromKeychain];
    [self loadConfiguration];
    [self updateCertificatePopup];
    
    NSString *payload = [_configuration valueForKey:@"payload"];
    _payloadField.string = payload.length ? payload : @"";
    _payloadField.font = [NSFont fontWithName:@"Courier" size:10];
    _payloadField.enabledTextCheckingTypes = 0;
    [self textDidChange:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NWLRemovePrinter("NWPusher");
    NWLog(@"Application will terminate");
    [_hub disconnect]; _hub.delegate = nil; _hub = nil;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
    return YES;
}


#pragma mark - Events

- (IBAction)certificateSelected:(NSPopUpButton *)sender
{
    [self connectWithCertificateAtIndex:_certificatePopup.indexOfSelectedItem];
}

- (NSDate *)expirySelected
{
    switch(_expiryPopup.indexOfSelectedItem) {
        case 1: return [NSDate dateWithTimeIntervalSince1970:0];
        case 2: return [NSDate dateWithTimeIntervalSinceNow:60];
        case 3: return [NSDate dateWithTimeIntervalSince1970:300];
        case 4: return [NSDate dateWithTimeIntervalSinceNow:3600];
        case 5: return [NSDate dateWithTimeIntervalSinceNow:86400];
        case 6: return [NSDate dateWithTimeIntervalSince1970:1];
        case 7: return [NSDate dateWithTimeIntervalSince1970:UINT32_MAX];
    }
    return nil;
}

- (NSUInteger)prioritySelected
{
    switch(_priorityPopup.indexOfSelectedItem) {
        case 1: return 5;
        case 2: return 10;
    }
    return 0;
}

- (void)textDidChange:(NSNotification *)notification
{
    NSString *payload = _payloadField.string;
    BOOL isJSON = !![NSJSONSerialization JSONObjectWithData:[payload dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    _countField.stringValue = [NSString stringWithFormat:@"%@  %lu", isJSON ? @"" : @"malformed", payload.length];
    _countField.textColor = payload.length > 256 || !isJSON ? NSColor.redColor : NSColor.darkGrayColor;
}

- (IBAction)push:(NSButton *)sender
{
    if (_hub) {
        [self push];
    } else {
        NWLogWarn(@"No certificate selected");
    }
}

- (IBAction)reconnect:(NSButton *)sender
{
    if (_hub) {
        [self reconnect];
    } else {
        NWLogWarn(@"No certificate selected");
    }
}

- (void)notification:(NWNotification *)notification didFailWithResult:(NWError)result
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"failed notification: %@ %@ %lu %lu %lu", notification.payload, notification.token, notification.identifier, notification.expires, notification.priority);
        NWLogWarn(@"Notification error: %@", [NWErrorUtil stringWithError:result]);
    });
}

- (void)upPayloadTextIndex
{
    NSString *payload = _payloadField.string;
    NSRange range = [payload rangeOfString:@"Testing.. \\([0-9]+\\)" options:NSRegularExpressionSearch];
    if (range.location != NSNotFound) {
        range.location += 11;
        range.length -= 12;
        NSString *before = [payload substringToIndex:range.location];
        NSUInteger value = [payload substringWithRange:range].integerValue + 1;
        NSString *after = [payload substringFromIndex:range.location + range.length];
        _payloadField.string = [NSString stringWithFormat:@"%@%lu%@", before, value, after];
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
    NSArray *certs = nil;
    NWError keychain = [NWSecTools keychainCertificates:&certs];
    if (keychain != kNWSuccess) {
        NWLogWarn(@"Unable to access keychain: %@", [NWErrorUtil stringWithError:keychain]);
    }
    if (!certs.count) {
        NWLogWarn(@"No push certificates in keychain.");
    }
    certs = [certs sortedArrayUsingComparator:^NSComparisonResult(NWCertificateRef a, NWCertificateRef b) {
        BOOL adev = [NWSecTools isSandboxCertificate:a];
        BOOL bdev = [NWSecTools isSandboxCertificate:b];
        if (adev != bdev) {
            return adev ? NSOrderedAscending : NSOrderedDescending;
        }
        NSString *aname = [NWSecTools summaryWithCertificate:a];
        NSString *bname = [NWSecTools summaryWithCertificate:b];
        return [aname compare:bname];
    }];
    NSMutableArray *pairs = @[].mutableCopy;
    for (NWCertificateRef c in certs) {
        [pairs addObject:@[c, NSNull.null]];
    }
    _certificateIdentityPairs = [_certificateIdentityPairs arrayByAddingObjectsFromArray:pairs];
}

- (void)updateCertificatePopup
{
    NSMutableString *suffix = @" ".mutableCopy;
    [_certificatePopup removeAllItems];
    [_certificatePopup addItemWithTitle:@"Select Push Certificate"];
    for (NSArray *pair in _certificateIdentityPairs) {
        NWCertificateRef certificate = pair[0];
        BOOL hasIdentity = (pair[1] != NSNull.null);
        BOOL sandbox = [NWSecTools isSandboxCertificate:certificate];
        NSString *summary = [NWSecTools summaryWithCertificate:certificate];
        [_certificatePopup addItemWithTitle:[NSString stringWithFormat:@"%@%@%@%@", hasIdentity ? @"imported: " : @"", summary, sandbox ? @" (sandbox)" : @"", suffix]];
        [suffix appendString:@" "];
    }
    [_certificatePopup addItemWithTitle:@"Import PKCS #12 file (.p12)..."];
}

- (void)connectWithCertificateAtIndex:(NSUInteger)index
{
    if (index == 0) {
        [_certificatePopup selectItemAtIndex:0];
        [self selectCertificate:nil identity:nil];
    } else if (index <= _certificateIdentityPairs.count) {
        [_certificatePopup selectItemAtIndex:index];
        _lastSelectedIndex = index;
        NSArray *pair = [_certificateIdentityPairs objectAtIndex:index - 1];
        [self selectCertificate:pair[0] identity:pair[1] == NSNull.null ? nil : pair[1]];
    } else {
        [_certificatePopup selectItemAtIndex:_lastSelectedIndex];
        [self importIdentity];
    }
}

- (NSArray *)tokensForCertificate:(id)certificate
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    BOOL sandbox = [NWSecTools isSandboxCertificate:certificate];
    NSString *summary = [NWSecTools summaryWithCertificate:certificate];
    for (NSDictionary *dict in [_configuration valueForKey:@"tokens"]) {
        NSArray *identifiers = [dict valueForKey:@"identifiers"];
        BOOL match = !identifiers;
        for (NSString *i in identifiers) {
            if ([i isEqualToString:summary]) {
                match = YES;
                break;
            }
        }
        if (match) {
            NSArray *tokens = sandbox ? [dict valueForKey:@"development"] : [dict valueForKey:@"production"];
            if (tokens.count) {
                [result addObjectsFromArray:tokens];
            }
        }
    }
    return result;
}

- (void)selectCertificate:(NWCertificateRef)certificate identity:(NWIdentityRef)identity
{
    if (_hub) {
        [_hub disconnect]; _hub = nil;
        _pushButton.enabled = NO;
        _reconnectButton.enabled = NO;
        NWLogInfo(@"Disconnected from APN");
    }
    
    NSArray *tokens = [self tokensForCertificate:certificate];
    [_tokenCombo removeAllItems];
    //_tokenCombo.stringValue = @"";
    [_tokenCombo addItemsWithObjectValues:tokens];
    
    if (certificate) {
        NWLogInfo(@"Connecting...");
        
        dispatch_async(_serial, ^{
            NWHub *hub = [[NWHub alloc] initWithDelegate:self];
            NWError connected = kNWSuccess;
            NWIdentityRef ident = identity;
            if (!ident) {
                connected = [NWSecTools keychainIdentityWithCertificate:certificate identity:&ident];
            }
            if (connected == kNWSuccess) {
                connected = [hub connectWithIdentity:ident];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (connected == kNWSuccess) {
                    BOOL sandbox = [NWSecTools isSandboxCertificate:certificate];
                    NSString *summary = [NWSecTools summaryWithCertificate:certificate];
                    NWLogInfo(@"Connected to APN: %@%@", summary, sandbox ? @" (sandbox)" : @"");
                    _hub = hub;
                    _pushButton.enabled = YES;
                    _reconnectButton.enabled = YES;
                } else {
                    NWLogWarn(@"Unable to connect: %@", [NWErrorUtil stringWithError:connected]);
                    [hub disconnect];
                    [_certificatePopup selectItemAtIndex:0];
                }
            });
        });
    }
}

- (void)importIdentity
{
    NWLogInfo(@"");
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = YES;
    panel.allowedFileTypes = @[@"p12"];
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result != NSFileHandlingPanelOKButton) {
            return;
        }
        NSMutableArray *pairs = @[].mutableCopy;
        for (NSURL *url in panel.URLs) {
            NSString *text = [NSString stringWithFormat:@"Enter password for %@", url.lastPathComponent];
            NSAlert *alert = [NSAlert alertWithMessageText:text defaultButton:@"OK" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@""];
            NSSecureTextField *input = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
            alert.accessoryView = input;
            NSInteger button = [alert runModal];
            if (button != NSAlertDefaultReturn) {
                return;
            }
            NSString *password = input.stringValue;
            NSData *data = [NSData dataWithContentsOfURL:url];
            NSArray *ids = nil;
            NWError identdata = [NWSecTools identitiesWithPKCS12Data:data password:password identities:&ids];
            if (identdata != kNWSuccess) {
                NWLogWarn(@"Unable to read p12 file: %@", [NWErrorUtil stringWithError:identdata]);
                return;
            }
            for (NWIdentityRef identity in ids) {
                NWCertificateRef certificate = nil;
                NWError certident = [NWSecTools certificateWithIdentity:identity certificate:&certificate];
                if (certident != kNWSuccess) {
                    NWLogWarn(@"Unable to import p12 file: %@", [NWErrorUtil stringWithError:certident]);
                    return;
                }
                [pairs addObject:@[certificate, identity]];
            }
        }
        if (!pairs.count) {
            NWLogWarn(@"Unable to import p12 file: no push certificates found");
            return;
        }
        NWLogInfo(@"Imported %i certificate%@", (int)pairs.count, pairs.count == 1 ? @"" : @"s");
        NSUInteger index = _certificateIdentityPairs.count;
        _certificateIdentityPairs = [_certificateIdentityPairs arrayByAddingObjectsFromArray:pairs];
        [self updateCertificatePopup];
        [self connectWithCertificateAtIndex:index + 1];
    }];
}

- (void)push
{
    NSString *payload = _payloadField.string;
    NSString *token = _tokenCombo.stringValue;
    NSDate *expiry = self.expirySelected;
    NSUInteger priority = self.prioritySelected;
    NWLogInfo(@"Pushing..");
    dispatch_async(_serial, ^{
        NWNotification *notification = [[NWNotification alloc] initWithPayload:payload token:token identifier:0 expiration:expiry priority:priority];
        NSUInteger failed = [_hub pushNotifications:@[notification] autoReconnect:NO];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_after(popTime, _serial, ^(void){
            NSUInteger failed2 = failed + [_hub flushFailed];
            if (!failed2) NWLogInfo(@"Payload has been pushed");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self upPayloadTextIndex];
            });
        });
    });
}

- (void)reconnect
{
    NWLogInfo(@"Reconnecting..");
    _pushButton.enabled = NO;
    _reconnectButton.enabled = NO;
    dispatch_async(_serial, ^{
        NWError connected = [_hub reconnect];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (connected == kNWSuccess) {
                NWLogInfo(@"Reconnected");
                _pushButton.enabled = YES;
            } else {
                NWLogWarn(@"Unable to reconnect: %@", [NWErrorUtil stringWithError:connected]);
            }
            _reconnectButton.enabled = YES;
        });
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
    id delegate = NSApplication.sharedApplication.delegate;
    [delegate log:(__bridge NSString *)message warning:warning];
}

@end
