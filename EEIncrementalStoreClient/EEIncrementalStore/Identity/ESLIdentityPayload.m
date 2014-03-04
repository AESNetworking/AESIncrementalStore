//
//  SLIdentityPayload.m
//  RubricaSede
//
//  Created by Luca Masini on 27/02/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "ESLIdentityPayload.h"

@interface ESLIdentityPayload()

@property (strong, nonatomic) NSData *identity;
@property (strong, nonatomic) NSString *password;

@end

@implementation ESLIdentityPayload

-(id)initWithIdentity:(NSData*)identity withPassword:(NSString*)password andServiceURL:(NSString*)serviceURL{
    if( self=[super init] ) {
        self.identity = identity;
        self.password = password;
        _serverURL = serviceURL;
    }
    
    return self;
}

+(NSString *)dictionaryKey {
    return @"SLIdentityPayloadKey";
}



-(SecIdentityRef)identityCertificate {
    
    if( !self.identity ) {
        return nil;
    }
    
    // Import the certificate.
    CFStringRef password = (__bridge CFStringRef)self.password;
    const void *keys[] = { kSecImportExportPassphrase };
    const void *values[] = { password };
    
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus result = SecPKCS12Import((__bridge CFDataRef)self.identity, options, &items);
	
	// by ingconti: (we were leaking)
	CFRelease(options);

    if (result != errSecSuccess)
    {
        @throw([NSException exceptionWithName:@"ErrSecSuccess" reason:[NSString stringWithFormat:@"Cannot Import Certificate in PKCS12, Error code %d", errSecSuccess] userInfo:nil]);
    }

    NSArray *itemArray = (__bridge NSArray *)items;
    
    if( itemArray.count!=1 ) {
        @throw([NSException exceptionWithName:@"MoreThanOneCertificate" reason:@"More than one certificate found in identity data" userInfo:nil]);
    }

    NSDictionary *info = [itemArray objectAtIndex:0];
	NSLog(@"%@", info);
    
    SecIdentityRef identityCertificate = (__bridge SecIdentityRef)[info objectForKey:(__bridge NSString *)kSecImportItemIdentity];
    
    if( !identityCertificate ) {
        @throw([NSException exceptionWithName:@"NoIdentityFound" reason:@"Certificate Imported doesn't contain identity" userInfo:nil]);
    }
    
#if 0
    // here try to check certificate summary
    // Get the certificate from the identity.
    SecCertificateRef certificate = NULL;
    OSStatus status = SecIdentityCopyCertificate (identityCertificate,
                                                  &certificate); 
    
    if (status!=errSecSuccess) {
        @throw([NSException exceptionWithName:@"NoCertificateFound" reason:@"Certificate not valid" userInfo:nil]);
    }
    
    CFStringRef certSummary = SecCertificateCopySubjectSummary(certificate); 
    
    NSString* summaryString = [[NSString alloc]
                               initWithString:(__bridge NSString *)certSummary];
    
    CFRelease(certSummary);
    DEBUG_LOG(@"summaryString = %@\n", summaryString);
#endif


    return identityCertificate;
}




// added 22th april



-(NSString*)description;
{
	// suboptimal.. add dump of identity...
	NSString * descr = [NSString stringWithFormat:@"identity: %@ ; server: %@", self.identity, _serverURL];
	return descr;
}

@end
