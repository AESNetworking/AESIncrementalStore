//
//  ESLNetworkOperationQueueObserver.m
//  CheckList
//
//  Created by roberto avanzi on 28/03/14.
//  Copyright (c) 2014 Esselunga. All rights reserved.
//

#import "ESLNetworkOperationQueueObserver.h"
#import "EEIncrementalStoreRESTClient.h"
#import "ESLPersistenceManager.h"
#import "ESLLoadingView.h"

@interface ESLNetworkOperationQueueObserver ()

@property (nonatomic) BOOL networkOff;
@property (nonatomic) BOOL waitForOperationQueueEmpty;

@end
@implementation ESLNetworkOperationQueueObserver

+(ESLNetworkOperationQueueObserver*)sharedInstance {
    static ESLNetworkOperationQueueObserver * sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance=[ESLNetworkOperationQueueObserver new];
        sharedInstance.networkOff=NO;
        sharedInstance.waitForOperationQueueEmpty=NO;
        ESLPersistenceManager * persistenceManager=[ESLPersistenceManager sharedInstance];
        EEIncrementalStore * incrementalStore=[persistenceManager incrementalStore];
        EEIncrementalStoreRESTClient * restClient=(EEIncrementalStoreRESTClient *)[incrementalStore HTTPClient];
        [restClient addObserver:sharedInstance forKeyPath:@"operationQueue.suspended" options:0 context:NULL];
        [persistenceManager addObserver:sharedInstance forKeyPath:@"offlineOperationQueue.operationCount" options:0 context:NULL];

    }
    
    return sharedInstance;
}

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                        context:(void *)context {
    
    DEBUG_LOG(@"observing: -[%@ %@]", object, keyPath);
    //NSLog(@"change: %@", change);
    ESLPersistenceManager * persistenceManager=[ESLPersistenceManager sharedInstance];

    if ([keyPath isEqualToString:@"operationQueue.suspended"]) {
        BOOL suspended=[[object valueForKeyPath:keyPath] boolValue];
        if (suspended==TRUE) {
            [persistenceManager.offlineOperationQueue setSuspended:suspended];
            self.networkOff=YES;
        } else if ((suspended==FALSE) && (self.networkOff==YES)) {
            NSUInteger nbrOperation=[[persistenceManager valueForKeyPath:@"offlineOperationQueue.operationCount"] unsignedIntegerValue];
            if (nbrOperation>0) {
                // retrieve root Controller
                UITabBarController * tabCtrl=(UITabBarController *)[[[[UIApplication sharedApplication] delegate] window] rootViewController];
                [[ESLLoadingView sharedESLLoadingView] setMessageString:@"Attendere prego, eseguo operazioni in coda..."];
                [[ESLLoadingView sharedESLLoadingView] show:tabCtrl];
                self.waitForOperationQueueEmpty=YES;
            }
            [persistenceManager.offlineOperationQueue setSuspended:suspended];
            self.networkOff=NO;
        }
    } else if ([keyPath isEqualToString:@"offlineOperationQueue.operationCount"]
               && self.waitForOperationQueueEmpty==YES) {
        
        NSUInteger nbrOperation=[[object valueForKeyPath:@"offlineOperationQueue.operationCount"] unsignedIntegerValue];
        if (nbrOperation==0) {
            [[ESLLoadingView sharedESLLoadingView] dismiss];
            [[ESLLoadingView sharedESLLoadingView] setMessageString:@"Attendere prego..."];
            self.waitForOperationQueueEmpty=NO;
        }
    }
    
}

-(void)dealloc {
    ESLPersistenceManager * persistenceManager=[ESLPersistenceManager sharedInstance];
    EEIncrementalStore * incrementalStore=[persistenceManager incrementalStore];
    EEIncrementalStoreRESTClient * restClient=(EEIncrementalStoreRESTClient *)[incrementalStore HTTPClient];
    [restClient removeObserver:self forKeyPath:@"operationQueue.suspended"];
    [persistenceManager removeObserver:self forKeyPath:@"offlineOperationQueue.operationCount"];
}

@end
