//
//  NWSecTools.m
//  Pusher
//
//  Copyright (c) 2012 noodlewerk. All rights reserved.
//

#import "NWSecTools.h"


static NSString * const NWDevelopmentiOSPrefix = @"Apple Development IOS Push Services: ";
static NSString * const NWProductioniOSPrefix = @"Apple Production IOS Push Services: ";
static NSString * const NWDevelopmentMacPrefix = @"Apple Development Mac Push Services: ";
static NSString * const NWProductionMacPrefix = @"Apple Production Mac Push Services: ";

typedef enum {
    kNWCertificateTypeNone = 0,
    kNWCertificateTypeDevelopment = 1,
    kNWCertificateTypeProduction = 2,
    kNWCertificateTypeUnknown = 3,
} NWCertificateType;


@implementation NWSecTools

#if !TARGET_OS_IPHONE

+ (NWPusherResult)identityWithCertificateData:(NSData *)certificate identity:(SecIdentityRef *)identity
{
    SecCertificateRef c = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)certificate);
    if (!c) return kNWPusherResultCertificateInvalid;
    NWPusherResult result = [self identityWithCertificateRef:c identity:identity];
    return result;
}

+ (NWPusherResult)identityWithCertificateRef:(SecCertificateRef)certificate identity:(SecIdentityRef *)identity
{
    OSStatus status = SecIdentityCreateWithCertificate(NULL, certificate, identity);
    if (status != errSecSuccess) {
        switch (status) {
            case errSecItemNotFound: return kNWPusherResultCertificatePrivateKeyMissing;
        }
        return kNWPusherResultCertificateCreateIdentity;
    }
    
    return kNWPusherResultSuccess;
}

#endif

+ (NWPusherResult)identityWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identity:(SecIdentityRef *)identity
{
    if (identity) *identity = nil;
    NSArray *identities = nil;
    NWPusherResult result = [self identitiesWithPKCS12Data:pkcs12 password:password identities:&identities];
    if (result != kNWPusherResultSuccess) return result;
    if (identities.count == 0) return kNWPusherResultPKCS12NoItems;
    if (identities.count > 1) return kNWPusherResultPKCS12MutlipleItems;
    if (identity) *identity = (SecIdentityRef)CFBridgingRetain(identities.lastObject);
    return kNWPusherResultSuccess;
}

+ (NWPusherResult)identitiesWithPKCS12Data:(NSData *)pkcs12 password:(NSString *)password identities:(NSArray **)identities
{
    if (identities) *identities = nil;
    
    if (!pkcs12.length) {
        return kNWPusherResultPKCS12EmptyData;
    }
    const void *keys[] = {kSecImportExportPassphrase};
    const void *values[] = {(__bridge const void *)password};
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFArrayRef items = NULL;
    OSStatus status = SecPKCS12Import((__bridge CFDataRef)pkcs12, options, &items);
    CFRelease(options);
    if (status != errSecSuccess) {
        CFRelease(items);
        return kNWPusherResultPKCS12InvalidData;
    }
    
    NSMutableArray *ids = @[].mutableCopy;
    for (NSUInteger i = 0; i < CFArrayGetCount(items); i++) {
        CFDictionaryRef dict = CFArrayGetValueAtIndex(items, 0);
        SecIdentityRef ident = (SecIdentityRef)CFDictionaryGetValue(dict, kSecImportItemIdentity);
        if (ident) [ids addObject:(__bridge id)(ident)];
    }
    CFRelease(items);
    if (identities) *identities = ids;
    return kNWPusherResultSuccess;
}

+ (NSArray *)keychainCertificates
{
    const void *keys[] = {kSecClass, kSecMatchLimit};
    int i = 1000;
    CFNumberRef n = CFNumberCreate(NULL, kCFNumberIntType, &i);
    const void *values[] = {kSecClassCertificate, n};
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 2, NULL, NULL);
    CFArrayRef results = NULL;
    
    OSStatus status = SecItemCopyMatching(options, (CFTypeRef *)&results);
    CFRelease(options);
    if (status != errSecSuccess) {
        return nil;
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSArray *candidates = CFBridgingRelease(results);
    for (id c in candidates) {
        SecCertificateRef certificate = (__bridge SecCertificateRef)(c);
        NWCertificateType type = [self typeForCertificate:certificate identifier:nil];
        if (type == kNWCertificateTypeDevelopment || type == kNWCertificateTypeProduction) {
            [result addObject:c];
        }
    }
    
    return result;
}

+ (BOOL)isSandboxCertificateRef:(SecCertificateRef)certificate
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
    NSString *name = CFBridgingRelease(SecCertificateCopySubjectSummary(certificate));
    
    NSArray *prefixes = @[NWDevelopmentiOSPrefix, NWProductioniOSPrefix, NWDevelopmentMacPrefix, NWProductionMacPrefix];
    for (NSString *prefix in prefixes) {
        if ([name hasPrefix:prefix]) {
            if (identifier) *identifier = [name substringFromIndex:prefix.length];
            
            BOOL development = (prefix == NWDevelopmentiOSPrefix || prefix == NWDevelopmentMacPrefix);
            return (development ? kNWCertificateTypeDevelopment : kNWCertificateTypeProduction);
        }
    }
    
    if (identifier) *identifier = name;
    return kNWCertificateTypeUnknown;
}

+ (SecCertificateRef)certificateForIdentity:(SecIdentityRef)identity
{
    SecCertificateRef result = NULL;
    OSStatus status = SecIdentityCopyCertificate(identity, &result);
    if (status != errSecSuccess) return nil;
    return result;
}

+ (NSDictionary *)inspectIdentity:(SecIdentityRef)identity
{
    NSMutableDictionary *result = @{}.mutableCopy;
    SecCertificateRef certificate = NULL;
    OSStatus certstat = SecIdentityCopyCertificate(identity, &certificate);
    result[@"has_certificate"] = @(!!certificate);
    if (certstat) result[@"certificate_error"] = @(certstat);
    if (certificate) {
        result[@"cert_subject_summary"] = CFBridgingRelease(SecCertificateCopySubjectSummary(certificate));
        result[@"cert_data"] = CFBridgingRelease(SecCertificateCopyData(certificate));
        CFRelease(certificate);
    }
    SecKeyRef key = NULL;
    OSStatus keystat = SecIdentityCopyPrivateKey(identity, &key);
    result[@"has_key"] = @(!!key);
    if (keystat) result[@"key_error"] = @(keystat);
    if (key) {
        result[@"key_block_size"] = @(SecKeyGetBlockSize(key));
        CFRelease(key);
    }
    return result;
}

#pragma mark - Deprecated


+ (BOOL)isDevelopmentCertificate:(SecCertificateRef)certificate
{
    return [self isSandboxCertificateRef:certificate];
}

+ (BOOL)isSandboxCertificate:(SecCertificateRef)certificate
{
    return [self isSandboxCertificateRef:certificate];
}

@end
