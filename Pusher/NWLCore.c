//
//  NWLCore.m
//  NWLogging
//
//  Created by leonard on 4/25/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWLCore.h"
#include <stdio.h>
#include <string.h>
#include <sys/uio.h>
#include <math.h>
#import <CoreFoundation/CFDate.h>

#pragma mark - Constants and statics

static const int kNWLFilterListSize = 16;
static const int kNWLPrinterListSize = 8;

typedef struct {
    const char *properties[kNWLProperty_count];
    NWLAction action;
} NWLFilter;

typedef struct {
    int count;
    NWLFilter elements[kNWLFilterListSize];
} NWLFilterList;

typedef struct {
    const char *name;
    void(*func)(NWLContext, CFStringRef, void *);
    void *info;
} NWLPrinter;

typedef struct {
    int count;
    NWLPrinter elements[kNWLPrinterListSize];
} NWLPrinterList;

#define NWLDefaultPrinterName "default"
static NWLFilterList NWLFilters = {1, {NULL, "warn", NULL, NULL, NULL, kNWLAction_print}};
static NWLPrinterList NWLPrinters = {1, {NWLDefaultPrinterName, NWLDefaultPrinter, NULL}};
static CFTimeInterval NWLTimeOffset = 0;


#pragma mark - Printing

void NWLForwardToPrinters(NWLContext context, CFStringRef message) {
    for (int i = 0; i < NWLPrinters.count; i++) {
        NWLPrinter *printer = &NWLPrinters.elements[i];
        void(*func)(NWLContext, CFStringRef, void *) = printer->func;
        func(context, message, printer->info);
    }
}

int NWLAddPrinter(const char *name, void(*func)(NWLContext, CFStringRef, void *), void *info) {
    int count = NWLPrinters.count;
    if (count < kNWLPrinterListSize) {
        NWLPrinters.elements[count].name = name;
        NWLPrinters.elements[count].func = func;
        NWLPrinters.elements[count].info = info;
        NWLPrinters.count = count + 1;
        return true;
    }
    return false;
}

void * NWLRemovePrinter(const char *name) {
    for (int i = NWLPrinters.count - 1; i >= 0; i--) {
        NWLPrinter *p = &NWLPrinters.elements[i];
        const char *n = p->name;
        if (n == name || (n && name && !strcasecmp(n, name))) {
            int count = NWLPrinters.count;
            if (count > 0) {
                void *info = p->info;
                NWLPrinters.count = count - 1;
                NWLPrinters.elements[i] = NWLPrinters.elements[count - 1];
                return info;
            }
        }
    }
    return NULL;
}

void NWLRemoveAllPrinters(void) {
    NWLPrinters.count = 0;
}

void NWLRestoreDefaultPrinters(void) {
    NWLPrinters.elements[0].name = NWLDefaultPrinterName;
    NWLPrinters.elements[0].func = NWLDefaultPrinter;
    NWLPrinters.elements[0].info = NULL;
    NWLPrinters.count = 1;
}

void NWLAddDefaultPrinter(void) {
    NWLAddPrinter(NWLDefaultPrinterName, NWLDefaultPrinter, NULL);
}

void NWLDefaultPrinter(NWLContext context, CFStringRef message, void *info) {
    // init io vector
    struct iovec iov[16];
    int i = 0;
    iov[i].iov_base = "[";
    iov[i++].iov_len = 1;

    // add time
    int hour = 0, minute = 0, second = 0, micro = 0;
    NWLClock(&hour, &minute, &second, &micro);
    char timeBuffer[16];
    int timeLength = snprintf(timeBuffer, sizeof(timeBuffer), "%02i:%02i:%02i.%06i", hour, minute, second, micro);
    iov[i].iov_base = timeBuffer;
    iov[i++].iov_len = sizeof(timeBuffer) - 1 < timeLength ? sizeof(timeBuffer) - 1 : timeLength;
    
    // add context
    if (context.lib && *context.lib) {
        iov[i].iov_base = " ";
        iov[i++].iov_len = 1;
        iov[i].iov_base = (void *)context.lib;
        iov[i++].iov_len = strnlen(context.lib, 32);
    }
    if (context.file && *context.file) {
        iov[i].iov_base = " ";
        iov[i++].iov_len = 1;
        iov[i].iov_base = (void *)context.file;
        iov[i++].iov_len = strnlen(context.file, 32);
        iov[i].iov_base = ":";
        iov[i++].iov_len = 1;
        char lineBuffer[10];
        int lineLength = snprintf(lineBuffer, sizeof(lineBuffer), context.line < 1000 ? "%03u" : "%06u", context.line);
        iov[i].iov_base = lineBuffer;
        iov[i++].iov_len = sizeof(lineBuffer) - 1 < lineLength ? sizeof(lineBuffer) - 1 : lineLength;
    }
    if (context.tag && *context.tag) {
        iov[i].iov_base = "] [";
        iov[i++].iov_len = 3;
        iov[i].iov_base = (void *)context.tag;
        iov[i++].iov_len = strnlen(context.tag, 32);
    }
    
    iov[i].iov_base = "] ";
    iov[i++].iov_len = 2;

    CFRange range = CFRangeMake(0, message ? CFStringGetLength(message) : 0);
    if (range.length) {
        // add message
        unsigned char messageBuffer[256];
        CFIndex messageLength = 0;
        CFIndex length = 1;
        
        while (length && range.length) {
            length = CFStringGetBytes(message, range, kCFStringEncodingUTF8, '?', false, messageBuffer, sizeof(messageBuffer), &messageLength);
            iov[i].iov_base = messageBuffer;
            iov[i++].iov_len = messageLength;
            if (length >= range.length) {
                iov[i].iov_base = "\n";
                iov[i++].iov_len = 1;
            } else if (!length) {
                iov[i].iov_base = "~\n";
                iov[i++].iov_len = 2;
            }
            writev(STDERR_FILENO, iov, i);
            i = 0;
            range.location += length;
            range.length -= length;
        }
    } else {
        iov[i].iov_base = "\n";
        iov[i++].iov_len = 1;
        writev(STDERR_FILENO, iov, i);
    }
}


#pragma mark - Filtering

NWLAction NWLMatchingActionForContext(NWLContext context) {
    NWLAction result = kNWLAction_none;
    int bestScore = 0;
    for (int i = 0; i < NWLFilters.count; i++) {
        NWLFilter *filter = &NWLFilters.elements[i];
        if (result < filter->action) {
            int score = 0;
            const char *s = NULL;
#define _NWL_FIND_(_prop) s = filter->properties[kNWLProperty_##_prop]; if (s && context._prop) {if (strcasecmp(s, context._prop)) {continue;} else {score++;}}
            _NWL_FIND_(tag)
            _NWL_FIND_(lib)
            _NWL_FIND_(file)
            _NWL_FIND_(function)
            if (bestScore <= score) {
                bestScore = score;
                result = filter->action;
            }
        }
    }
    return result;
}

static int NWLAddFilter1(NWLFilter *filter) {
    if (filter->action != kNWLAction_none) {
        int count = NWLFilters.count;
        if (count < kNWLFilterListSize) {
            NWLFilters.elements[count] = *filter;
            NWLFilters.count = count + 1;
            return true;
        }
    }
    return false;
}

static NWLAction NWLHasFilter1(NWLFilter *filter) {
    for (int i = 0; i < NWLFilters.count; i++) {
        NWLFilter *m = &NWLFilters.elements[i];
        int j = 1;
        for (; j < kNWLProperty_count; j++) {
            const char *a = filter->properties[j];
            const char *b = m->properties[j];
            if (a != b && (!a || !b || strcasecmp(a, b))) break;
        }
        if (j == kNWLProperty_count) {
            return m->action;
        }
    }
    return kNWLAction_none;
}

static int NWLRemoveFilter1(NWLFilter *filter) {
    int result = 0;
    for (int i = 0; i < NWLFilters.count; i++) {
        NWLFilter *m = &NWLFilters.elements[i];
        int j = 1;
        for (; j < kNWLProperty_count; j++) {
            const char *a = filter->properties[j];
            const char *b = m->properties[j];
            if (a != b && (!a || !b || strcasecmp(a, b))) break;
        }
        int count = NWLFilters.count;
        if (j == kNWLProperty_count && count > 0) {
            NWLFilters.count = count - 1;
            NWLFilters.elements[i--] = NWLFilters.elements[count - 1];
            result++;
        }
    }
    return result;
}

static int NWLRemoveMatchingFilters1(NWLFilter *filter) {
    int result = 0;
    for (int i = 0; i < NWLFilters.count; i++) {
        NWLFilter *m = &NWLFilters.elements[i];
        int j = 1;
        for (; j < kNWLProperty_count; j++) {
            const char *a = filter->properties[j];
            const char *b = m->properties[j];
            if (a && (!b || strcasecmp(a, b))) break;
        }
        int count = NWLFilters.count;
        if (j == kNWLProperty_count && count > 0) {
            NWLFilters.count = count - 1;
            NWLFilters.elements[i--] = NWLFilters.elements[count - 1];
            result++;
        }
    }
    return result;
}

int NWLAddFilter(const char *tag, const char *lib, const char *file, const char *function, NWLAction action) {
    NWLFilter filter = {NULL, tag, lib, file, function, action};
    NWLRemoveFilter1(&filter);
    int result = NWLAddFilter1(&filter);
    return result;
}

NWLAction NWLHasFilter(const char *tag, const char *lib, const char *file, const char *function) {
    NWLFilter filter = {NULL, tag, lib, file, function, kNWLAction_none};
    NWLAction result = NWLHasFilter1(&filter);
    return result;
}

int NWLRemoveMatchingFilters(const char *tag, const char *lib, const char *file, const char *function) {
    NWLFilter filter = {NULL, tag, lib, file, function, kNWLAction_none};
    int result = NWLRemoveMatchingFilters1(&filter);
    return result;
}

void NWLRemoveAllFilters(void) {
    NWLFilters.count = 0;
}

void NWLRestoreDefaultFilters(void) {
    NWLFilters.elements[0].action = kNWLAction_print;
    NWLFilters.elements[0].properties[0] = "warn";
    NWLFilters.count = 1;
}


#pragma mark - Clock

static double NWLTime() {
    return CFAbsoluteTimeGetCurrent() + 978307200;
}

void NWLResetPrintClock(void) {
    NWLTimeOffset = NWLTime();
}

void NWLOffsetPrintClock(double seconds) {
    NWLTimeOffset = -seconds;
}

void NWLRestorePrintClock(void) {
    NWLTimeOffset = 0;
}

double NWLClock(int *hour, int *minute, int *second, int *micro) {
    CFAbsoluteTime time = NWLTime() - NWLTimeOffset;
    *hour = (int)(time / 3600) % 24;
    *minute = (int)(time / 60) % 60;
    *second = (int)time % 60;
    *micro = (int)((time - floor(time)) * 1000000) % 1000000;
    return time;
}


#pragma mark - About

#define _NWL_PRINT_(_buffer, _size, _fmt, ...) do {\
        int _s = _size > 0 ? _size : 0;\
        int __p = snprintf(_buffer, _s, _fmt, ##__VA_ARGS__);\
        if (__p <= _size) _buffer += __p; else buffer += _s;\
        _size -= __p;\
    } while (0)

int NWLAboutString(char *buffer, int size) {
    int s = size;
    for (int i = 0; i < NWLFilters.count; i++) {
        NWLFilter *filter = &NWLFilters.elements[i];
#define _NWL_ABOUT_ACTION_(_action) do {if (filter->action == kNWLAction_##_action) {_NWL_PRINT_(buffer, s, "   action       : "#_action);}} while (0)
        _NWL_ABOUT_ACTION_(print);
        _NWL_ABOUT_ACTION_(break);
        _NWL_ABOUT_ACTION_(raise);
        _NWL_ABOUT_ACTION_(assert);
        const char *value = NULL;
#define _NWL_ABOUT_PROP_(_prop) do {if ((value = filter->properties[kNWLProperty_##_prop])) {_NWL_PRINT_(buffer, s, " "#_prop"=%s\n", value);}} while (0)
        _NWL_ABOUT_PROP_(tag);
        _NWL_ABOUT_PROP_(lib);
        _NWL_ABOUT_PROP_(file);
        _NWL_ABOUT_PROP_(function);
    }
    for (int i = 0; i < NWLPrinters.count; i++) {
        NWLPrinter *p = &NWLPrinters.elements[i];
        _NWL_PRINT_(buffer, s, "   printer      : %s\n", p->name);
    }
    _NWL_PRINT_(buffer, s, "   time-offset  : %f\n", NWLTimeOffset);
    return size - s;
}

void NWLogAbout(void) {
    char buffer[256];
    int length = NWLAboutString(buffer, sizeof(buffer));
    NWLLogWithoutFilter(, NWLogging, "About NWLogging\n%s%s", buffer, length <= sizeof(buffer) - 1 ? "" : "\n   ...");
}


#pragma mark - Macro wrappers

void NWLPrintInfo() {
    NWLAddFilter("info", NULL, NULL, NULL, kNWLAction_print);
}

void NWLPrintWarn() {
    NWLAddFilter("warn", NULL, NULL, NULL, kNWLAction_print);
}

void NWLPrintDbug() {
    NWLAddFilter("dbug", NULL, NULL, NULL, kNWLAction_print);
}

void NWLPrintTag(const char *tag) {
    NWLAddFilter(tag, NULL, NULL, NULL, kNWLAction_print);
}

void NWLPrintAll() {
    NWLAddFilter(NULL, NULL, NULL, NULL, kNWLAction_print);
}



void NWLPrintInfoInLib(const char *lib) {
    NWLAddFilter("info", lib, NULL, NULL, kNWLAction_print);
}

void NWLPrintWarnInLib(const char *lib) {
    NWLAddFilter("warn", lib, NULL, NULL, kNWLAction_print);
}

void NWLPrintDbugInLib(const char *lib) {
    NWLAddFilter("dbug", lib, NULL, NULL, kNWLAction_print);
}

void NWLPrintTagInLib(const char *tag, const char *lib) {
    NWLAddFilter(tag, lib, NULL, NULL, kNWLAction_print);
}

void NWLPrintAllInLib(const char *lib) {
    NWLAddFilter(NULL, lib, NULL, NULL, kNWLAction_print);
}



void NWLPrintDbugInFile(const char *file) {
    NWLAddFilter("dbug", NULL, file, NULL, kNWLAction_print);
}

void NWLPrintDbugInFunction(const char *function) {
    NWLAddFilter("dbug", NULL, NULL, function, kNWLAction_print);
}



void NWLBreakWarn() {
    NWLAddFilter("warn", NULL, NULL, NULL, kNWLAction_break);
}

void NWLBreakWarnInLib(const char *lib) {
    NWLAddFilter("warn", lib, NULL, NULL, kNWLAction_break);
}

void NWLBreakTag(const char *tag) {
    NWLAddFilter(tag, NULL, NULL, NULL, kNWLAction_break);
}

void NWLBreakTagInLib(const char *tag, const char *lib) {
    NWLAddFilter(tag, lib, NULL, NULL, kNWLAction_break);
}



void NWLClearInfo() {
    NWLRemoveMatchingFilters("info", NULL, NULL, NULL);
}

void NWLClearWarn() {
    NWLRemoveMatchingFilters("warn", NULL, NULL, NULL);
}

void NWLClearDbug() {
    NWLRemoveMatchingFilters("dbug", NULL, NULL, NULL);
}

void NWLClearTag(const char *tag) {
    NWLRemoveMatchingFilters(tag, NULL, NULL, NULL);
}

void NWLClearAllInLib(const char *lib) {
    NWLRemoveMatchingFilters(NULL, lib, NULL, NULL);
}

void NWLClearAll(void) {
    NWLRemoveAllFilters();
}


#pragma mark - Dumping

void NWLDumpConfig(void) {
    char buffer[256];
    int length = NWLAboutString(buffer, sizeof(buffer));
    struct iovec iov[2];
    iov[0].iov_base = buffer;
    iov[0].iov_len = length <= sizeof(buffer) - 1 ? length : sizeof(buffer) - 1;
    iov[1].iov_base = "   ...\n";
    iov[1].iov_len = length <= sizeof(buffer) - 1 ? 0 : 7;
    writev(STDERR_FILENO, iov, 2);
}

#define PRINT(_format, ...) fprintf(stderr, _format"\n", ##__VA_ARGS__)
void NWLDumpFlags(int active, const char *lib, int debug, const char *file, int line, const char *function) {
    PRINT("   file         : %s:%i", file, line);
    PRINT("   function     : %s", function);
    PRINT("   DEBUG        : %s", debug ? "ON" : "OFF");
    PRINT("   NWL_LIB      : %s", lib && *lib ? lib : (lib ? "<empty>" : "<not set>"));
    PRINT("   NWLog macros : %s", active ? "ON" : "OFF");
}

void NWLDumpHelp(int active, const char *lib, int debug, const char *file, int line, const char *function) {
    //PRINT("012345678910234567892023456789302345678940234567895023456789");
    PRINT("This text privides info on the configuration of NWLogging at");
    PRINT("a specific point in your code. The purpose of this text is");
    PRINT("to assist you with configuring the framework. It is printed");
    PRINT("to stderr, your console, using the NWLHelp() macro function.");
    PRINT("Avoid checking NWLHelp() calls into version control or leaving");
    PRINT("it in the final release of your app.");
    PRINT();
    PRINT("NWLogging is configured as follows:");
    NWLDumpFlags(active, lib, debug, file, line, function);
    if (active) {
        NWLDumpConfig();
    }
    PRINT();
    PRINT("If NWLog macros are ON then all macro functions of the form");
    PRINT("NWLog..() are compiled and executed at runtime. Using");
    PRINT("NWLog(\"\") should always show up in the console output.");
    PRINT("Other logs, like NWLogInfo(\"\") might be filtered out, but");
    PRINT("these can be activated at runtime using the NWLPrint..()");
    PRINT("methods.");
    PRINT();
    PRINT("If NWLog macros are OFF then all macro functions of the form");
    PRINT("NWLog..() are completely stripped from the binary have no");
    PRINT("impact at runtime.");
    PRINT();
    PRINT("By default, NWLog macros are active in DEBUG mode and if the");
    PRINT("NWL_LIB macro is set in the preprocessor. See the readme file");
    PRINT("for details on how to do this in Xcode.");
}

#undef NWLDump
void NWLDump(void) {
    NWLDumpConfig();
}
