//
//  NWPusher.h
//  Pusher
//
//  Created by Leo on 9/9/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

@interface NWPusher : NSObject

- (BOOL)connectWithCertificateRef:(SecCertificateRef)certificate sandbox:(BOOL)sandbox;
- (BOOL)connectWithIdentityRef:(SecIdentityRef)identity sandbox:(BOOL)sandbox;
- (BOOL)pushPayloadString:(NSString *)payload token:(NSString *)token;
- (BOOL)pushPayloadString:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier expires:(NSDate *)expires;
- (BOOL)pushPayloadData:(NSData *)payload tokenData:(NSData *)token;
- (BOOL)pushPayloadData:(NSData *)payload tokenData:(NSData *)token identifier:(NSUInteger)identifier expires:(NSDate *)expires;
- (BOOL)fetchFailedIdentifier:(NSUInteger *)identifier reason:(NSString **)reason;
- (void)disconnect;

@end
