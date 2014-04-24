//
//  LoadingView.m
//  CheckList
//
//  Created on 18/04/11.
//  Copyright 2011. All rights reserved.
//

#import "ESLLoadingView.h"
#import "ESLSynthesizeSingleton.h"
#import <QuartzCore/QuartzCore.h>

@implementation ESLLoadingView

SYNTHESIZE_SINGLETON_FOR_CLASS(ESLLoadingView)

- (void)loadView
{
	CGRect viewFrame = [[UIScreen mainScreen] applicationFrame];
    UIView *view = [[UIView alloc] initWithFrame:viewFrame];
    view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.33];
    view.contentMode = UIViewContentModeCenter;
    view.autoresizingMask=UIViewAutoresizingNone;
	CGRect loadingViewFrame =CGRectMake(160.f, 160.f, 160.f, 120.f);
							   
	_loadingView = [[UIView alloc] initWithFrame:loadingViewFrame];
    _loadingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.66];
    _loadingView.layer.cornerRadius = 10.f;

    _indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _indicator.center = CGPointMake(80.f, 36.f);
    [_loadingView addSubview:_indicator];
    
	CGRect messageFrame = CGRectMake(0.f, 54.f, 160.f, 60.f);
	
    UILabel *message = [[UILabel alloc] initWithFrame:messageFrame];
    message.backgroundColor = [UIColor clearColor];
    message.text = @"Attendere prego...";
    message.font = [UIFont fontWithName:@"Arial-MT" size:14];
    message.textAlignment = NSTextAlignmentCenter;
    message.textColor = [UIColor whiteColor];
    message.numberOfLines = 3;
    
    [_loadingView addSubview:message];

    [view addSubview:_loadingView];
    
    self.view = view;
}

- (void)show:(UIViewController *)viewController
{
	_parent = viewController;
    CGRect viewFrame = [[UIScreen mainScreen] bounds];
	UIInterfaceOrientation orientation=viewController.interfaceOrientation;
    CGFloat width=viewFrame.size.width, height=viewFrame.size.height;
	CGRect frameView;
    
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        width=viewFrame.size.height;
        height=viewFrame.size.width;
    }
    frameView=CGRectMake(0.f, 0.f, width, height);
																				    
	self.view.frame = frameView;
	
	_loadingView.center = self.view.center;
    [_indicator startAnimating];
    [_parent.view addSubview:self.view];
}

- (void)dismiss
{	
    [self.view removeFromSuperview];
    [_indicator stopAnimating];
}

- (void)setMessageString:(NSString *)messageStr {
    
    for (UILabel * messageLabel in [_loadingView subviews]) {
        
        if ([messageLabel isKindOfClass:[UILabel class]]) {
            
            messageLabel.text = messageStr;
        }
    }
}

- (BOOL)isShow {
    return (self.view.superview!=nil);
}

- (void)resizeLoadingViewWithOrientation:(UIInterfaceOrientation)orientation {
    CGRect bounds=[[UIScreen mainScreen] bounds];
    CGSize size=bounds.size;
    CGFloat width=size.width, height=size.height;
    CGRect frameView=self.view.frame;
    
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        width=size.height;
        height=size.width;
        if ([_parent splitViewController]!=nil) {
            width-=320.f;
        }
    }
    
    frameView.size=CGSizeMake(width, height);
    self.view.frame=frameView;
    
	_loadingView.center = self.view.center;
}

@end
