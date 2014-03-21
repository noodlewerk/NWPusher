//
//  NWPusher.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPusher.h"
#import "NWSSLConnection.h"
#import "NWSecTools.h"
#import "NWNotification.h"


// http://developer.apple.com/library/mac/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingWIthAPS/CommunicatingWIthAPS.html

static NSString * const NWSandboxPushHost = @"gateway.sandbox.push.apple.com";
static NSString * const NWPushHost = @"gateway.push.apple.com";
static NSUInteger const NWPushPort = 2195;

@implementation NWPusher {
    NSUInteger _index;
}


#pragma mark - Apple SSL

#if !TARGET_OS_IPHONE

- (NWPusherResult)connectWithCertificateRef:(SecCertificateRef)certificate
{
    SecIdentityRef identity = NULL;
    NWPusherResult result = [NWSecTools identityWithCertificateRef:certificate identity:&identity];
    if (result != kNWPusherResultSuccess) {
        if (identity) CFRelease(identity);
        return result;
    }
    result = [self connectWithIdentityRef:identity];
    if (identity) CFRelease(identity);
    return result;
}

#endif

- (NWPusherResult)connectWithIdentityRef:(SecIdentityRef)identity
{
    SecCertificateRef certificate = [NWSecTools certificateForIdentity:identity];
    if (!certificate) return kNWPusherResultCertificateNotFound;
    BOOL sandbox = [NWSecTools isSandboxCertificate:certificate];
    CFRelease(certificate);
    NSString *host = sandbox ? NWSandboxPushHost : NWPushHost;
    
    if (_connection) [_connection disconnect]; _connection = nil;
    NWSSLConnection *connection = [[NWSSLConnection alloc] initWithHost:host port:NWPushPort identity:identity];
    
    NWPusherResult result = [connection connect];
    if (result == kNWPusherResultSuccess) {
        _connection = connection;
    }
    return result;
}

- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password
{
    SecIdentityRef identity = NULL;
    NWPusherResult result = [NWSecTools identityWithPKCS12Data:data password:password identity:&identity];
    if (result != kNWPusherResultSuccess) {
        if (identity) CFRelease(identity);
        return result;
    }
    result = [self connectWithIdentityRef:identity];
    if (identity) CFRelease(identity);
    return result;
}

- (NWPusherResult)reconnect
{
    if (!_connection) return kNWPusherResultNotConnected;
    return [_connection reconnect];
}

- (void)disconnect
{
    [_connection disconnect]; _connection = nil;
}


#pragma mark - Apple push

- (NWPusherResult)pushPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier
{
    return [self pushNotification:[[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:nil priority:0] type:kNWNotificationType2];
}

- (NWPusherResult)pushNotification:(NWNotification *)notification type:(NWNotificationType)type
{
    return [_connection write:[notification dataWithType:type] length:NULL];
}

- (NWPusherResult)fetchFailedIdentifier:(NSUInteger *)identifier
{
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(uint8_t) * 2 + sizeof(uint32_t)];
    NSUInteger length = 0;
    NWPusherResult read = [_connection read:data length:&length];
    if (length && read == kNWPusherResultSuccess) {
        read = [NWNotification parseResponse:data identifier:identifier];
    }
    return read;
}


#pragma mark - Helpers

+ (NSString *)stringFromResult:(NWPusherResult)result
{
    switch (result) {
        case kNWPusherResultSuccess: return @"Success";
        case kNWPusherResultAPNNoErrorsEncountered: return @"APN: No errors encountered";
        case kNWPusherResultAPNProcessingError: return @"APN: Processing error";
        case kNWPusherResultAPNMissingDeviceToken: return @"APN: Missing device token";
        case kNWPusherResultAPNMissingTopic: return @"APN: Missing topic";
        case kNWPusherResultAPNMissingPayload: return @"APN: Missing payload";
        case kNWPusherResultAPNInvalidTokenSize: return @"APN: Invalid token size";
        case kNWPusherResultAPNInvalidTopicSize: return @"APN: Invalid topic size";
        case kNWPusherResultAPNInvalidPayloadSize: return @"APN: Invalid payload size";
        case kNWPusherResultAPNInvalidToken: return @"APN: Invalid token (you might need to reconnect now)";
        case kNWPusherResultAPNUnknownReason: return @"APN: Unkown reason";
        case kNWPusherResultAPNShutdown: return @"APN: Shutdown";
        case kNWPusherResultEmptyPayload: return @"Payload is empty";
        case kNWPusherResultInvalidPayload: return @"Invalid payload format";
        case kNWPusherResultEmptyToken: return @"Device token is emtpy";
        case kNWPusherResultInvalidToken: return @"Device token should be 64 hex characters)";
        case kNWPusherResultPayloadTooLong: return @"Payload cannot be more than 256 bytes (UTF8)";
        case kNWPusherResultUnexpectedResponseCommand: return @"Unexpected response command";
        case kNWPusherResultUnexpectedResponseLength: return @"Unexpected response length";
        case kNWPusherResultUnexpectedTokenLength: return @"Unexpected token length";
        case kNWPusherResultIDOutOfSync: return @"Push identifier out-of-sync :(";
        case kNWPusherResultNotConnected: return @"Not connected, connect first";
        case kNWPusherResultIOConnectFailed: return @"Unable to create connection to server";
        case kNWPusherResultIOConnectSSLContext: return @"Unable create SSL context";
        case kNWPusherResultIOConnectSocketCallbacks: return @"Unable to set socket callbacks";
        case kNWPusherResultIOConnectSSL: return @"Unable to set SSL connection ";
        case kNWPusherResultIOConnectPeerDomain: return @"Unable to set peer domain";
        case kNWPusherResultIOConnectAssignCertificate: return @"Unable to assign certificate";
        case kNWPusherResultIOConnectSSLHandshakeConnection: return @"Unable to perform SSL handshake, no connection";
        case kNWPusherResultIOConnectSSLHandshakeAuthentication: return @"Unable to perform SSL handshake, authentication failed";
        case kNWPusherResultIOConnectSSLHandshakeError: return @"Unable to perform SSL handshake";
        case kNWPusherResultIOConnectTimeout: return @"Timeout SSL handshake";
        case kNWPusherResultIOReadDroppedByServer: return @"Failed to read, connection dropped by server";
        case kNWPusherResultIOReadConnectionError: return @"Failed to read, connection error";
        case kNWPusherResultIOReadConnectionClosed: return @"Failed to read, connection closed";
        case kNWPusherResultIOReadError: return @"Failed to read";
        case kNWPusherResultIOWriteDroppedByServer: return @"Failed to write, connection dropped by server";
        case kNWPusherResultIOWriteConnectionError: return @"Failed to write, connection error";
        case kNWPusherResultIOWriteConnectionClosed: return @"Failed to write, connection closed";
        case kNWPusherResultIOWriteError: return @"Failed to write";
        case kNWPusherResultCertificateInvalid: return @"Unable to read certificate";
        case kNWPusherResultCertificatePrivateKeyMissing: return @"Unable to create identitiy, private key missing";
        case kNWPusherResultCertificateCreateIdentity: return @"Unable to create identitiy";
        case kNWPusherResultCertificateNotFound: return @"Unable to find certificate";
        case kNWPusherResultPKCS12EmptyData: return @"PKCS12 data is empty";
        case kNWPusherResultPKCS12InvalidData: return @"Unable to import PKCS12 data";
        case kNWPusherResultPKCS12NoItems: return @"No items in PKCS12 data";
        case kNWPusherResultPKCS12MutlipleItems: return @"Multiple certificates in PKCS12 data";
        case kNWPusherResultPKCS12NoIdentity: return @"No identity in PKCS12 data";
    }
    return @"Unkown";
}


#pragma mark - Deprecated

#if !TARGET_OS_IPHONE
- (NWPusherResult)connectWithCertificateRef:(SecCertificateRef)certificate sandbox:(BOOL)sandbox
{
    return [self connectWithCertificateRef:certificate];
}
#endif

- (NWPusherResult)connectWithIdentityRef:(SecIdentityRef)identity sandbox:(BOOL)sandbox
{
    return [self connectWithIdentityRef:identity];
}

- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox
{
    return [self connectWithPKCS12Data:data password:password];
}

- (NWPusherResult)pushPayloadString:(NSString *)payload token:(NSString *)token
{
    NWPusherResult result = [self pushPayloadString:payload token:token identifier:0 expires:NULL];
    return result;
}

- (NWPusherResult)pushPayloadString:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier expires:(NSDate *)expires
{
    if (!payload.length) {
        return kNWPusherResultEmptyPayload;
    }
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    if (![[NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil] count]) {
        return kNWPusherResultInvalidPayload;
    }
    return [self pushNotification:[[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expiration:expires priority:0] type:kNWNotificationType2];
}

- (NWPusherResult)pushPayloadData:(NSData *)payload tokenData:(NSData *)token
{
    NWPusherResult result = [self pushPayloadData:payload tokenData:token enhance:NO identifier:0 expires:nil];
    return result;
}

- (NWPusherResult)pushPayloadData:(NSData *)payload tokenData:(NSData *)token identifier:(NSUInteger)identifier expires:(NSDate *)expires
{
    NWPusherResult result = [self pushPayloadData:payload tokenData:token enhance:YES identifier:identifier expires:expires];
    return result;
}

- (NWPusherResult)pushPayloadData:(NSData *)payload tokenData:(NSData *)token enhance:(BOOL)enhance identifier:(NSUInteger)identifier expires:(NSDate *)expires
{
    return [self pushNotification:[[NWNotification alloc] initWithPayloadData:payload tokenData:token identifier:identifier expirationStamp:(NSUInteger)expires.timeIntervalSince1970 addExpiration:!!expires priority:0] type:kNWNotificationType2];
}

- (void)connectWithPKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox block:(void(^)(NWPusherResult response))block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NWPusherResult connected = [self connectWithPKCS12Data:data password:password];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) dispatch_async(dispatch_get_main_queue(), ^{block(connected);});
        });
    });
    
}

- (NSUInteger)pushPayloadString:(NSString *)payload tokenString:(NSString *)token block:(void(^)(NWPusherResult response))block
{
    NSUInteger identifier = ++_index;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NWPusherResult pushed = [self pushPayload:payload token:token identifier:identifier];
        if (pushed == kNWPusherResultSuccess) {
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                NSUInteger identifier2 = 0;
                NWPusherResult response = [self fetchFailedIdentifier:&identifier2];
                if (identifier2 && identifier != identifier2) response = kNWPusherResultIDOutOfSync;
                if (block) dispatch_async(dispatch_get_main_queue(), ^{block(response);});
            });
        } else {
            if (block) dispatch_async(dispatch_get_main_queue(), ^{block(pushed);});
        }
    });
    return identifier;
}

@end