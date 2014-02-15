//
//  NWPushFeedback.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPusher.h"
#import <Foundation/Foundation.h>


@interface NWPushFeedback : NSObject

#if !TARGET_OS_IPHONE
- (NWPusherResult)connectWithCertificateRef:(SecCertificateRef)certificate;
#endif
- (NWPusherResult)connectWithIdentityRef:(SecIdentityRef)identity;
- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password;
- (NWPusherResult)readTokenData:(NSData **)token date:(NSDate **)date;
- (NWPusherResult)readToken:(NSString **)token date:(NSDate **)date;
- (NWPusherResult)readTokenDatePairs:(NSArray **)pairs max:(NSUInteger)max;
- (void)disconnect;

// deprecated
#if !TARGET_OS_IPHONE
- (NWPusherResult)connectWithCertificateData:(NSData *)certificate sandbox:(BOOL)sandbox __attribute__((deprecated));
- (NWPusherResult)connectWithCertificateData:(NSData *)certificate;
#endif
- (NWPusherResult)connectWithIdentity:(SecIdentityRef)identity sandbox:(BOOL)sandbox __attribute__((deprecated));
- (NWPusherResult)connectWithIdentity:(SecIdentityRef)identity;
- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox __attribute__((deprecated));
- (NWPusherResult)readDate:(NSDate **)date token:(NSData **)token;

@end
