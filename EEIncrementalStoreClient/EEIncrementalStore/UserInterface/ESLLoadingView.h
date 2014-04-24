//
//  LoadingView.h
//  CheckList
//
//  Created on 18/04/11.
//  Copyright 2011. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ESLLoadingView : UIViewController
{
	UIViewController *_parent;
	UIView *_loadingView;
    UIActivityIndicatorView * _indicator;
}

+ (ESLLoadingView *)sharedESLLoadingView;

- (void)show:(UIViewController *)viewController;
- (void)dismiss;
- (void)setMessageString:(NSString *)messageStr;
- (BOOL)isShow;
- (void)resizeLoadingViewWithOrientation:(UIInterfaceOrientation)orientation;
;
@end
