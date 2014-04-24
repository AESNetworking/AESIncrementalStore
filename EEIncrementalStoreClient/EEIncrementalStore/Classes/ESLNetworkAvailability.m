//
//  ESLNetworkAvailability.m
//  CheckList
//
//  Created by roberto avanzi on 29/01/14.
//  Copyright (c) 2014 Esselunga. All rights reserved.
//

#import "ESLNetworkAvailability.h"
#import "EEIncrementalStoreRESTClient.h"
#import "ESLPersistenceManager.h"

@implementation ESLNetworkAvailability

+(ESLNetworkAvailability*)sharedInstance {
    static ESLNetworkAvailability * sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance=[ESLNetworkAvailability new];
    }
    
    return sharedInstance;
}

-(BOOL)isNetworkReachable {

    EEIncrementalStore * incrementalStore=[[ESLPersistenceManager sharedInstance] incrementalStore];
    EEIncrementalStoreRESTClient * restClient=(EEIncrementalStoreRESTClient *)[incrementalStore HTTPClient];
    BOOL valueReturned=[[restClient operationQueue] isSuspended]!=TRUE;
    
    return valueReturned;
    
}

@end
