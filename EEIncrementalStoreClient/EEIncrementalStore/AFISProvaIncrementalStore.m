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

#import "AFISProvaIncrementalStore.h"
#import "AFISProvaAPIClient.h"
#import "Department.h"
#import "Employee.h"
#import <AFIncrementalStore/AFIncrementalStore.h>
#import <AFIncrementalStore/AFRESTClient.h>
#import "UIApplicationDelegateCoreDataProtocol.h"
#import <TransformerKit/TTTDateTransformers.h>
#import <objc/runtime.h>

@implementation AFISProvaIncrementalStore

+ (void)initialize {
    [NSPersistentStoreCoordinator registerStoreClass:self forStoreType:[self type]];
}

+ (NSString *)type {
    return NSStringFromClass(self);
}

+ (NSManagedObjectModel *)model {
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"AFISProva" withExtension:@"xcdatamodeld"]];
}

- (id <AFIncrementalStoreHTTPClient>)HTTPClient {
    return [AFISProvaAPIClient sharedClient];
}

#if 0
-(void)sync:(NSNotification * )note {

    NSLog(@"ricevuta sync");
    [[NSNotificationCenter defaultCenter]
                           postNotificationName:AFISForceSyncNotification
                                         object:nil];
}
#endif

- (void)registerNotifications {
#if 0
    [[NSNotificationCenter defaultCenter]
                           addObserver:self
                           selector:@selector(sync:)
                           name:AFISClientForceSyncNotification
                           object:nil];
#endif
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(postPonedSaveChangeRequest:)
     name:AFIncrementalStoreSaveChangePostPoneRequestKey
     object:nil];
}

#pragma mark - loadMetadata method override
- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
    [self registerNotifications];
    return [super loadMetadata:error];
}

@end
