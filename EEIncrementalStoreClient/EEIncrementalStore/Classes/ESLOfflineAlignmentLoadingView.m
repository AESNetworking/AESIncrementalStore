//
//  ESLOfflineAlignmentLoadingView.m
//  CheckList
//
//  Created by roberto avanzi on 28/04/14.
//  Copyright (c) 2014 Esselunga. All rights reserved.
//

#import "ESLOfflineAlignmentLoadingView.h"
#import "ESLNetworkOperationQueueObserver.h"

@interface ESLOfflineAlignmentLoadingView()
@property (nonatomic,strong) id observerDisplay;
@property (nonatomic,strong) id observerDismiss;
@end

@implementation ESLOfflineAlignmentLoadingView

-(id)init {

    if (self=[super init]) {
        self.observerDisplay=[[NSNotificationCenter defaultCenter]
                                    addObserverForName:kESLNetworkOperationQueueObserverDisplayLoadingViewUINotification
                                                object:nil
                                                 queue:[NSOperationQueue mainQueue]
                                                 usingBlock:^(NSNotification * note) {
                                                     [self displayLoadingViewForOfflineState];
                                                 }];
        self.observerDismiss=[[NSNotificationCenter defaultCenter]
                                    addObserverForName:kESLNetworkOperationQueueObserverDismissLoadingViewUINotification
                                                object:nil
                                                 queue:[NSOperationQueue mainQueue]
                                            usingBlock:^(NSNotification * note) {
                                                [self dismissLoadingViewForOfflineState];
                                            }];
    }
    
    return self;
}

- (void) displayLoadingViewForOfflineState {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"-displayLoadingViewForOfflineState is not a valid method for the class %@", self.class]
                                 userInfo:nil];
}

- (void) dismissLoadingViewForOfflineState {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"-dismissLoadingViewForOfflineState is not a valid method for the class %@", self.class]
                                 userInfo:nil];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.observerDisplay];
    [[NSNotificationCenter defaultCenter] removeObserver:self.observerDismiss];
    self.observerDisplay=nil;
    self.observerDismiss=nil;
}

@end
