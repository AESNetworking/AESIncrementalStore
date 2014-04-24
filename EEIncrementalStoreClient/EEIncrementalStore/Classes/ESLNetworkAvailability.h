//
//  ESLNetworkAvailability.h
//  CheckList
//
//  Created by roberto avanzi on 29/01/14.
//  Copyright (c) 2014 Esselunga. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ESLNetworkAvailability : NSObject

+ (ESLNetworkAvailability*)sharedInstance;

-(BOOL)isNetworkReachable;

@end
