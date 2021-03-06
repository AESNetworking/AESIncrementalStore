//
//  ESLPreferenceManager.m
//  RubricaSede
//
//  Created by Luca Masini on 09/04/13.
//  Copyright (c) 2013 Luca Masini. All rights reserved.
//

#import "ESLPreferenceManager.h"

static ESLPreferenceManager *singleInstance;

@implementation ESLPreferenceManager {
@private
    NSUserDefaults *userDefaults;
}

+ (ESLPreferenceManager*) sharedInstance {
    
    @synchronized(singleInstance) {
        if( !singleInstance ) {
            singleInstance = [[ESLPreferenceManager alloc] initInternal];
            [singleInstance readDefaultValuesFromSettingsBundle];
        }
    }
    
    return singleInstance;
}

- (id) init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"-init is not a valid initializer for the class %@", self.class]
                                 userInfo:nil];
}

- (id) initInternal {
    
    self = [super init];
    
    if( self ) {
        userDefaults = [NSUserDefaults standardUserDefaults];
    }
    
    return self;
}

- (NSString *) serverURL {
    return [userDefaults objectForKey:@"it.esselunga.mobile.serverURL"];
}

- (NSString *) username {
    return [userDefaults objectForKey:@"it.esselunga.mobile.username"];
}

- (NSString *) serverPassword {
    return [userDefaults objectForKey:@"it.esselunga.mobile.password"];
}

- (NSString *) validationURL {
    return [userDefaults objectForKey:@"it.esselunga.mobile.validationURL"];
}

- (NSNumber *) eraseCoreDataDB {
    return [userDefaults objectForKey:@"it.esselunga.mobile.erasedatabutton"];
}

- (NSNumber *) useClientCert {
    return [userDefaults objectForKey:@"it.esselunga.mobile.useClientCert"];
}

- (void)readDefaultValuesFromSettingsBundle
{
    // no default values have been set, create them here based on what's in our Settings bundle info
    //
    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
    NSString *settingsBundlePath = [pathStr stringByAppendingPathComponent:@"Settings.bundle"];
    NSString *finalPath = [settingsBundlePath stringByAppendingPathComponent:@"Root.plist"];
    NSString *applicationPath = [settingsBundlePath stringByAppendingPathComponent:@"Application.plist"];
    NSString *frameworkPath = [settingsBundlePath stringByAppendingPathComponent:@"Framework.plist"];
    
    NSMutableDictionary *settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:finalPath];
    [settingsDict addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:applicationPath]];
    [settingsDict addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:frameworkPath]];


    NSArray *prefSpecifierArray = [settingsDict objectForKey:@"PreferenceSpecifiers"];
    
    NSMutableDictionary *appDefaults = [NSMutableDictionary new];
    
    NSDictionary *prefItem;
    for (prefItem in prefSpecifierArray)
        {
        NSString *keyValueStr = [prefItem objectForKey:@"Key"];
        id defaultValue = [prefItem objectForKey:@"DefaultValue"];
        
        if (defaultValue!=nil) {
            [appDefaults setObject:defaultValue forKey:keyValueStr];
        }
        }
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

@end
