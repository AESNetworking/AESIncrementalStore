//
//  ESSLAppDelegate.m
//  AFISProva
//
//  Created by roberto avanzi on 25/06/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import "ESSLAppDelegate.h"
#import <AFIncrementalStore/AFIncrementalStore.h>
#import "AFISProvaIncrementalStore.h"
#import "AFISProvaViewController.h"
#import "ESLPreferenceManager.h"
#import <objc/runtime.h>

@implementation ESSLAppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [ESLPreferenceManager sharedInstance];
#if 0
    NSFetchRequest * fetchRequest=[self.managedObjectModel fetchRequestTemplateForName:@"AllDepartment"];
    [[ESSLServerSynchronization sharedInstance] setMainContext:self.managedObjectContext];
    [[ESSLServerSynchronization sharedInstance] setPrimaryFetchRequest:fetchRequest];
#endif
    AFISProvaViewController *viewController = [[AFISProvaViewController alloc] init];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    self.window.rootViewController = self.navigationController;
    
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark - Core Data stack

static char incrementalStoreProperty;

-(id)incrementalStore {
    return objc_getAssociatedObject(self, &incrementalStoreProperty);
}

-(void)setIncrementalStore:(id)incrementalStore {
    objc_setAssociatedObject(self, &incrementalStoreProperty,
                             incrementalStore, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
