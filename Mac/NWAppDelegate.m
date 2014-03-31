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
    NSDictionary *_config;
    NSArray *_certificateIdentityPairs;
    NSUInteger _lastSelectedIndex;
    NWCertificateRef _selectedCertificate;
    
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
    [self migrateOldConfigurationIfNeeded];
    [self loadConfig];
    [self updateCertificatePopup];
    
    NSString *payload = [_config valueForKey:@"payload"];
    _payloadField.string = payload.length ? payload : @"";
    _payloadField.font = [NSFont fontWithName:@"Courier" size:10];
    _payloadField.enabledTextCheckingTypes = 0;
    [self updatePayloadCounter];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self saveConfig];
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

- (IBAction)tokenSelected:(NSComboBox *)sender
{
    [self selectTokenAndUpdateCombo];
}

- (void)textDidChange:(NSNotification *)notification
{
    if (notification.object == _payloadField) [self updatePayloadCounter];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
//    if (notification.object == _tokenCombo) [self something];
}

- (IBAction)push:(NSButton *)sender
{
    [self addTokenAndUpdateCombo];
    [self push];
}

- (IBAction)reconnect:(NSButton *)sender
{
    [self reconnect];
}

- (void)notification:(NWNotification *)notification didFailWithResult:(NWError)result
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"failed notification: %@ %@ %lu %lu %lu", notification.payload, notification.token, notification.identifier, notification.expires, notification.priority);
        NWLogWarn(@"Notification error: %@", [NWErrorUtil stringWithError:result]);
    });
}

#pragma mark - Certificate and Identity

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

#pragma mark - Expiry and Priority

- (NSDate *)selectedExpiry
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

- (NSUInteger)selectedPriority
{
    switch(_priorityPopup.indexOfSelectedItem) {
        case 1: return 5;
        case 2: return 10;
    }
    return 0;
}

#pragma mark - Payload

- (void)updatePayloadCounter
{
    NSString *payload = _payloadField.string;
    BOOL isJSON = !![NSJSONSerialization JSONObjectWithData:[payload dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    _countField.stringValue = [NSString stringWithFormat:@"%@  %lu", isJSON ? @"" : @"malformed", payload.length];
    _countField.textColor = payload.length > 256 || !isJSON ? NSColor.redColor : NSColor.darkGrayColor;
}

- (void)upPayloadTextIndex
{
    NSString *payload = _payloadField.string;
    NSRange range = [payload rangeOfString:@"\\([0-9]+\\)" options:NSRegularExpressionSearch];
    if (range.location != NSNotFound) {
        range.location += 1;
        range.length -= 2;
        NSString *before = [payload substringToIndex:range.location];
        NSUInteger value = [payload substringWithRange:range].integerValue + 1;
        NSString *after = [payload substringFromIndex:range.location + range.length];
        _payloadField.string = [NSString stringWithFormat:@"%@%lu%@", before, value, after];
    }
}

#pragma mark - Connection

- (void)connectWithCertificateAtIndex:(NSUInteger)index
{
    if (index == 0) {
        [_certificatePopup selectItemAtIndex:0];
        _lastSelectedIndex = 0;
        [self selectCertificate:nil identity:nil];
        _tokenCombo.enabled = NO;
        [self loadSelectedToken];
    } else if (index <= _certificateIdentityPairs.count) {
        [_certificatePopup selectItemAtIndex:index];
        _lastSelectedIndex = index;
        NSArray *pair = [_certificateIdentityPairs objectAtIndex:index - 1];
        [self selectCertificate:pair[0] identity:pair[1] == NSNull.null ? nil : pair[1]];
        _tokenCombo.enabled = YES;
        [self loadSelectedToken];
    } else {
        [_certificatePopup selectItemAtIndex:_lastSelectedIndex];
        [self importIdentity];
    }
}

- (void)selectCertificate:(NWCertificateRef)certificate identity:(NWIdentityRef)identity
{
    if (_hub) {
        [_hub disconnect]; _hub = nil;
        _pushButton.enabled = NO;
        _reconnectButton.enabled = NO;
        NWLogInfo(@"Disconnected from APN");
    }
    
    _selectedCertificate = certificate;
    [self updateTokenCombo];
    
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

- (void)push
{
    NSString *payload = _payloadField.string;
    NSString *token = _tokenCombo.stringValue;
    NSDate *expiry = self.selectedExpiry;
    NSUInteger priority = self.selectedPriority;
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

#pragma mark - Config

- (NSString *)identifierWithCertificate:(NWCertificateRef)certificate
{
    BOOL sandbox = [NWSecTools isSandboxCertificate:certificate];
    NSString *summary = [NWSecTools summaryWithCertificate:certificate];
    return summary ? [NSString stringWithFormat:@"%@%@", summary, sandbox ? @"-sandbox" : @""] : nil;
}

- (NSMutableArray *)tokensWithCertificate:(NWCertificateRef)certificate create:(BOOL)create
{
    NSString *identifier = [self identifierWithCertificate:certificate];
    if (!identifier) return nil;
    NSArray *result = _config[@"identifiers"][identifier];
    if (create && !result) result = (_config[@"identifiers"][identifier] = @[].mutableCopy);
    if (result && ![result isKindOfClass:NSMutableArray.class]) result = (_config[@"identifiers"][identifier] = result.mutableCopy);
    return (NSMutableArray *)result;
}

- (BOOL)addToken:(NSString *)token certificate:(NWCertificateRef)certificate
{
    NSMutableArray *tokens = [self tokensWithCertificate:certificate create:YES];
    if (token.length && ![tokens containsObject:token]) {
        [tokens addObject:token];
        return YES;
    }
    return NO;
}

- (BOOL)removeToken:(NSString *)token certificate:(NWCertificateRef)certificate
{
    NSMutableArray *tokens = [self tokensWithCertificate:certificate create:NO];
    if (token && [tokens containsObject:token]) {
        [tokens removeObject:token];
        return YES;
    }
    return NO;
}

- (BOOL)selectToken:(NSString *)token certificate:(NWCertificateRef)certificate
{
    NSMutableArray *tokens = [self tokensWithCertificate:certificate create:YES];
    if (token && [tokens containsObject:token]) {
        [tokens removeObject:token];
        [tokens addObject:token];
        return YES;
    }
    return NO;
}

- (void)updateTokenCombo
{
    [_tokenCombo removeAllItems];
    NSArray *tokens = [self tokensWithCertificate:_selectedCertificate create:NO];
    if (tokens.count) [_tokenCombo addItemsWithObjectValues:tokens.reverseObjectEnumerator.allObjects];
}

- (void)loadSelectedToken
{
    _tokenCombo.stringValue = [[self tokensWithCertificate:_selectedCertificate create:YES] lastObject] ?: @"";
}

- (void)addTokenAndUpdateCombo
{
    BOOL added = [self addToken:_tokenCombo.stringValue certificate:_selectedCertificate];
    if (added) [self updateTokenCombo];
}

- (void)selectTokenAndUpdateCombo
{
    BOOL selected = [self selectToken:_tokenCombo.stringValue certificate:_selectedCertificate];
    if (selected) [self updateTokenCombo];
}

- (NSURL *)configFileURL
{
    NSURL *libraryURL = [[NSFileManager.defaultManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *configURL = [libraryURL URLByAppendingPathComponent:@"Pusher" isDirectory:YES];
    if (!configURL) return nil;
    NSError *error = nil;
    BOOL exists = [NSFileManager.defaultManager createDirectoryAtURL:configURL withIntermediateDirectories:YES attributes:nil error:&error];
    NWLogWarnIfError(error);
    if (!exists) return nil;
    NSURL *result = [configURL URLByAppendingPathComponent:@"config.plist"];
    if (![NSFileManager.defaultManager fileExistsAtPath:result.path]){
        NSURL *defaultURL = [NSBundle.mainBundle URLForResource:@"config" withExtension:@"plist"];
        [NSFileManager.defaultManager copyItemAtURL:defaultURL toURL:result error:&error];
        NWLogWarnIfError(error);
    }
    return result;
}

- (void)loadConfig
{
    _config = [NSDictionary dictionaryWithContentsOfURL:[self configFileURL]];
}

- (void)saveConfig
{
    if (_config.count) [_config writeToURL:[self configFileURL] atomically:NO];
}

- (void)migrateOldConfigurationIfNeeded
{
    NSURL *libraryURL = [[NSFileManager.defaultManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *configURL = [libraryURL URLByAppendingPathComponent:@"Pusher" isDirectory:YES];
    NSURL *newURL = [configURL URLByAppendingPathComponent:@"config.plist"];
    NSURL *oldURL = [configURL URLByAppendingPathComponent:@"configuration.plist"];
    if ([NSFileManager.defaultManager fileExistsAtPath:newURL.path]) return;
    if (![NSFileManager.defaultManager fileExistsAtPath:oldURL.path]) return;
    NSDictionary *old = [NSDictionary dictionaryWithContentsOfURL:oldURL];
    NSMutableDictionary *identifiers = @{}.mutableCopy;
    for (NSDictionary *d in old[@"tokens"]) {
        for (NSString *identifier in d[@"identifiers"]) {
            for (NSArray *token in d[@"development"]) {
                NSString *key = [NSString stringWithFormat:@"%@-sandbox", identifier];
                if (!identifiers[key]) identifiers[key] = @[].mutableCopy;
                [identifiers[key] addObject:token];
            }
            for (NSArray *token in d[@"production"]) {
                NSString *key = identifier;
                if (!identifiers[key]) identifiers[key] = @[].mutableCopy;
                [identifiers[key] addObject:token];
            }
        }
    }
    NSMutableDictionary *new = @{}.mutableCopy;
    new[@"payload"] = old[@"payload"];
    new[@"identifiers"] = identifiers;
    [new writeToURL:newURL atomically:NO];
    NSError *error = nil;
    [NSFileManager.defaultManager removeItemAtURL:oldURL error:&error];
    NWLogWarnIfError(error);
}

#pragma mark - Logging

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
