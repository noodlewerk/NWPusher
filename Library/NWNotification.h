//
//  NWNotification.h
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWPusher.h"
#import <Foundation/Foundation.h>


@interface NWNotification : NSObject

@property (nonatomic, strong) NSData *payload;
@property (nonatomic, strong) NSData *token;
@property (nonatomic, assign) NSUInteger identifier;
@property (nonatomic, assign) NSUInteger expires;
@property (nonatomic, assign) NSUInteger priority;

- (id)initWithPayloadString:(NSString *)payload tokenString:(NSString *)token identifier:(NSUInteger)identifier expirationDate:(NSDate *)date priority:(NSUInteger)priority;
- (id)initWithPayload:(NSData *)payload token:(NSData *)token identifier:(NSUInteger)identifier expires:(NSUInteger)expires priority:(NSUInteger)priority;

- (void)setPayloadString:(NSString *)string;
- (void)setTokenString:(NSString *)hex;
- (void)setExpirationDate:(NSDate *)date;

- (NSData *)dataWithType:(NWNotificationType)type;
- (NWPusherResult)validate;

+ (NSData *)dataFromHex:(NSString *)hex;
+ (NSString *)hexFromData:(NSData *)data;

@end
