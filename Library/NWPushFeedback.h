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
- (NWPusherResult)connectWithCertificateData:(NSData *)certificate sandbox:(BOOL)sandbox;
#endif
- (NWPusherResult)connectWithIdentity:(SecIdentityRef)identity sandbox:(BOOL)sandbox;
- (NWPusherResult)connectWithPKCS12Data:(NSData *)data password:(NSString *)password sandbox:(BOOL)sandbox;
- (NWPusherResult)readDate:(NSDate **)date token:(NSData **)token;
- (void)disconnect;

@end
