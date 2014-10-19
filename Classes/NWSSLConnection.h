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

- (BOOL)connectWithError:(NSError **)error;
- (void)disconnect;

- (BOOL)read:(NSMutableData *)data length:(NSUInteger *)length error:(NSError **)error;
- (BOOL)write:(NSData *)data length:(NSUInteger *)length error:(NSError **)error;

// deprecated

- (NWError)connect __deprecated;
- (NWError)read:(NSMutableData *)data length:(NSUInteger *)length __deprecated;
- (NWError)write:(NSData *)data length:(NSUInteger *)length __deprecated;

@end
