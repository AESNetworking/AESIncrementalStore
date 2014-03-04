//
//  ESSLAppDelegate.h
//  AFISProva
//
//  Created by roberto avanzi on 25/06/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIApplicationDelegateCoreDataProtocol.h"

@interface ESSLAppDelegate : UIResponder <UIApplicationDelegate,
                                          UIApplicationDelegateCoreDataProtocol>
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic,strong) UINavigationController * navigationController;

@end
