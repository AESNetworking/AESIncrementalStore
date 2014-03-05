// CheckInsIncrementalStore.m
//
// Copyright (c) 2012 Mattt Thompson (http://mattt.me)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "EEIncrementalStore.h"
#import "EEIncrementalStoreRESTClient.h"
#import <AFIncrementalStore/AFIncrementalStore.h>
#import <AFIncrementalStore/AFRESTClient.h>
#import "UIApplicationDelegateCoreDataProtocol.h"
#import <objc/runtime.h>
#import "ESLPersistenceManager.h"

@implementation EEIncrementalStore

+ (void)initialize {
    [NSPersistentStoreCoordinator registerStoreClass:self forStoreType:[self type]];
}

+ (NSString *)type {
    return NSStringFromClass(self);
}

+ (NSManagedObjectModel *)model {

    NSURL * modelURL=[[NSBundle mainBundle] URLForResource:@"EEIncrementalStore"
                                             withExtension:@"momd"];
    
    NSManagedObjectModel * originalModel=[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        
    return [EEIncrementalStore addHiddenModelToApplicationModel:originalModel];
}


- (id <AFIncrementalStoreHTTPClient>)HTTPClient {
    return [EEIncrementalStoreRESTClient sharedClient];
}

- (void)registerNotifications {

    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(executePostDeleteWithObjects:)
     name:ESLIncrementalStoredeletedFromAPIClient    object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(postPonedSaveChangeRequest:)
     name:AFIncrementalStoreSaveChangePostPoneRequestKey
     object:nil];
}

#pragma mark - loadMetadata method override
- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
    [self registerNotifications];
    [self setMainManagedObjectContext:[[ESLPersistenceManager sharedInstance] managedObjectContext]];
    return [super loadMetadata:error];
}

@end
