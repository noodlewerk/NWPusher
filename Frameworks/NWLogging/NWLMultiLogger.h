//
//  NWLMultiLogger.h
//  NWLogging
//
//  Created by leonard on 6/7/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

@protocol NWLPrinter;

@interface NWLMultiLogger : NSObject

@property (nonatomic, readonly) NSUInteger count;

- (void)addPrinter:(id<NWLPrinter>)printer;
- (void)removePrinter:(id<NWLPrinter>)printer;
- (void)removeAllPrinters;

+ (NWLMultiLogger *)shared;

@end
