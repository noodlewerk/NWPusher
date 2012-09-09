//
//  NWPushFeedback.h
//  Pusher
//
//  Created by Leo on 9/9/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

@interface NWPushFeedback : NSObject

- (BOOL)connectWithCertificateData:(NSData *)certificate sandbox:(BOOL)sandbox;
- (BOOL)connectWithIdentity:(SecIdentityRef)identity sandbox:(BOOL)sandbox;
- (BOOL)readDate:(NSDate **)date token:(NSData **)token;
- (void)disconnect;

@end
