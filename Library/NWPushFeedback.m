//
//  NWPushFeedback.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPushFeedback.h"
#import "NWSSLConnection.h"
#import "NWSecTools.h"


// http://developer.apple.com/library/mac/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingWIthAPS/CommunicatingWIthAPS.html

static NSString * const NWSandboxPushHost = @"feedback.sandbox.push.apple.com";
static NSString * const NWPushHost = @"feedback.push.apple.com";
static NSUInteger const NWPushPort = 2196;
static NSUInteger const NWTokenMaxSize = 32;

@implementation NWPushFeedback {
    NWSSLConnection *_connection;
}


#pragma mark - Apple SSL

#if !TARGET_OS_IPHONE

- (NWPusherResult)connectWithCertificateData:(NSData *)certificateData sandbox:(BOOL)sandbox
{
    SecIdentityRef identity = NULL;
    NWPusherResult result = [NWSecTools identityWithCertificateData:certificateData identity:&identity];
    if (result != kNWPusherResultSuccess) {
        return result;
    }
    result = [self connectWithIdentity:identity sandbox:sandbox];
    CFRelease(identity);
    return result;
}

#endif

- (NWPusherResult)connectWithIdentity:(SecIdentityRef)identity sandbox:(BOOL)sandbox
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
        return result;
    }
    result = [self connectWithIdentity:identity sandbox:sandbox];
    CFRelease(identity);
    return result;
}

- (void)disconnect
{
    [_connection disconnect]; _connection = nil;
}


#pragma mark - Apple push

- (NWPusherResult)readDate:(NSDate **)date token:(NSData **)token
{
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(uint32_t) + sizeof(uint16_t) + NWTokenMaxSize];
    NSUInteger length = 0;
    NWPusherResult read = [_connection read:data length:&length];
    if (read != kNWPusherResultSuccess) {
        return read;
    }
    
    if (length) {
        if (length != data.length) {
            return kNWPusherResultUnexpectedResponseLength;
        }
        
        uint32_t time = 0;
        [data getBytes:&time range:NSMakeRange(0, 4)];
        if (date) *date = [NSDate dateWithTimeIntervalSince1970:htonl(time)];
        
        uint16_t l = 0;
        [data getBytes:&l range:NSMakeRange(4, 2)];
        NSUInteger tokenLength = htons(l);
        if (tokenLength != NWTokenMaxSize) {
            return kNWPusherResultUnexpectedTokenLength;
        }
        
        if (token) *token = [data subdataWithRange:NSMakeRange(6, length - 6)];
    }
    
    return kNWPusherResultSuccess;
}

@end
