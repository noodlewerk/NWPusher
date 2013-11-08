//
//  NWPusher.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPusher.h"
#import "NWSSLConnection.h"
#import "NWSecTools.h"


// http://developer.apple.com/library/mac/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingWIthAPS/CommunicatingWIthAPS.html

static NSString * const NWSandboxPushHost = @"gateway.sandbox.push.apple.com";
static NSString * const NWPushHost = @"gateway.push.apple.com";
static NSUInteger const NWPushPort = 2195;
static NSUInteger const NWDeviceTokenSize = 32;
static NSUInteger const NWPayloadMaxSize = 256;

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

- (void)disconnect
{
    [_connection disconnect]; _connection = nil;
}


#pragma mark - Apple push

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
    
    if (!token.length) {
        return kNWPusherResultEmptyToken;
    }
    NSString *normal = [self.class filterHex:token];
    NSUInteger max = NWDeviceTokenSize * 2;
    NSString *trunk = normal.length >= max ? [normal substringToIndex:max] : nil;
    NSData *tokenData = [self.class dataFromHex:trunk];
    if (!tokenData.length) {
        return kNWPusherResultInvalidToken;
    }
    
    NWPusherResult result = [self pushPayloadData:payloadData tokenData:tokenData identifier:identifier expires:expires];
    return result;
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
    if (token.length != NWDeviceTokenSize) {
        return kNWPusherResultInvalidToken;
    }
    if (payload.length > NWPayloadMaxSize) {
        return kNWPusherResultPayloadTooLong;
    }
    
    char buffer[sizeof(uint8_t) + sizeof(uint32_t) * 2 + sizeof(uint16_t) + NWDeviceTokenSize + sizeof(uint16_t) + NWPayloadMaxSize];
    char *p = buffer;
    
    uint8_t command = enhance ? 1 : 0;
    memcpy(p, &command, sizeof(uint8_t));
    p += sizeof(uint8_t);
    
    if (enhance) {
        uint32_t ID = htonl(identifier);
        memcpy(p, &ID, sizeof(uint32_t));
        p += sizeof(uint32_t);
        
        uint32_t exp = htonl((NSUInteger)expires.timeIntervalSince1970);
        memcpy(p, &exp, sizeof(uint32_t));
        p += sizeof(uint32_t);
    }
    
    uint16_t tokenLength = htons(token.length);
    memcpy(p, &tokenLength, sizeof(uint16_t));
    p += sizeof(uint16_t);
    
    memcpy(p, token.bytes, token.length);
    p += token.length;
    
    uint16_t payloadLength = htons(payload.length);
    memcpy(p, &payloadLength, sizeof(uint16_t));
    p += sizeof(uint16_t);
    
    memcpy(p, payload.bytes, payload.length);
    p += payload.length;
    
    NSData *data = [NSData dataWithBytes:buffer length:p - buffer];
    NWPusherResult result = [_connection write:data length:NULL];
    
    return result;
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


#pragma mark - Blocked

- (void)connectWithPKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox block:(void(^)(NWPusherResult response))block
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NWPusherResult connected = [self connectWithPKCS12Data:data password:password sandbox:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) dispatch_async(dispatch_get_main_queue(), ^{block(connected);});
        });
    });
    
}

- (NSUInteger)pushPayloadString:(NSString *)payload token:(NSString *)token expires:(NSDate *)expires block:(void(^)(NWPusherResult response))block
{
    NSUInteger identifier = ++_index;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NWPusherResult pushed = [self pushPayloadString:payload token:token identifier:identifier expires:expires];
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

#pragma mark - Helpers

+ (NSString *)filterHex:(NSString *)hex
{
    hex = hex.lowercaseString;
    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSUInteger i = 0; i < hex.length; i++) {
        unichar c = [hex characterAtIndex:i];
        if ((c >= 'a' && c <= 'f') || (c >= '0' && c <= '9')) {
            [result appendString:[NSString stringWithCharacters:&c length:1]];
        }
    }
    return result;
}

+ (NSData *)dataFromHex:(NSString *)hex
{
    NSMutableData *result = [[NSMutableData alloc] init];
    char buffer[3] = {'\0','\0','\0'};
    for (NSUInteger i = 0; i < hex.length / 2; i++) {
        buffer[0] = [hex characterAtIndex:i * 2];
        buffer[1] = [hex characterAtIndex:i * 2 + 1];
        unsigned char b = strtol(buffer, NULL, 16);
        [result appendBytes:&b length:1];
    }
    return result;
}

+ (NSString *)hexFromData:(NSData *)data
{
    NSUInteger length = data.length;
    NSMutableString *result = [NSMutableString stringWithCapacity:length * 2];
    for (const unsigned char *b = data.bytes, *end = b + length; b != end; b++) {
        [result appendFormat:@"%02X", *b];
    }
    return result;
}

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
        case kNWPusherResultAPNInvalidToken: return @"APN: Invalid token";
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

@end