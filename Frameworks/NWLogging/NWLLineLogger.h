//
//  NWLLineLogger.h
//  NWLogging
//
//  Created by leonard on 6/7/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//


extern const char *NWLLineLoggerMessage;
extern const char *NWLLineLoggerAscii;

#ifdef __OBJC__

@interface NWLLineLogger : NSObject

+ (void)start:(NSUInteger)info;
+ (void)start;
+ (void)stop;

+ (NSString *)tag;
+ (NSString *)lib;
+ (NSString *)file;
+ (NSUInteger)line;
+ (NSString *)function;
+ (NSString *)message;
+ (NSString *)ascii;
+ (NSUInteger)info;

@end

#endif
