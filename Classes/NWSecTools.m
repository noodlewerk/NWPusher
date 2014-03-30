//
//  NWSecTools.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSecTools.h"

typedef enum {
    kNWCertTypeNone = 0,
    kNWCertTypeIOSDevelopment = 1,
    kNWCertTypeIOSProduction = 2,
    kNWCertTypeMacDevelopment = 3,
    kNWCertTypeMacProduction = 4,
    kNWCertTypeUnknown = 5,
} NWCertType;


@implementation NWSecTools

+ (NWError)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identity:(NWIdentityRef *)identity
{
    *identity = nil;
    NSArray *identities = nil;
    NWError result = [self identitiesWithPKCS12Data:pkcs12 password:password identities:&identities];
    if (result != kNWSuccess) {
        return result;
    }
    if (identities.count == 0) {
        return kNWErrorPKCS12NoItems;
    }
    if (identities.count > 1) {
        return kNWErrorPKCS12MutlipleItems;
    }
    *identity = identities.lastObject;
    return kNWSuccess;
}

+ (NWError)identitiesWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identities:(NSArray **)identities
{
    *identities = nil;
    NSArray *dicts = nil;
    if (!pkcs12.length) {
        return kNWErrorPKCS12EmptyData;
    }
    NWError result = [self allIdentitiesWithPKCS12Data:pkcs12 password:password dicts:&dicts];
    if (result != kNWSuccess) {
        return result;
    }
    NSMutableArray *ids = @[].mutableCopy;
    for (NSDictionary *dict in dicts) {
        NWIdentityRef identity = dict[(__bridge id)kSecImportItemIdentity];
        if (identity) {
            NWCertificateRef certificate = nil;
            NWError certres = [self certificateWithIdentity:identity certificate:&certificate];
            if (certres != kNWSuccess) {
                return certres;
            }
            if ([self isPushCertificate:certificate]) {
                NWKeyRef key = nil;
                NWError keyres = [self keyWithIdentity:identity key:&key];
                if (keyres != kNWSuccess) {
                    return keyres;
                }
                [ids addObject:identity];
            }
        }
    }
    *identities = ids;
    return kNWSuccess;
}

+ (NWError)keychainCertificates:(NSArray **)certificates
{
    *certificates = nil;
    NSArray *candidates = nil;
    NWError result = [self allKeychainCertificates:&candidates];
    if (result != kNWSuccess) {
        return result;
    }
    NSMutableArray *certs = [[NSMutableArray alloc] init];
    for (id certificate in candidates) {
        if ([self isPushCertificate:certificate]) {
            [certs addObject:certificate];
        }
    }
    *certificates = certs;
    return kNWSuccess;
}

#pragma mark - Certificate types

+ (NWCertType)typeWithCertificate:(NWCertificateRef)certificate summary:(NSString **)summary
{
    if (summary) *summary = nil;
    NSString *name = [self plainSummaryWithCertificate:certificate];
    for (NWCertType t = kNWCertTypeNone; t < kNWCertTypeUnknown; t++) {
        NSString *prefix = [self prefixWithCertType:t];
        if (prefix && [name hasPrefix:prefix]) {
            if (summary) *summary = [name substringFromIndex:prefix.length];
            return t;
        }
    }
    if (summary) *summary = name;
    return kNWCertTypeUnknown;
}

+ (NSString *)summaryWithCertificate:(NWCertificateRef)certificate
{
    NSString *result = nil;
    [self typeWithCertificate:certificate summary:&result];
    return result;
}

+ (BOOL)isSandboxIdentity:(NWIdentityRef)identity
{
    NWCertificateRef certificate = nil;
    [self certificateWithIdentity:identity certificate:&certificate];
    return [self isSandboxCertificate:certificate];
}

+ (BOOL)isSandboxCertificate:(NWCertificateRef)certificate
{
    switch ([self typeWithCertificate:certificate summary:nil]) {
        case kNWCertTypeIOSDevelopment:
        case kNWCertTypeMacDevelopment:
            return YES;
        case kNWCertTypeIOSProduction:
        case kNWCertTypeMacProduction:
        case kNWCertTypeNone:
        case kNWCertTypeUnknown:
            break;
    }
    return NO;
}

+ (BOOL)isPushCertificate:(NWCertificateRef)certificate
{
    switch ([self typeWithCertificate:certificate summary:nil]) {
        case kNWCertTypeIOSDevelopment:
        case kNWCertTypeMacDevelopment:
        case kNWCertTypeIOSProduction:
        case kNWCertTypeMacProduction:
            return YES;
        case kNWCertTypeNone:
        case kNWCertTypeUnknown:
            break;
    }
    return NO;
}

+ (NSString *)prefixWithCertType:(NWCertType)type
{
    switch (type) {
        case kNWCertTypeIOSDevelopment: return @"Apple Development IOS Push Services: ";
        case kNWCertTypeIOSProduction: return @"Apple Production IOS Push Services: ";
        case kNWCertTypeMacDevelopment: return @"Apple Development Mac Push Services: ";
        case kNWCertTypeMacProduction: return @"Apple Production Mac Push Services: ";
        case kNWCertTypeNone:
        case kNWCertTypeUnknown:
            break;
    }
    return nil;
}

#pragma mark - Sec wrappers

+ (NWCertificateRef)certificateWithData:(NSData *)data
{
    return data ? CFBridgingRelease(SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)data)) : nil;
}

+ (NSString *)plainSummaryWithCertificate:(NWCertificateRef)certificate
{
    return certificate ? CFBridgingRelease(SecCertificateCopySubjectSummary((__bridge SecCertificateRef)certificate)) : nil;
}

+ (NSData *)derDataWithCertificate:(NWCertificateRef)certificate
{
    return certificate ? CFBridgingRelease(SecCertificateCopyData((__bridge SecCertificateRef)certificate)) : nil;
}

+ (NWError)certificateWithIdentity:(NWIdentityRef)identity certificate:(NWCertificateRef *)certificate
{
    *certificate = nil;
    SecCertificateRef cert = NULL;
    OSStatus status = identity ? SecIdentityCopyCertificate((__bridge SecIdentityRef)identity, &cert) : errSecParam;
    *certificate = CFBridgingRelease(cert);
    if (status != errSecSuccess || !cert) {
        return kNWErrorIdentityCopyCertificate;
    }
    return kNWSuccess;
}

+ (NWError)keyWithIdentity:(NWIdentityRef)identity key:(NWKeyRef *)key
{
    *key = nil;
    SecKeyRef k = NULL;
    OSStatus status = identity ? SecIdentityCopyPrivateKey((__bridge SecIdentityRef)identity, &k) : errSecParam;
    *key = CFBridgingRelease(k);
    if (status != errSecSuccess || !k) {
        return kNWErrorIdentityCopyPrivateKey;
    }
    return kNWSuccess;
}

+ (NWError)allIdentitiesWithPKCS12Data:(NSData *)data password:(NSString *)password dicts:(NSArray **)dicts
{
    *dicts = nil;
    NSDictionary *options = @{(__bridge id)kSecImportExportPassphrase: password};
    CFArrayRef items = NULL;
    OSStatus status = data ? SecPKCS12Import((__bridge CFDataRef)data, (__bridge CFDictionaryRef)options, &items) : errSecParam;
    *dicts = CFBridgingRelease(items);
    if (status != errSecSuccess || !items) {
        switch (status) {
            case errSecDecode: return kNWErrorPKCS12Decode;
            case errSecAuthFailed: return kNWErrorPKCS12AuthFailed;
#if !TARGET_OS_IPHONE
            case errSecPkcs12VerifyFailure: return kNWErrorPKCS12Password;
#endif
        }
        return kNWErrorPKCS12Import;
    }
    return kNWSuccess;
}

+ (NWError)allKeychainCertificates:(NSArray **)certificates
{
    *certificates = nil;
    NSDictionary *options = @{(__bridge id)kSecClass: (__bridge id)kSecClassCertificate,
                              (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll};
    CFArrayRef certs = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)options, (CFTypeRef *)&certs);
    *certificates = CFBridgingRelease(certs);
    if (status != errSecSuccess || !certs) {
        return kNWErrorKeychainCopyMatching;
    }
    return kNWSuccess;
}

#if !TARGET_OS_IPHONE
+ (NWError)keychainIdentityWithCertificate:(NWCertificateRef)certificate identity:(NWIdentityRef *)identity
{
    *identity = nil;
    SecIdentityRef ident = NULL;
    OSStatus status = certificate ? SecIdentityCreateWithCertificate(NULL, (__bridge SecCertificateRef)certificate, &ident) : errSecParam;
    *identity = CFBridgingRelease(ident);
    if (status != errSecSuccess || !ident) {
        switch (status) {
            case errSecItemNotFound: return kNWErrorKeychainItemNotFound;
        }
        return kNWErrorKeychainCreateIdentity;
    }
    return kNWSuccess;
}
#endif

#pragma mark - Debug

+ (NSDictionary *)inspectIdentity:(NWIdentityRef)identity
{
    if (!identity) return nil;
    NSMutableDictionary *result = @{}.mutableCopy;
    SecCertificateRef certificate = NULL;
    OSStatus certstat = SecIdentityCopyCertificate((__bridge SecIdentityRef)identity, &certificate);
    result[@"has_certificate"] = @(!!certificate);
    if (certstat) result[@"certificate_error"] = @(certstat);
    if (certificate) {
        result[@"subject_summary"] = CFBridgingRelease(SecCertificateCopySubjectSummary(certificate));
        result[@"der_data"] = CFBridgingRelease(SecCertificateCopyData(certificate));
        CFRelease(certificate);
    }
    SecKeyRef key = NULL;
    OSStatus keystat = SecIdentityCopyPrivateKey((__bridge SecIdentityRef)identity, &key);
    result[@"has_key"] = @(!!key);
    if (keystat) result[@"key_error"] = @(keystat);
    if (key) {
        result[@"block_size"] = @(SecKeyGetBlockSize(key));
        CFRelease(key);
    }
    return result;
}

#pragma mark - Deprecated

#if !TARGET_OS_IPHONE
+ (NWError)identityWithCertificateRef:(SecCertificateRef)certificate identity:(SecIdentityRef *)identity
{
    *identity = NULL;
    NWIdentityRef ident = nil;
    NWError result = [self keychainIdentityWithCertificate:(__bridge NWCertificateRef)certificate identity:&ident];
    *identity = (SecIdentityRef)CFBridgingRetain(ident);
    return result;
}

+ (NWError)identityWithCertificateData:(NSData *)data identity:(SecIdentityRef *)identity
{
    *identity = NULL;
    NWCertificateRef certificate = [self certificateWithData:data];
    NWIdentityRef ident = nil;
    NWError result = [self keychainIdentityWithCertificate:certificate identity:&ident];
    *identity = (SecIdentityRef)CFBridgingRetain(ident);
    return result;
}
#endif

+ (NSArray *)keychainCertificates
{
    NSArray *result = nil;
    [self keychainCertificates:&result];
    return result;
}

+ (NSString *)identifierForCertificate:(SecCertificateRef)certificate
{
    return [self summaryWithCertificate:(__bridge NWCertificateRef)certificate];
}

+ (SecCertificateRef)certificateForIdentity:(SecIdentityRef)identity
{
    NWCertificateRef result = nil;
    [self certificateWithIdentity:(__bridge NWIdentityRef)identity certificate:&result];
    return (SecCertificateRef)CFBridgingRetain(result);
}

+ (BOOL)isSandboxCertificateRef:(SecCertificateRef)certificate
{
    return [self isSandboxCertificate:(__bridge NWCertificateRef)certificate];
}

@end
