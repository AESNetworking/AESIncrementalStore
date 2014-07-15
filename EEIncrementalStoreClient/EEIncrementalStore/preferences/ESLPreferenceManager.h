//
//  SLPreferenceManager.h
//  RubricaSede
//
//  Created by Luca Masini on 09/04/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//



@interface ESLPreferenceManager : NSObject

+ (ESLPreferenceManager*) sharedInstance;

@property (readonly) NSString *serverURL;
@property (readonly) NSString * username;
@property (readonly) NSString * serverPassword;
@property (readonly) NSString * validationURL;
@property (readonly) NSNumber * useClientCert;
@property (readonly) NSNumber * eraseCoreDataDB;

@end
