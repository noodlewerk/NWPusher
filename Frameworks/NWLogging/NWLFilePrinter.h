//
//  NWLFilePrinter.h
//  NWLogging
//
//  Created by leonard on 6/6/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWLPrinter.h"


@interface NWLFilePrinter : NSObject <NWLPrinter>

@property (nonatomic, assign) NSUInteger maxLogSize;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSString *content;

- (id)init;
- (id)initWithFileName:(NSString *)name;
- (void)openPath:(NSString *)path;
- (void)sync;
- (void)clear;
- (void)close;

+ (NSString *)pathForName:(NSString *)name;

@end
