//
//  NWSSLConnection.h
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWPusher.h"

@interface NWSSLConnection : NSObject

@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) NSUInteger port;
@property (nonatomic, assign) SecIdentityRef identity;

- (id)initWithHost:(NSString *)host port:(NSUInteger)port identity:(SecIdentityRef)identity;
- (NWPusherResult)connect;
- (NWPusherResult)read:(NSMutableData *)data length:(NSUInteger *)length;
- (NWPusherResult)write:(NSData *)data length:(NSUInteger *)length;
- (void)disconnect;

@end
