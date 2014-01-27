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
- (NWPusherResult)connectWithCertificateData:(NSData *)certificate;
#endif
- (NWPusherResult)connectWithIdentity:(SecIdentityRef)identity;
- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password;
- (NWPusherResult)readDate:(NSDate **)date token:(NSData **)token;
- (void)disconnect;

// deprecated
#if !TARGET_OS_IPHONE
- (NWPusherResult)connectWithCertificateData:(NSData *)certificate sandbox:(BOOL)sandbox __attribute__((deprecated));
#endif
- (NWPusherResult)connectWithIdentity:(SecIdentityRef)identity sandbox:(BOOL)sandbox __attribute__((deprecated));
- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox __attribute__((deprecated));

@end
