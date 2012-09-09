//
//  NWLTools.h
//  NWLogging
//
//  Created by leonard on 6/6/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

@interface NWLTools : NSObject

+ (NSString *)dateMark;
+ (NSString *)bundleInfo;
+ (NSString *)formatTag:(NSString *)tag lib:(NSString *)lib file:(NSString *)file line:(NSUInteger)line function:(NSString *)function message:(NSString *)message;

@end
