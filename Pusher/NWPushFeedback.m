//
//  NWPushFeedback.m
//  Pusher
//
//  Created by Leo on 9/9/12.
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
    NWSSLConnection *connection;
}


#pragma mark - Apple SSL

- (BOOL)connectWithCertificateData:(NSData *)certificateData sandbox:(BOOL)sandbox
{
    SecIdentityRef identity = NULL;
    BOOL result = [NWSecTools identityWithCertificateData:certificateData identity:&identity];
    if (!result) {
        return NO;
    }
    result = [self connectWithIdentity:identity sandbox:sandbox];
    CFRelease(identity);
    return result;
}

- (BOOL)connectWithIdentity:(SecIdentityRef)identity sandbox:(BOOL)sandbox
{
    NSString *host = sandbox ? NWSandboxPushHost : NWPushHost;
    
    if (connection) [connection disconnect];
    connection = [[NWSSLConnection alloc] initWithHost:host port:NWPushPort identity:identity];
    
    BOOL result = [connection connect];
    return result;
}

- (void)disconnect
{
	[connection disconnect]; connection = nil;
}


#pragma mark - Apple push

- (BOOL)readDate:(NSDate **)date token:(NSData **)token
{
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(uint32_t) + sizeof(uint16_t) + NWTokenMaxSize];
    NSUInteger length = 0;
    BOOL read = [connection read:data length:&length];
    if (!read) {
        return NO;
    }
    
    if (length) {
        if (length != data.length) {
            NWLogWarn(@"Unexpected response length: %@", [data subdataWithRange:NSMakeRange(0, length)]);
            return NO;
        }
        
        uint32_t time = 0;
        [data getBytes:&time range:NSMakeRange(0, 4)];
        if (date) *date = [NSDate dateWithTimeIntervalSince1970:htonl(time)];
        
        uint16_t l = 0;
        [data getBytes:&l range:NSMakeRange(4, 2)];
        NSUInteger tokenLength = htons(l);
        if (tokenLength != NWTokenMaxSize) {
            NWLogWarn(@"Unexpected token length: %i", (int)tokenLength);
            return NO;
        }
        
        if (token) *token = [data subdataWithRange:NSMakeRange(6, length - 6)];
    }
    
    return YES;
}

@end
