//
//  NSManagedObject+EEIncrementalStore.m
//  AFISProva
//
//  Created by roberto avanzi on 28/06/13.
//  Copyright (c) 2013 Esselunga. All rights reserved.
//

#import "NSManagedObject+EEIncrementalStore.h"

@implementation NSManagedObject (EEIncrementalStore)


+(NSString *)localResourceIdentifier {
    CFUUIDRef UUID = CFUUIDCreate(NULL);
    NSString *resourceIdentifier = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, UUID);
    CFRelease(UUID);
    return resourceIdentifier;
}


@end
