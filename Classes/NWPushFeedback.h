//
//  NWPushFeedback.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>


@interface NWPushFeedback : NSObject

- (NWError)connectWithIdentity:(NWIdentityRef)identity;
- (NWError)connectWithPKCS12Data:(NSData *)data password:(NSString *)password;
- (void)disconnect;

- (NWError)readTokenData:(NSData **)token date:(NSDate **)date;
- (NWError)readToken:(NSString **)token date:(NSDate **)date;
- (NWError)readTokenDatePairs:(NSArray **)pairs max:(NSUInteger)max;

// deprecated
#if !TARGET_OS_IPHONE
- (NWError)connectWithCertificateRef:(SecCertificateRef)certificate __attribute__((deprecated));
#endif
- (NWError)connectWithIdentityRef:(SecIdentityRef)identity __attribute__((deprecated));

@end
