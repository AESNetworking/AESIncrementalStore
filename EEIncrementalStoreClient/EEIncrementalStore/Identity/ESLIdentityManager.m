//
//  SLIdentityManager.m
//  RubricaSede
//
//  Created by Luca Masini on 27/02/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "ESLIdentityManager.h"
#import "ESLIdentityPayload.h"
#import <Security/Security.h>


#define kEsselungaProvisioningClientCertificate     @"EsselungaProvisioningClientCertificate"
#define kEsselungaCertificateName                   @"EsselungaCertificateName"
#define kEsselungaCertificatePasswordName           @"EsselungaCertificatePasswordName"

NSString * const IdentityManagerCertificateReceived = @"IdentityManagerCertificateReceived";

@implementation ESLIdentityManager

static ESLIdentityManager *sharedInstance = nil;

+ (ESLIdentityManager *) sharedInstance {
    
    if( !sharedInstance ) {
        sharedInstance = [ESLIdentityManager new];
        
    }
    
    return sharedInstance;
}


// by ingconti for now manages errors, too. Should we decide to split....

-(void)certificateReceived:(NSNotification*)notif {

    DEBUG_LOG(@"Received Identity from AW");
    
    NSDictionary *userInfo = notif.userInfo;	
	ESLIdentityPayload *payload = nil;
	NSError * error = [userInfo objectForKey: @"error"]; // make a define ??
	if (error)
	{
		DEBUG_LOG(@"error : %@",  error);
//		return; // by ingconti: make return?? other way to deal with?
	}
    
	payload = [userInfo objectForKey:[ESLIdentityPayload dictionaryKey]];
    
    //[SSKeychain setPasswordData:payload. forService:kEsselungaProvisioningClientCertificate account:kEsselungaCertificateName];
    
    NSUserDefaults * defaults=[NSUserDefaults standardUserDefaults];
    NSString * serverURL=payload.serverURL;
    if(serverURL) {
        [defaults setObject:serverURL  forKey:@"it.esselunga.mobile.serverURL"];

        DEBUG_LOG(@"it.esselunga.mobile.serverURL=%@", [defaults objectForKey:@"it.esselunga.mobile.serverURL"]);
		
		// 22th April:
		/*
		 we are owerwriting default we set in SLPreferenceManager
		
		 there we have:
		 - (NSString *) serverURL
		 - (NSString *) mdmURL
		 
		 so a "setter" approach would be nice...
		 */
    }
    SecIdentityRef ref = payload.identityCertificate;
    if(ref) {
        [defaults setObject: (NSData *)(__bridge id)(persistentRefForIdentity(ref)) forKey:@"it.esselunga.mobile.SecIdentityRef"];
        DEBUG_LOG(@"it.esselunga.mobile.SecIdentityRef=%@", [defaults objectForKey:@"it.esselunga.mobile.SecIdentityRef"]);
    }
	else{
		NSLog(@"SecIdentityRef is NIL");
	}
	
    [defaults synchronize];
    
    // invio della notifica dopo aver salvato e reso disponibile il reference
    // al certificato nei defaults
    [[NSNotificationCenter defaultCenter]
                           postNotificationName:IdentityManagerCertificateReceived
                                         object:nil];
}


CFDataRef persistentRefForIdentity(SecIdentityRef identity) {
    OSStatus status = errSecSuccess;
    
    CFTypeRef  persistent_ref = NULL;
    CFStringRef group_name = (__bridge CFStringRef)@"W6QAMYJ5YU.it.esselunga.mobile.CertificateStore";
    const void *keys[] =   { kSecReturnPersistentRef, kSecValueRef, kSecAttrAccessGroup,    kSecAttrAccessible};
    const void *values[] = { kCFBooleanTrue,          identity,     group_name,             kSecAttrAccessibleAlways};
    const int  numValues = 4;
    
    CFDictionaryRef dict = CFDictionaryCreate(NULL, keys, values, numValues, NULL, NULL);
    status = SecItemDelete(dict);
    DEBUG_LOG(@"SecItemDelete: %ld", status);
    status = SecItemAdd(dict, &persistent_ref);
    DEBUG_LOG(@"SecItemAdd: %ld", status);
    
    if (dict)
        CFRelease(dict);
    
    return (CFDataRef)persistent_ref;
}

SecIdentityRef identityForPersistentRef(CFDataRef persistent_ref)
{
    CFTypeRef   identity_ref     = NULL;
    const void *keys[] =   { kSecClass, kSecReturnRef,  kSecValuePersistentRef };
    const void *values[] = { kSecClassIdentity, kCFBooleanTrue, persistent_ref };
    CFDictionaryRef dict = CFDictionaryCreate(NULL, keys, values,
                                              3, NULL, NULL);
    SecItemCopyMatching(dict, &identity_ref);
    
    if (dict)
        CFRelease(dict);
    
    return (SecIdentityRef)identity_ref;
	// // by ingconti: identity_ref should be released. is not autoreleasing. we are transferring ownership.
}

#pragma mark - class interface methods, returned type should be released using CFRelease!!
-(SecIdentityRef)createIdentityFromPersistentRef:(CFDataRef)persistent_ref {
    return identityForPersistentRef(persistent_ref);
}

-(NSString *)copySummaryString:(SecCertificateRef)certificate
{
    NSString * summaryString=nil;
    
    if (certificate) {
        CFStringRef certSummary = SecCertificateCopySubjectSummary(certificate);
    
        summaryString = [[NSString alloc]
                               initWithString:(__bridge NSString *)certSummary];
    
        CFRelease(certSummary);
    }
    
    return summaryString;
}

-(SecCertificateRef)createCertificateFromIdentity:(SecIdentityRef)identity_ref {
    
    // Get the certificate from the identity.
    SecCertificateRef certificate = NULL;
    OSStatus status = SecIdentityCopyCertificate(identity_ref,
                                                 &certificate);
    if (status) {
        DEBUG_LOG(@"retrieveCertificateFromIdentity failed.\n");
        return NULL;
    }
    
    DEBUG_LOG(@"summary String = %@\n", [self copySummaryString:certificate]);
    return certificate;
}

// Roberto: add method for direct access to Identity Ref
-(SecIdentityRef)retrieveSecIdentityRefFromIdentifier:(NSString *)identifier {
    NSMutableDictionary * genericPasswordQuery = [[NSMutableDictionary alloc] init];
    NSString * group_name = @"W6QAMYJ5YU.it.esselunga.mobile.CertificateStore";
    [genericPasswordQuery setObject:(__bridge id)kSecClassIdentity forKey:(__bridge id)kSecClass];
    //[genericPasswordQuery setObject:identifier forKey:(__bridge id)kSecAttrGeneric];
    [genericPasswordQuery setObject:group_name forKey:(__bridge id)kSecAttrAccessGroup];
    [genericPasswordQuery setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    [genericPasswordQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnPersistentRef];
    
    NSDictionary *tempQuery = [NSDictionary dictionaryWithDictionary:genericPasswordQuery];
    
    CFTypeRef outPersistentData = nil;
    
    if (SecItemCopyMatching((__bridge CFDictionaryRef)tempQuery,
                             (CFTypeRef *)&outPersistentData) == noErr) {
        if (outPersistentData) {
            DEBUG_LOG(@"persistent Ref = %@", outPersistentData);
            return [self createIdentityFromPersistentRef:outPersistentData];
        }
    }
    return NULL;
}

@end
