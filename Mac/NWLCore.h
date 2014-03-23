//
//  NWLCore.h
//  NWLogging
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#include <string.h>
#import <CoreFoundation/CFString.h>

#ifdef __OBJC__
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#else // __OBJC__
#include <assert.h>
#endif // __OBJC__

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

#ifndef _NWLCORE_H_
#define _NWLCORE_H_


#pragma mark - The Good, the Bad and the Macro

/** Macros for configuration stuff. */
#define NWL_STR(_a) NWL_STR_(_a)
#define NWL_STR_(_a) #_a

#ifdef NWL_LIB

#define NWL_ACTIVE 1
#define NWL_LIB_STR NWL_STR(NWL_LIB)

#else // NWL_LIB

#if DEBUG
#define NWL_ACTIVE 1
#else // DEBUG
#define NWL_ACTIVE 0
#endif // DEBUG
#define NWL_LIB_STR NULL

#endif // NWL_LIB


#pragma mark - Common logging operations

/** Log directly, bypasses all filter and forwards directly to all printers. */
#define NWLog(_format, ...)                      NWLLogWithoutFilter(NULL, NWL_LIB_STR, _format, ##__VA_ARGS__)

/** Log on the 'dbug' tag, which can be activated using NWLPrintDbug(). */
#define NWLogDbug(_format, ...)                  NWLLogWithFilter("dbug", NWL_LIB_STR, _format, ##__VA_ARGS__)

/** Log on the 'info' tag, which can be activated using NWLPrintInfo(). */
#define NWLogInfo(_format, ...)                  NWLLogWithFilter("info", NWL_LIB_STR, _format, ##__VA_ARGS__)
    
/** Log on the 'info' tag if the condition is true. */
#define NWLogInfoIf(_condition, _format, ...)    do {if (_condition) NWLogInfo(_format, ##__VA_ARGS__);} while (0)
    
/** Log on the 'warn' tag, which can be activated using NWLPrintWarn(). */
#define NWLogWarn(_format, ...)                  NWLLogWithFilter("warn", NWL_LIB_STR, _format, ##__VA_ARGS__)

/** Log on an 'warn' tag if the condition is false. */
#define NWLogWarnIfNot(_condition, _format, ...) do {if (!(_condition)) NWLogWarn(_format, ##__VA_ARGS__);} while (0)

/** Log error description on the 'warn' tag if error is not nil. */
#define NWLogWarnIfError(_error)                 NWLogWarnIfNot(!(_error), @"Caught: %@", (_error))

/** Log on a custom tag, which can be activated using NWLPrintTag(tag). */
#define NWLogTag(_tag, _format, ...)             NWLLogWithFilter((#_tag), NWL_LIB_STR, _format, ##__VA_ARGS__)

/** Convenient assert and error macros. */
#define NWAssert(_condition)                     NWLogWarnIfNot((_condition), @"Expected true condition '"#_condition@"' in %s:%i", _NWL_FILE_, __LINE__)
#define NWAssertMainThread()                     NWLogWarnIfNot(_NWL_MAIN_THREAD_, @"Expected running on main thread in %s:%i", _NWL_FILE_, __LINE__)
#define NWAssertQueue(_queue,_label)             NWLogWarnIfNot(strcmp(dispatch_queue_get_label(_queue)?:"",#_label)==0, @"Expected running on '%s', not on '%s' in %s:%i", #_label, dispatch_queue_get_label(_queue), _NWL_FILE_, __LINE__)
#define NWParameterAssert(_condition)            NWLogWarnIfNot((_condition), @"Expected parameter: '"#_condition@"' in %s:%i", _NWL_FILE_, __LINE__)
#define NWError(_error)                          do {NWLogWarnIfNot(!(_error), @"Caught: %@", (_error)); _error = nil;} while (0)


#pragma mark - Logging macros

// ARC helper
#if __has_feature(objc_arc)
#define _NWL_BRIDGE_ __bridge
#else // __has_feature(objc_arc)
#define _NWL_BRIDGE_
#endif // __has_feature(objc_arc)

// C/Objective-C support
#ifdef __OBJC__
#define _NWL_CFSTRING_(_str) ((_NWL_BRIDGE_ CFStringRef)_str)
#define _NWL_MAIN_THREAD_ [NSThread isMainThread]
#else // __OBJC__
#define _NWL_CFSTRING_(_str) CFSTR(_str)
#define _NWL_MAIN_THREAD_ (dispatch_get_main_queue() == dispatch_get_current_queue())
#endif // __OBJC__

// Misc helper macros
#define _NWL_FILE_ (strrchr((__FILE__), '/') + 1)
#define NWL_CALLER ({NSString*__line=NSThread.callStackSymbols[1];NSRange r=[__line rangeOfString:@"0x"];[NSString stringWithFormat:@"<%@>",r.length?[__line substringFromIndex:r.location]:__line];})
#define NWL_STACK(__a) ({NSArray*lines=NSThread.callStackSymbols;[lines subarrayWithRange:NSMakeRange(0,__a<lines.count?__a:lines.count)];})

#define NWLLogWithoutFilter(_tag, _lib, _fmt, ...) NWLLogWithoutFilter_(_tag, _lib, _fmt, ##__VA_ARGS__)
#define NWLLogWithFilter(_tag, _lib, _fmt, ...) NWLLogWithFilter_(_tag, _lib, _fmt, ##__VA_ARGS__)
    
#if NWL_ACTIVE
#define NWLLogWithoutFilter_(_tag, _lib, _fmt, ...) NWLForwardWithoutFilter((NWLContext){_tag, _lib, _NWL_FILE_, __LINE__, __PRETTY_FUNCTION__, NWLTime()}, _NWL_CFSTRING_(_fmt), ##__VA_ARGS__)
#define NWLLogWithFilter_(_tag, _lib, _fmt, ...) NWLForwardWithFilter((NWLContext){_tag, _lib, _NWL_FILE_, __LINE__, __PRETTY_FUNCTION__, NWLTime()}, _NWL_CFSTRING_(_fmt), ##__VA_ARGS__)
#else // NWL_ACTIVE
#define NWLLogWithoutFilter_(_tag, _lib, _fmt, ...) do {} while (0)
#define NWLLogWithFilter_(_tag, _lib, _fmt, ...) do {} while (0)
#endif // NWL_ACTIVE


#pragma mark - Type definitions

/** Types of context properties to filter on */
typedef enum {
    kNWLProperty_none     = 0,
    kNWLProperty_tag      = 1,
    kNWLProperty_lib      = 2,
    kNWLProperty_file     = 3,
    kNWLProperty_function = 4,
    kNWLProperty_count    = 5,
} NWLProperty;

/** Types of actions to take when a log context matches properties */
typedef enum {
    kNWLAction_none   = 0,
    kNWLAction_print  = 1,
    kNWLAction_break  = 2,
    kNWLAction_count  = 3,
} NWLAction;

/** The properties of a logging statement. */
typedef struct {
    const char *tag;
    const char *lib;
    const char *file;
    int line;
    const char *function;
    double time;
} NWLContext;


#pragma mark - Configuration

/** Forwards context and formatted log line to printers. */
extern void NWLForwardWithoutFilter(NWLContext context, CFStringRef format, ...) CF_FORMAT_FUNCTION(2,3);

/** Looks for the best-matching filter and performs the associated action. */
extern void NWLForwardWithFilter(NWLContext context, CFStringRef format, ...) CF_FORMAT_FUNCTION(2,3);

/** Forward printing of line to printers, return true if added. */
extern int NWLAddPrinter(const char *name, void(*)(NWLContext, CFStringRef, void *), void *info);

/** Remove a printer, returns info of the printer. */
extern void * NWLRemovePrinter(const char *name);

/** Clear the printer list. */
extern void NWLRemoveAllPrinters(void);

/** Restore the default stderr printer. */
extern void NWLRestoreDefaultPrinters(void);

/** Add the default stderr printer. */
extern void NWLAddDefaultPrinter(void);

/** Formatter tailored for debugging, with format: "[hr:mn:sc:micros Library File:line] [tag] message", to stderr. */
extern void NWLStderrPrinter(NWLContext context, CFStringRef message, void *info);


/** Tests context (like lib and file name) and returns the matching action. */
extern NWLAction NWLMatchingActionForContext(NWLContext context);

/** Activates and action for these filter properties. */
extern int NWLAddFilter(const char *tag, const char *lib, const char *file, const char *function, NWLAction action);

/** Finds filter that machtes these filter properties and returns its action. */
extern NWLAction NWLHasFilter(const char *tag, const char *lib, const char *file, const char *function);

/** Remove all filters that are included by these filter properties. */
extern int NWLRemoveMatchingFilters(const char *tag, const char *lib, const char *file, const char *function);

/** Remove all actions for all properties. */
extern void NWLRemoveAllFilters(void);

/** Restore the default print-on-warn filter. */
extern void NWLRestoreDefaultFilters(void);

/** Add the default print-on-warn filter. */
extern void NWLAddDefaultFilter(void);


/** Reset the clock on log prints to 00:00:00. */
extern void NWLResetPrintClock(void);

/** Offset the clock on log prints with seconds. */
extern void NWLOffsetPrintClock(double seconds);

/** Restore the clock on log prints to UTC time. */
extern void NWLRestorePrintClock(void);

/** Seconds since epoch. */
extern double NWLTime(void);

/** Provides clock values, returns time since epoch or since reset. */
extern void NWLClock(double time, int *hour, int *minute, int *second, int *micro);

/** Returns a human-readable summary of this logger, returns the length of the about text excluding the null byte independent of 'size'. */
extern int NWLAboutString(char *buffer, int size);

/** Log the internal state. */
extern void NWLogAbout(void);


/** Restore all internal state, including default printers, default filters, and default clock. **/
extern void NWLRestore(void);


#pragma mark - Common Configuration

/** Activate the printing of all log statements. */
extern void NWLPrintInfo(void);
extern void NWLPrintWarn(void);
extern void NWLPrintDbug(void);
extern void NWLPrintTag(const char *tag);
extern void NWLPrintAll(void);

/** Activate the printing in one lib. */
extern void NWLPrintInfoInLib(const char *lib);
extern void NWLPrintWarnInLib(const char *lib);
extern void NWLPrintDbugInLib(const char *lib);
extern void NWLPrintTagInLib(const char *tag, const char *lib);
extern void NWLPrintAllInLib(const char *lib);
    
#define NWLPrintInfoInThisLib()      NWLPrintInfoInLib(NWL_LIB_STR)
#define NWLPrintWarnInThisLib()      NWLPrintWarnInLib(NWL_LIB_STR)
#define NWLPrintDbugInThisLib()      NWLPrintDbugInLib(NWL_LIB_STR)
#define NWLPrintTagInThisLib(__tag)  NWLPrintTagInLib(__tag, NWL_LIB_STR)
#define NWLPrintAllInThisLib()       NWLPrintAllInLib(NWL_LIB_STR)
#define NWLPrintOnlyInThisLib()      do {NWLRemoveAllFilters();NWLPrintAllInLib(NWL_LIB_STR);} while (0)
    
/** Activate printing in a file or function. */
extern void NWLPrintDbugInFile(const char *file);
extern void NWLPrintAllInFile(const char *file);
extern void NWLPrintDbugInFunction(const char *function);
    
#define NWLPrintDbugInThisFile()     NWLPrintDbugInFile(_NWL_FILE_)
#define NWLPrintAllInThisFile()      NWLPrintAllInFile(_NWL_FILE_)
#define NWLPrintDbugInThisFunction() NWLPrintDbugInFunction(__PRETTY_FUNCTION__)
#define NWLPrintOnlyInThisFile()     do {NWLRemoveAllFilters();NWLPrintAllInFile(_NWL_FILE_);} while (0)
#define NWLPrintOnlyInThisFunction() do {NWLRemoveAllFilters();NWLPrintAllInFunction(__PRETTY_FUNCTION__);} while (0)

/** Activate breaking. */
extern void NWLBreakWarn(void);
extern void NWLBreakWarnInLib(const char *lib);
extern void NWLBreakTag(const char *tag);
extern void NWLBreakTagInLib(const char *tag, const char *lib);

#define NWLBreakWarnInThisLib()       NWLBreakWarnInLib(NWL_LIB_STR)
#define NWLBreakTagInThisLib(__tag)   NWLBreakTagInLib(__tag, NWL_LIB_STR)

/** Deactivate actions. */
extern void NWLClearInfo(void);
extern void NWLClearWarn(void);
extern void NWLClearDbug(void);
extern void NWLClearTag(const char *tag);
extern void NWLClearAllInLib(const char *lib);
extern void NWLClearAll(void);
    
#define NWLClearAllInThisLib()        NWLClearAllInLib(NWL_LIB_STR)
    

#pragma mark - Debugging

void NWLBreakInDebugger(void);

/** Print internal state info to stderr. */
extern void NWLDump(void);
extern void NWLDumpFlags(int active, const char *lib, int debug, const char *file, int line, const char *function);
extern void NWLDumpConfig(void);
#if DEBUG
#define NWL_DEBUG 1
#else // DEBUG
#define NWL_DEBUG 0
#endif // DEBUG
#define NWLDump() do {NWLDumpFlags(NWL_ACTIVE, NWL_LIB_STR, NWL_DEBUG, _NWL_FILE_, __LINE__, __PRETTY_FUNCTION__);NWLDumpConfig();} while (0)


#endif // _NWLCORE_H_

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus
