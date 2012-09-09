//
//  NWSSLConnection.h
//  Pusher
//
//  Created by Leo on 9/9/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

@interface NWSSLConnection : NSObject

@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) NSUInteger port;
@property (nonatomic, assign) SecIdentityRef identity;

- (id)initWithHost:(NSString *)host port:(NSUInteger)port identity:(SecIdentityRef)identity;
- (BOOL)connect;
- (BOOL)read:(NSMutableData *)data length:(NSUInteger *)length;
- (BOOL)write:(NSData *)data length:(NSUInteger *)length;
- (void)disconnect;

@end
