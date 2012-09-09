//
//  NWLCore.h
//  NWLogging
//
//  Created by leonard on 4/25/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#include <string.h>
#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#import <CoreFoundation/CFString.h>

#ifdef __OBJC__
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#else // __OBJC__
#include <assert.h>
#endif // __OBJC__

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _NWLOGGING_H_
#define _NWLOGGING_H_

/** Logging active in debug by default. */
#ifdef NWL_LIB
    #define NWL_ACTIVE 1
    #define NWL_LIB_ NWL_LIB
    #define NWL_LIB_STR NWL_STR(NWL_LIB)
#else
    #if DEBUG
        #define NWL_ACTIVE 1
    #else
        #define NWL_ACTIVE 0
    #endif
    #define NWL_LIB_
    #define NWL_LIB_STR NULL
#endif

#if DEBUG
    #define NWL_DEBUG 1
#else
    #define NWL_DEBUG 0
#endif

    
#pragma mark - Convenient logging operations
    
#if NWL_ACTIVE
    
/** Log directly. */
#define NWLog(_format, ...)                      NWLLogWithoutFilter(, NWL_LIB_, _format, ##__VA_ARGS__)

/** Log on the 'dbug' tag. */
#define NWLogDbug(_format, ...)                  NWLLogWithFilter(dbug, NWL_LIB_, _format, ##__VA_ARGS__)
    
/** Log on the 'info' tag. */
#define NWLogInfo(_format, ...)                  NWLLogWithFilter(info, NWL_LIB_, _format, ##__VA_ARGS__)
    
/** Log on the 'warn' tag. */
#define NWLogWarn(_format, ...)                  NWLLogWithFilter(warn, NWL_LIB_, _format, ##__VA_ARGS__)

/** Log on an 'warn' tag if the condition is false. */
#define NWLogWarnIfNot(_condition, _format, ...) do {if (!(_condition)) NWLLogWithFilter(warn, NWL_LIB_, _format, ##__VA_ARGS__);} while (0)
#define NWAssert(_condition, _format, ...)       NWLogWarnIfNot(_condition, _format, ##__VA_ARGS__)

/** Log on an error object on the 'warn' tag. */
#define NWLogWarnIfError(_error)                 do {if(_error) NWLLogWithFilter(warn, NWL_LIB_, @"Caught: %@", _error);} while (0)
#define NWError(_error)                          NWLogWarnIfError(_error)

/** Log on a custom tag. */
#define NWLogTag(_tag, _format, ...)             NWLLogWithFilter(_tag, NWL_LIB_, _format, ##__VA_ARGS__)

#else
    
#define NWLog(_format, ...)                      
#define NWLogDbug(_format, ...)
#define NWLogInfo(_format, ...)                  
#define NWLogWarn(_format, ...)                  
#define NWLogWarnIfNot(_condition, _format, ...) do {break; if (_condition) {}} while (0)
#define NWLogWarnIfError(_error)                       
#define NWLogTag(_tag, _format, ...)             
    
#endif

        
#pragma mark - The Good, the Bad and the Macro

#define NWL_STR(_a) NWL_STR_(_a)
#define NWL_STR_(_a) #_a

#if __has_feature(objc_arc)
    #define _NWL_BRIDGE_ __bridge
#else
    #define _NWL_BRIDGE_
#endif

// Objective-C support
#ifdef __OBJC__
    #define _NWL_CFSTRING_(_str) ((_NWL_BRIDGE_ CFStringRef)_str)
    #define _NWL_EXCEPTION_(_msg) [NSException raise:@"NWLogging" format:@"%@", _msg]
    #define _NWL_ASSERT_(_msg) NSCAssert1(NO, @"%@", _msg)
    #define _NWL_LOG_(_msg, _fmt, ...) NSLog(_fmt, ##__VA_ARGS__)
#else // __OBJC__
    #define _NWL_CFSTRING_(_str) CFSTR(_str)
    #define _NWL_EXCEPTION_(_msg) CFShow(_msg)
    #define _NWL_ASSERT_(_msg) assert(false)
    #define _NWL_LOG_(_msg, _fmt, ...) CFShow(_msg)
#endif // __OBJC__

// Misc helper macros
#define _NWL_FILE_ (strrchr((__FILE__), '/') + 1)    
    
/** Combines the format and parameters and prints it to stderr. */
#define NWLLogWithoutFilter(_tag, _lib, _fmt, ...) NWLLogWithoutFilter_(_tag, _lib, _fmt, ##__VA_ARGS__)
#define NWLLogWithoutFilter_(_tag, _lib, _fmt, ...) do {\
        NWLContext __context = {(#_tag), (#_lib), _NWL_FILE_, __LINE__, __PRETTY_FUNCTION__};\
        CFStringRef __message = CFStringCreateWithFormat(NULL, 0, _NWL_CFSTRING_(_fmt), ##__VA_ARGS__);\
        NWLForwardToPrinters(__context, __message);\
        CFRelease(__message);\
    } while (0)

/** Looks for a match and if so combines the format and parameters and performs the required action. */
#define NWLLogWithFilter(_tag, _lib, _fmt, ...) NWLLogWithFilter_(_tag, _lib, _fmt, ##__VA_ARGS__)
#define NWLLogWithFilter_(_tag, _lib, _fmt, ...) do {\
        NWLContext __context = {(#_tag), (#_lib), _NWL_FILE_, __LINE__, __PRETTY_FUNCTION__};\
        NWLAction __type = NWLMatchingActionForContext(__context);\
        if (__type) {\
            CFStringRef __message = CFStringCreateWithFormat(NULL, 0, _NWL_CFSTRING_(_fmt), ##__VA_ARGS__);\
            switch (__type) {\
                case kNWLAction_print: NWLForwardToPrinters(__context, __message); break;\
                case kNWLAction_break: NWLForwardToPrinters(__context, __message); kill(getpid(), SIGINT); break;\
                case kNWLAction_raise: _NWL_EXCEPTION_(__message); break;\
                case kNWLAction_assert: _NWL_ASSERT_(__message); break;\
                default: _NWL_LOG_(__message, _fmt, ##__VA_ARGS__); break;\
            }\
            CFRelease(__message);\
        }\
    } while (0)


#pragma mark - Type definitions

/** Kinds of context properties to filter on */
typedef enum {
    kNWLProperty_none     = 0,
    kNWLProperty_tag      = 1,
    kNWLProperty_lib      = 2,
    kNWLProperty_file     = 3,
    kNWLProperty_function = 4,
    kNWLProperty_count    = 5,
} NWLProperty;

/** Kinds of actions to take when a log context matches properties */
typedef enum {
    kNWLAction_none   = 0,
    kNWLAction_print  = 1,
    kNWLAction_break  = 2,
    kNWLAction_raise  = 3,
    kNWLAction_assert = 4,
    kNWLAction_count  = 5,
} NWLAction;

/** The properties of a logging statement. */
typedef struct {
    const char *tag;
    const char *lib;
    const char *file;
    int line;
    const char *function;
} NWLContext;


#pragma mark - Core functions

/** Sends printing data to all printers. */
extern void NWLForwardToPrinters(NWLContext context, CFStringRef message);

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
extern void NWLDefaultPrinter(NWLContext context, CFStringRef message, void *info);


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


/** Reset the clock on log prints to 00:00:00. */
extern void NWLResetPrintClock(void);

/** Offset the clock on log prints with seconds. */
extern void NWLOffsetPrintClock(double seconds);

/** Restore the clock on log prints to UTC time. */
extern void NWLRestorePrintClock(void);

/** Provides clock values, returns time since epoch or since reset. */
extern double NWLClock(int *hour, int *minute, int *second, int *micro);

/** Returns a human-readable summary of this logger, returns the length of the about text excluding the null byte independent of 'size'. */
extern int NWLAboutString(char *buffer, int size);

/** Log the internal state. */
extern void NWLogAbout(void);


#pragma mark - Convenient logging configuration

/** Activate the printing of all info statements. */
extern void NWLPrintInfo(void);

/** Activate the printing of all warn statements. */
extern void NWLPrintWarn(void);

/** Activate the printing of all dbug statements. */
extern void NWLPrintDbug(void);

/** Activate the printing of all statements on a custom tag. */
extern void NWLPrintTag(const char *tag);

/** Activate the printing of all statements. */
extern void NWLPrintAll(void);


/** Activate the printing of all info statements in one lib. */
extern void NWLPrintInfoInLib(const char *lib);

/** Activate the printing of all warn statements in one lib. */
extern void NWLPrintWarnInLib(const char *lib);

/** Activate the printing of all dbug statements in one lib. */
extern void NWLPrintDbugInLib(const char *lib);

/** Activate the printing of custom tag statements in one lib. */
extern void NWLPrintTagInLib(const char *tag, const char *lib);

/** Activate the printing of all statements in one lib. */
extern void NWLPrintAllInLib(const char *lib);


/** Activate printing of dbug statements in a file. */
extern void NWLPrintDbugInFile(const char *file);

/** Activate printing of dbug statements in a function, of the form: -[CLass parmeter:parmeter:]. */
extern void NWLPrintDbugInFunction(const char *function);


/** Activate breaking on all warn statements. */
extern void NWLBreakWarn(void);

/** Activate breaking on all warn statements in one lib. */
extern void NWLBreakWarnInLib(const char *lib);

/** Activate breaking of custom tag statements. */
extern void NWLBreakTag(const char *tag);

/** Activate breaking of custom tag statements in one lib. */
extern void NWLBreakTagInLib(const char *tag, const char *lib);


/** Deactivate actions of all info statements. */
extern void NWLClearInfo(void);

/** Deactivate actions of all warn statements. */
extern void NWLClearWarn(void);

/** Deactivate actions of all dbug statements. */
extern void NWLClearDbug(void);

/** Deactivate actions of custom tag statements. */
extern void NWLClearTag(const char *tag);

/** Deactivate actions of all statements in one lib. */
extern void NWLClearAllInLib(const char *lib);

/** Removes all actions for all filters. */
extern void NWLClearAll(void);

    
/** Print internal state info to stderr. */
extern void NWLDump(void);
extern void NWLDumpFlags(int active, const char *lib, int debug, const char *file, int line, const char *function);
extern void NWLDumpConfig();
#define NWLDump() do {NWLDumpFlags(NWL_ACTIVE, NWL_LIB_STR, NWL_DEBUG, _NWL_FILE_, __LINE__, __PRETTY_FUNCTION__);if(NWL_ACTIVE){NWLDumpConfig();}} while (0)

/** Print help info for developers to stderr. */
extern void NWLDumpHelp(int active, const char *lib, int debug, const char *file, int line, const char *function);
#define NWLHelp() NWLDumpHelp(NWL_ACTIVE, NWL_LIB_STR, NWL_DEBUG, _NWL_FILE_, __LINE__, __PRETTY_FUNCTION__)

    
#endif // _NWLOGGING_H_
    
#ifdef __cplusplus
} // extern "C"
#endif
