//
//  NWSecTools.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSecTools.h"

/** Types of push certificates. */
typedef NS_ENUM(NSInteger, NWCertType) {
    /** None. */
    kNWCertTypeNone = 0,
    /** iOS Development. */
    kNWCertTypeIOSDevelopment = 1,
    /** iOS Production. */
    kNWCertTypeIOSProduction = 2,
    /** OS X Development. */
    kNWCertTypeMacDevelopment = 3,
    /** OS X Production. */
    kNWCertTypeMacProduction = 4,
    /** Simplified Certificate Handling. */
    kNWCertTypeSimplified = 5,
    /** Web Push Production. */
    kNWCertTypeWebProduction = 6,
    /** VoIP Services. */
    kNWCertTypeVoIPServices = 7,
    /** WatchKit Services. */
    kNWCertTypeWatchKitServices = 8,
    /** Pass Type ID. */
    kNWCertTypePasses = 9,
    /** Unknown. */
    kNWCertTypeUnknown = 10,
};


@implementation NWSecTools

#pragma mark - Initialization

+ (NWIdentityRef)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password error:(NSError *__autoreleasing *)error
{
    NSArray *identities = [self identitiesWithPKCS12Data:pkcs12 password:password error:error];
    if (!identities) {
        return nil;
    }
    if (identities.count == 0) {
        return [NWErrorUtil nilWithErrorCode:kNWErrorPKCS12NoItems error:error];
    }
    if (identities.count > 1) {
        return [NWErrorUtil nilWithErrorCode:kNWErrorPKCS12MultipleItems reason:identities.count error:error];
    }
    return identities.lastObject;
}

+ (NSArray *)identitiesWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password error:(NSError *__autoreleasing *)error
{
    if (!pkcs12.length) {
        return [NWErrorUtil nilWithErrorCode:kNWErrorPKCS12EmptyData error:error];
    }
    NSArray *dicts = [self allIdentitiesWithPKCS12Data:pkcs12 password:password error:error];
    if (!dicts) {
        return nil;
    }
    NSMutableArray *ids = @[].mutableCopy;
    for (NSDictionary *dict in dicts) {
        NWIdentityRef identity = dict[(__bridge id)kSecImportItemIdentity];
        if (identity) {
            NWCertificateRef certificate = [self certificateWithIdentity:identity error:error];
            if (!certificate) {
                return nil;
            }
            if ([self isPushCertificate:certificate]) {
                NWKeyRef key = [self keyWithIdentity:identity error:error];
                if (!key) {
                    return nil;
                }
                [ids addObject:identity];
            }
        }
    }
    return ids;
}

+ (NSArray *)keychainCertificatesWithError:(NSError *__autoreleasing *)error
{
    NSArray *candidates = [self allKeychainCertificatesWithError:error];
    if (!candidates) {
        return nil;
    }
    NSMutableArray *certs = [[NSMutableArray alloc] init];
    for (id certificate in candidates) {
        if ([self isPushCertificate:certificate]) {
            [certs addObject:certificate];
        }
    }
    return certs;
}

#pragma mark - Inspection

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

+ (NWEnvironmentOptions)environmentOptionsForIdentity:(NWIdentityRef)identity
{
    NWCertificateRef certificate = [self certificateWithIdentity:identity error:nil];
    return [self environmentOptionsForCertificate:certificate];
}

+ (NWEnvironmentOptions)environmentOptionsForCertificate:(NWCertificateRef)certificate
{
    switch ([self typeWithCertificate:certificate summary:nil]) {
        case kNWCertTypeIOSDevelopment:
        case kNWCertTypeMacDevelopment:
            return NWEnvironmentOptionSandbox;
            
        case kNWCertTypeIOSProduction:
        case kNWCertTypeMacProduction:
            return NWEnvironmentOptionProduction;
        case kNWCertTypeSimplified:
        case kNWCertTypeWebProduction:
        case kNWCertTypeVoIPServices:
        case kNWCertTypeWatchKitServices:
        case kNWCertTypePasses:
            return NWEnvironmentOptionAny;
        case kNWCertTypeNone:
        case kNWCertTypeUnknown:
            break;
    }
    return NWEnvironmentOptionNone;
}

+ (BOOL)isPushCertificate:(NWCertificateRef)certificate
{
    switch ([self typeWithCertificate:certificate summary:nil]) {
        case kNWCertTypeIOSDevelopment:
        case kNWCertTypeMacDevelopment:
        case kNWCertTypeIOSProduction:
        case kNWCertTypeMacProduction:
        case kNWCertTypeSimplified:
        case kNWCertTypeWebProduction:
        case kNWCertTypeVoIPServices:
        case kNWCertTypeWatchKitServices:
        case kNWCertTypePasses:
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
        case kNWCertTypeSimplified: return @"Apple Push Services: ";
        case kNWCertTypeWebProduction: return @"Website Push ID: ";
        case kNWCertTypeVoIPServices:  return @"VoIP Services: ";
        case kNWCertTypeWatchKitServices: return @"WatchKit Services: ";
        case kNWCertTypePasses: return @"Pass Type ID: ";
        case kNWCertTypeNone:
        case kNWCertTypeUnknown:
            break;
    }
    return nil;
}

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

+ (NWCertificateRef)certificateWithIdentity:(NWIdentityRef)identity error:(NSError *__autoreleasing *)error
{
    SecCertificateRef cert = NULL;
    OSStatus status = identity ? SecIdentityCopyCertificate((__bridge SecIdentityRef)identity, &cert) : errSecParam;
    NWCertificateRef certificate = CFBridgingRelease(cert);
    if (status != errSecSuccess || !cert) {
        return [NWErrorUtil nilWithErrorCode:kNWErrorIdentityCopyCertificate reason:status error:error];
    }
    return certificate;
}

+ (NWKeyRef)keyWithIdentity:(NWIdentityRef)identity error:(NSError *__autoreleasing *)error
{
    SecKeyRef k = NULL;
    OSStatus status = identity ? SecIdentityCopyPrivateKey((__bridge SecIdentityRef)identity, &k) : errSecParam;
    NWKeyRef key = CFBridgingRelease(k);
    if (status != errSecSuccess || !k) {
        return [NWErrorUtil nilWithErrorCode:kNWErrorIdentityCopyPrivateKey reason:status error:error];
    }
    return key;
}

+ (NSArray *)allIdentitiesWithPKCS12Data:(NSData *)data password:(NSString *)password error:(NSError *__autoreleasing *)error
{
    NSDictionary *options = password ? @{(__bridge id)kSecImportExportPassphrase: password} : @{};
    CFArrayRef items = NULL;
    OSStatus status = data ? SecPKCS12Import((__bridge CFDataRef)data, (__bridge CFDictionaryRef)options, &items) : errSecParam;
    NSArray *dicts = CFBridgingRelease(items);
    if (status != errSecSuccess || !items) {
        switch (status) {
            case errSecDecode: return [NWErrorUtil nilWithErrorCode:kNWErrorPKCS12Decode error:error];
            case errSecAuthFailed: return [NWErrorUtil nilWithErrorCode:kNWErrorPKCS12AuthFailed error:error];
#if !TARGET_OS_IPHONE
            case errSecPkcs12VerifyFailure: return [NWErrorUtil nilWithErrorCode:kNWErrorPKCS12Password error:error];
            case errSecPassphraseRequired: return [NWErrorUtil nilWithErrorCode:kNWErrorPKCS12PasswordRequired error:error];
#endif
        }
        return [NWErrorUtil nilWithErrorCode:kNWErrorPKCS12Import reason:status error:error];
    }
    return dicts;
}

+ (NSArray *)allKeychainCertificatesWithError:(NSError *__autoreleasing *)error
{
    NSDictionary *options = @{(__bridge id)kSecClass: (__bridge id)kSecClassCertificate,
                              (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll};
    CFArrayRef certs = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)options, (CFTypeRef *)&certs);
    NSArray *certificates = CFBridgingRelease(certs);
    if (status != errSecSuccess || !certs) {
        return [NWErrorUtil nilWithErrorCode:kNWErrorKeychainCopyMatching reason:status error:error];
    }
    return certificates;
}

#if !TARGET_OS_IPHONE
+ (NWIdentityRef)keychainIdentityWithCertificate:(NWCertificateRef)certificate error:(NSError *__autoreleasing *)error
{
    SecIdentityRef ident = NULL;
    OSStatus status = certificate ? SecIdentityCreateWithCertificate(NULL, (__bridge SecCertificateRef)certificate, &ident) : errSecParam;
    NWIdentityRef identity = CFBridgingRelease(ident);
    if (status != errSecSuccess || !ident) {
        switch (status) {
            case errSecItemNotFound: return [NWErrorUtil nilWithErrorCode:kNWErrorKeychainItemNotFound error:error];
        }
        return [NWErrorUtil nilWithErrorCode:kNWErrorKeychainCreateIdentity reason:status error:error];
    }
    return identity;
}

+ (NSDate *)expirationWithCertificate:(NWCertificateRef)certificate
{
    return [self valueWithCertificate:certificate key:(__bridge id)kSecOIDInvalidityDate];
}

+ (id)valueWithCertificate:(NWCertificateRef)certificate key:(id)key
{
    return [self valuesWithCertificate:certificate keys:@[key] error:nil][key][(__bridge id)kSecPropertyKeyValue];
}

+ (NSDictionary *)valuesWithCertificate:(NWCertificateRef)certificate keys:(NSArray *)keys error:(NSError **)error
{
    CFErrorRef e = NULL;
    NSDictionary *result = CFBridgingRelease(SecCertificateCopyValues((__bridge SecCertificateRef)certificate, (__bridge CFArrayRef)keys, &e));
    if (error) *error = CFBridgingRelease(e);
    return result;
}
#endif

#pragma mark - Deprecated

+ (BOOL)isSandboxIdentity:(NWIdentityRef)identity
{
    return [self environmentForIdentity:identity] == NWEnvironmentSandbox;
}

+ (BOOL)isSandboxCertificate:(NWCertificateRef)certificate
{
    return [self environmentForCertificate:certificate] == NWEnvironmentSandbox;
}

+ (NWEnvironment)environmentForIdentity:(NWIdentityRef)identity
{
    NWCertificateRef certificate = [self certificateWithIdentity:identity error:nil];
    return [self environmentForCertificate:certificate];
}

+ (NWEnvironment)environmentForCertificate:(NWCertificateRef)certificate
{
    switch ([self typeWithCertificate:certificate summary:nil]) {
        case kNWCertTypeIOSDevelopment:
        case kNWCertTypeMacDevelopment:
            return NWEnvironmentSandbox;
            
        case kNWCertTypeIOSProduction:
        case kNWCertTypeMacProduction:
            return NWEnvironmentProduction;
        case kNWCertTypeSimplified:
        case kNWCertTypeWebProduction:
        case kNWCertTypeVoIPServices:
        case kNWCertTypeWatchKitServices:
        case kNWCertTypePasses:
        case kNWCertTypeNone:
        case kNWCertTypeUnknown:
            break;
    }
    return NWEnvironmentNone;
}

@end
