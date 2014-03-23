//
//  NWSSLConnection.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWType.h"
#import <Foundation/Foundation.h>


@interface NWSSLConnection : NSObject

@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) NSUInteger port;
@property (nonatomic, strong) NWIdentityRef identity;

- (instancetype)initWithHost:(NSString *)host port:(NSUInteger)port identity:(NWIdentityRef)identity;

- (NWError)connect;
- (void)disconnect;

- (NWError)read:(NSMutableData *)data length:(NSUInteger *)length;
- (NWError)write:(NSData *)data length:(NSUInteger *)length;

// deprecated
- (SecCertificateRef)certificate __attribute__((deprecated));
- (NWError)reconnect __attribute__((deprecated));

@end
