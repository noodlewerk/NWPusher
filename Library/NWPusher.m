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
    NWSSLConnection *_connection;
    NSUInteger _index;
}


#pragma mark - Apple SSL

#if !TARGET_OS_IPHONE

- (NWPusherResult)connectWithCertificateRef:(SecCertificateRef)certificate sandbox:(BOOL)sandbox
{
    SecIdentityRef identity = NULL;
    NWPusherResult result = [NWSecTools identityWithCertificateRef:certificate identity:&identity];
    if (result != kNWPusherResultSuccess) {
        if (identity) CFRelease(identity);
        return result;
    }
    result = [self connectWithIdentityRef:identity sandbox:sandbox];
    if (identity) CFRelease(identity);
    return result;
}

#endif

- (NWPusherResult)connectWithIdentityRef:(SecIdentityRef)identity sandbox:(BOOL)sandbox
{
    NSString *host = sandbox ? NWSandboxPushHost : NWPushHost;
    
    if (_connection) [_connection disconnect]; _connection = nil;
    NWSSLConnection *connection = [[NWSSLConnection alloc] initWithHost:host port:NWPushPort identity:identity];
    
    NWPusherResult result = [connection connect];
    if (result == kNWPusherResultSuccess) {
        _connection = connection;
    }
    return result;
}

- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox
{
    SecIdentityRef identity = NULL;
    NWPusherResult result = [NWSecTools identityWithPKCS12Data:data password:password identity:&identity];
    if (result != kNWPusherResultSuccess) {
        if (identity) CFRelease(identity);
        return result;
    }
    result = [self connectWithIdentityRef:identity sandbox:sandbox];
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
    if (!payload.length) {
        return kNWPusherResultEmptyPayload;
    }
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    if (![[NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil] count]) {
        return kNWPusherResultInvalidPayload;
    }
    return [self pushNotification:[[NWNotification alloc] initWithPayloadString:payload tokenString:token identifier:identifier expirationDate:nil priority:0] type:kNWNotificationType2];
}

- (NWPusherResult)pushNotification:(NWNotification *)notification type:(NWNotificationType)type
{
    NWPusherResult result = [notification validate];
    if (result != kNWPusherResultSuccess) {
        return result;
    }
    NSData *data = [notification dataWithType:type];
    return [_connection write:data length:NULL];
}

- (NWPusherResult)fetchFailedIdentifier:(NSUInteger *)identifier
{
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(uint8_t) * 2 + sizeof(uint32_t)];
    NSUInteger length = 0;
    NWPusherResult read = [_connection read:data length:&length];
    if (read != kNWPusherResultSuccess) {
        return kNWPusherResultUnableToReadResponse;
    }
    
    if (length) {
        uint8_t command = 0;
        [data getBytes:&command range:NSMakeRange(0, 1)];
        if (command != 8) {
            return kNWPusherResultUnexpectedResponseCommand;
        }
        if (length != data.length) {
            return kNWPusherResultUnexpectedResponseLength;
        }
        uint8_t status = 0;
        [data getBytes:&status range:NSMakeRange(1, 1)];
        uint32_t ID = 0;
        [data getBytes:&ID range:NSMakeRange(2, 4)];
        if (identifier) *identifier = htonl(ID);
        switch (status) {
            case 0: return kNWPusherResultAPNNoErrorsEncountered;
            case 1: return kNWPusherResultAPNProcessingError;
            case 2: return kNWPusherResultAPNMissingDeviceToken;
            case 3: return kNWPusherResultAPNMissingTopic;
            case 4: return kNWPusherResultAPNMissingPayload;
            case 5: return kNWPusherResultAPNInvalidTokenSize;
            case 6: return kNWPusherResultAPNInvalidTopicSize;
            case 7: return kNWPusherResultAPNInvalidPayloadSize;
            case 8: return kNWPusherResultAPNInvalidToken;
            case 10: return kNWPusherResultAPNShutdown;
        }
        return kNWPusherResultAPNUnknownReason;
    }
    
    return kNWPusherResultSuccess;
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
        case kNWPusherResultUnableToReadResponse: return @"Unable to read response";
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
        case kNWPusherResultPKCS12NoIdentity: return @"No identity in PKCS12 data";
    }
    return @"Unkown";
}


#pragma mark - Deprecated

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
    return [self pushNotification:[[NWNotification alloc] initWithPayloadString:payload tokenString:token identifier:identifier expirationDate:expires priority:0] type:kNWNotificationType2];
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
    return [self pushNotification:[[NWNotification alloc] initWithPayload:payload token:token identifier:identifier expires:(NSUInteger)expires.timeIntervalSince1970 priority:0] type:kNWNotificationType2];
}

- (void)connectWithPKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox block:(void(^)(NWPusherResult response))block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NWPusherResult connected = [self connectWithPKCS12Data:data password:password sandbox:YES];
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