//
//  ESLNetworkOperationQueueObserver.h
//  CheckList
//
//  Created by roberto avanzi on 28/03/14.
//  Copyright (c) 2014 Esselunga. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * kESLNetworkOperationQueueObserverDisplayLoadingViewUINotification;
extern NSString * kESLNetworkOperationQueueObserverDismissLoadingViewUINotification;

@interface ESLNetworkOperationQueueObserver : NSObject

+ (ESLNetworkOperationQueueObserver*)sharedInstance;

@end
