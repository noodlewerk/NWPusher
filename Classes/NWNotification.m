//
//  NWNotification.m
//  Pusher
//
//  Copyright (c) 2014 noodlewerk. All rights reserved.
//

#import "NWNotification.h"


static NSUInteger const NWDeviceTokenSize = 32;
static NSUInteger const NWPayloadMaxSize = 256;

@implementation NWNotification

- (instancetype)initWithPayload:(NSString *)payload token:(NSString *)token identifier:(NSUInteger)identifier expiration:(NSDate *)date priority:(NSUInteger)priority
{
    self = [super init];
    if (self) {
        self.payload = payload;
        self.token = token;
        _identifier = identifier;
        self.expiration = date;
        _priority = priority;
    }
    return self;
}

- (instancetype)initWithPayloadData:(NSData *)payload tokenData:(NSData *)token identifier:(NSUInteger)identifier expirationStamp:(NSUInteger)expirationStamp addExpiration:(BOOL)addExpiration priority:(NSUInteger)priority
{
    self = [super init];
    if (self) {
        _payloadData = payload;
        _tokenData = token;
        _identifier = identifier;
        _expirationStamp = expirationStamp;
        _addExpiration = addExpiration;
        _priority = priority;
    }
    return self;
}

#pragma mark - Accessors

- (NSString *)payload
{
    return _payloadData ? [[NSString alloc] initWithData:_payloadData encoding:NSUTF8StringEncoding] : nil;
}

- (void)setPayload:(NSString *)payload
{
    _payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)token
{
    return _tokenData ? [self.class hexFromData:_tokenData] : nil;
}

- (void)setToken:(NSString *)token
{
    if (token) {
        NSString *normal = [self.class filterHex:token];
        NSString *trunk = normal.length >= 64 ? [normal substringToIndex:64] : nil;
        _tokenData = [self.class dataFromHex:trunk];
    } else {
        _tokenData = nil;
    }
}

- (NSDate *)expiration
{
    return _addExpiration ? [NSDate dateWithTimeIntervalSince1970:_expirationStamp] : nil;
}

- (void)setExpiration:(NSDate *)date
{
    _expirationStamp = (NSUInteger)date.timeIntervalSince1970;
    _addExpiration = !!date;
}


#pragma mark - Helpers

+ (NSString *)filterHex:(NSString *)hex
{
    hex = hex.lowercaseString;
    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSUInteger i = 0; i < hex.length; i++) {
        unichar c = [hex characterAtIndex:i];
        if ((c >= 'a' && c <= 'f') || (c >= '0' && c <= '9')) {
            [result appendString:[NSString stringWithCharacters:&c length:1]];
        }
    }
    return result;
}

+ (NSData *)dataFromHex:(NSString *)hex
{
    NSMutableData *result = [[NSMutableData alloc] init];
    char buffer[3] = {'\0','\0','\0'};
    for (NSUInteger i = 0; i < hex.length / 2; i++) {
        buffer[0] = [hex characterAtIndex:i * 2];
        buffer[1] = [hex characterAtIndex:i * 2 + 1];
        unsigned char b = strtol(buffer, NULL, 16);
        [result appendBytes:&b length:1];
    }
    return result;
}

+ (NSString *)hexFromData:(NSData *)data
{
    NSUInteger length = data.length;
    NSMutableString *result = [NSMutableString stringWithCapacity:length * 2];
    for (const unsigned char *b = data.bytes, *end = b + length; b != end; b++) {
        [result appendFormat:@"%02X", *b];
    }
    return result;
}


#pragma mark - Types

- (NSData *)dataWithType:(NWNotificationType)type
{
    switch (type) {
        case kNWNotificationType0: return [self dataWithType0];
        case kNWNotificationType1: return [self dataWithType1];
        case kNWNotificationType2: return [self dataWithType2];
    }
    return nil;
}

- (NSData *)dataWithType0
{
    char buffer[sizeof(uint8_t) + sizeof(uint32_t) * 2 + sizeof(uint16_t) + NWDeviceTokenSize + sizeof(uint16_t) + NWPayloadMaxSize];
    char *p = buffer;
    
    uint8_t command = 0;
    memcpy(p, &command, sizeof(uint8_t));
    p += sizeof(uint8_t);
    
    uint16_t tokenLength = htons(_tokenData.length);
    memcpy(p, &tokenLength, sizeof(uint16_t));
    p += sizeof(uint16_t);
    
    memcpy(p, _tokenData.bytes, _tokenData.length);
    p += _tokenData.length;
    
    uint16_t payloadLength = htons(_payloadData.length);
    memcpy(p, &payloadLength, sizeof(uint16_t));
    p += sizeof(uint16_t);
    
    memcpy(p, _payloadData.bytes, _payloadData.length);
    p += _payloadData.length;
    
    return [NSData dataWithBytes:buffer length:p - buffer];
}

- (NSData *)dataWithType1
{
    char buffer[sizeof(uint8_t) + sizeof(uint32_t) * 2 + sizeof(uint16_t) + NWDeviceTokenSize + sizeof(uint16_t) + NWPayloadMaxSize];
    char *p = buffer;
    
    uint8_t command = 1;
    memcpy(p, &command, sizeof(uint8_t));
    p += sizeof(uint8_t);
    
    uint32_t ID = htonl(_identifier);
    memcpy(p, &ID, sizeof(uint32_t));
    p += sizeof(uint32_t);
    
    uint32_t exp = htonl(_expirationStamp);
    memcpy(p, &exp, sizeof(uint32_t));
    p += sizeof(uint32_t);
    
    uint16_t tokenLength = htons(_tokenData.length);
    memcpy(p, &tokenLength, sizeof(uint16_t));
    p += sizeof(uint16_t);
    
    memcpy(p, _tokenData.bytes, _tokenData.length);
    p += _tokenData.length;
    
    uint16_t payloadLength = htons(_payloadData.length);
    memcpy(p, &payloadLength, sizeof(uint16_t));
    p += sizeof(uint16_t);
    
    memcpy(p, _payloadData.bytes, _payloadData.length);
    p += _payloadData.length;
    
    return [NSData dataWithBytes:buffer length:p - buffer];
}

- (NSData *)dataWithType2
{
    NSMutableData *result = [[NSMutableData alloc] initWithLength:5];
    
    if (_tokenData) [self.class appendTo:result identifier:1 bytes:_tokenData.bytes length:_tokenData.length];
    if (_payloadData) [self.class appendTo:result identifier:2 bytes:_payloadData.bytes length:_payloadData.length];
    uint32_t identifier = htonl(_identifier);
    uint32_t expires = htonl(_expirationStamp);
    uint8_t priority = _priority;
    if (identifier) [self.class appendTo:result identifier:3 bytes:&identifier length:4];
    if (_addExpiration) [self.class appendTo:result identifier:4 bytes:&expires length:4];
    if (priority) [self.class appendTo:result identifier:5 bytes:&priority length:1];
    uint8_t command = 2;
    [result replaceBytesInRange:NSMakeRange(0, 1) withBytes:&command];
    uint32_t length = htonl(result.length - 5);
    [result replaceBytesInRange:NSMakeRange(1, 4) withBytes:&length];
        
    return result;
}

+ (void)appendTo:(NSMutableData *)buffer identifier:(NSUInteger)identifier bytes:(const void *)bytes length:(NSUInteger)length
{
    uint8_t i = identifier;
    uint16_t l = htons(length);
    [buffer appendBytes:&i length:1];
    [buffer appendBytes:&l length:2];
    [buffer appendBytes:bytes length:length];
}

@end
