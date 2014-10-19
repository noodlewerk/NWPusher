//
//  NWPushFeedback.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>


@interface NWPushFeedback : NSObject

- (BOOL)connectWithIdentity:(NWIdentityRef)identity error:(NSError **)error;
- (BOOL)connectWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError **)error;
- (void)disconnect;

- (BOOL)readTokenData:(NSData **)token date:(NSDate **)date error:(NSError **)error;
- (BOOL)readToken:(NSString **)token date:(NSDate **)date error:(NSError **)error;
- (NSArray *)readTokenDatePairsWithMax:(NSUInteger)max error:(NSError **)error;

// deprecated

- (NWError)connectWithIdentity:(NWIdentityRef)identity __deprecated;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password __deprecated;
- (NWError)readTokenData:(NSData **)token date:(NSDate **)date __deprecated;
- (NWError)readToken:(NSString **)token date:(NSDate **)date __deprecated;
- (NWError)readTokenDatePairs:(NSArray **)pairs max:(NSUInteger)max __deprecated;

@end
