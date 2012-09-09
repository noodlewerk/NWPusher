//
//  NWSecTools.m
//  Pusher
//
//  Created by Leo on 9/9/12.
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSecTools.h"

static NSString * const NWDevelpmentPrefix = @"Apple Development IOS Push Services: ";
static NSString * const NWProductionPrefix = @"Apple Production IOS Push Services: ";

typedef enum {
    kNWCertificateTypeNone = 0,
    kNWCertificateTypeDevelopment = 1,
    kNWCertificateTypeProduction = 2,
} NWCertificateType;


@implementation NWSecTools

+ (BOOL)identityWithCertificateData:(NSData *)certificate identity:(SecIdentityRef *)identity
{
    SecCertificateRef c = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)certificate);
    if (!c) {
        NWLogWarn(@"Unable to read certificate");
        return NO;
    }
    
    BOOL result = [self identityWithCertificateRef:c identity:identity];
    return result;
}

+ (BOOL)identityWithCertificateRef:(SecCertificateRef)certificate identity:(SecIdentityRef *)identity
{
	OSStatus status = SecIdentityCreateWithCertificate(NULL, certificate, identity);
    if (status != noErr) {
        switch (status) {
            case errSecItemNotFound: NWLogWarn(@"Unable to create identitiy, private key missing"); break;
            default: NWLogWarn(@"Unable to create identitiy (%i)", status); break;
        }
        return NO;
    }
    
    return YES;
}

+ (BOOL)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identity:(SecIdentityRef *)identity
{
    const void *keys[] = {kSecImportExportPassphrase};
    const void *values[] = {(__bridge const void *)password};
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus status = SecPKCS12Import((__bridge CFDataRef)pkcs12, options, &items);
    CFRelease(options);
    if (status != noErr) {
        NWLogWarn(@"Unable to import PKCS12 data (%i)", status);
        return NO;
    }
    
    CFIndex count = CFArrayGetCount(items);
    if (!count) {
        NWLogWarn(@"No items in PKCS12 data (%i)", status);
        return NO;
    }
    
    CFDictionaryRef dict = CFArrayGetValueAtIndex(items, 0);
    *identity = (SecIdentityRef)CFDictionaryGetValue(dict, kSecImportItemIdentity);
    if (!identity) {
        NWLogWarn(@"No identity in PKCS12 data (%i)", status);
        return NO;
    }
    
    CFRetain(*identity);
    CFRelease(items);
    
    return YES;
}

+ (BOOL)keychainCertificates:(NSArray **)certificates
{
    const void *keys[] = {kSecClass, kSecMatchLimit};
    int i = 1000;
    CFNumberRef n = CFNumberCreate(NULL, kCFNumberIntType, &i);
    const void *values[] = {kSecClassCertificate, n};
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 2, NULL, NULL);
    CFArrayRef results = NULL;
    
    OSStatus status = SecItemCopyMatching(options, (CFTypeRef *)&results);
    CFRelease(options);
    if (status != noErr) {
        NWLogWarn(@"Unable to find certificate (%i)", status);
        return NO;
    }
    
    NSMutableArray *certs = [[NSMutableArray alloc] init];
    NSArray *candidates = CFBridgingRelease(results);
    for (id c in candidates) {
        SecCertificateRef certificate = (__bridge SecCertificateRef)(c);
        NWCertificateType type = [self typeForCertificate:certificate identifier:nil];
        if (type == kNWCertificateTypeDevelopment || type == kNWCertificateTypeProduction) {
            [certs addObject:c];
        }
    }
    if (certificates) *certificates = certs;
    
    return YES;
}

+ (BOOL)isDevelopmentCertificate:(SecCertificateRef)certificate
{
    BOOL result = [self typeForCertificate:certificate identifier:nil] == kNWCertificateTypeDevelopment;
    return result;
}

+ (NSString *)identifierForCertificate:(SecCertificateRef)certificate
{
    NSString *result = nil;
    [self typeForCertificate:certificate identifier:&result];
    return result;
}

+ (NWCertificateType)typeForCertificate:(SecCertificateRef)certificate identifier:(NSString **)identifier
{
    CFStringRef ref = NULL;
    SecCertificateCopyCommonName(certificate, &ref);
    NSString *name = CFBridgingRelease(ref);
    if ([name hasPrefix:NWDevelpmentPrefix]) {
        if (identifier) *identifier = [name substringFromIndex:NWDevelpmentPrefix.length];
        return kNWCertificateTypeDevelopment;
    }
    if ([name hasPrefix:NWProductionPrefix]) {
        if (identifier) *identifier = [name substringFromIndex:NWProductionPrefix.length];
        return kNWCertificateTypeProduction;
    }
    return kNWCertificateTypeNone;
}

@end
