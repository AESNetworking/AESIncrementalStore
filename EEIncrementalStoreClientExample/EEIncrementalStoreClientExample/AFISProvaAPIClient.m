// CheckInsAPIClient.m
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

#import "AFISProvaAPIClient.h"
#import "UIApplicationDelegateCoreDataProtocol.h"
#import "SLPreferenceManager.h"
#import "AFISTransactionObject.h"

//#define SERVERHIBERNATE
#ifdef SERVERHIBERNATE
#define kVersionStartNumber 0
#else
#define kVersionStartNumber 1
#endif
@interface AFISProvaAPIClient()<UIAlertViewDelegate>

@property (nonatomic,strong) NSManagedObjectModel * mObjectModel;
@property (nonatomic,strong) NSSet * commonObjects;
@property (nonatomic,strong) NSMutableDictionary * jsonRequest;
@property (nonatomic,strong) NSMutableSet * insertedObjects;
@property (nonatomic,strong) NSMutableSet * updatedObjects;
@property (nonatomic,strong) NSMutableSet * deletedObjects;

-(void)showFailTransactionAlertView:(AFISTransactionObject *) transaction;

@end

@implementation AFISProvaAPIClient

+ (AFISProvaAPIClient *)sharedClient {
    static AFISProvaAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString * baseURL=[[SLPreferenceManager sharedInstance] serverURL];
        _sharedClient = [[self alloc] initWithBaseURL:[NSURL URLWithString:baseURL]];
        id<UIApplicationDelegateCoreDataProtocol> delegate=(id<UIApplicationDelegateCoreDataProtocol>)
                                                                                 [[UIApplication sharedApplication] delegate];
        _sharedClient.mObjectModel=[delegate managedObjectModel];
#if 1
        [[NSNotificationCenter defaultCenter] addObserver:_sharedClient
                                                 selector:@selector(executeDeletedService:)
                                                     name:AFIncrementalStoreContextDidFetchRemoteValues
                                                   object:[delegate managedObjectContext]];
#endif
        _sharedClient.jsonRequest=[NSMutableDictionary dictionary];
        _sharedClient.insertedObjects=[NSMutableSet set];
        _sharedClient.updatedObjects=[NSMutableSet set];
        _sharedClient.deletedObjects=[NSMutableSet set];

    });
    
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    
    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [self setDefaultHeader:@"Accept" value:@"application/json"];
    [self setParameterEncoding:AFJSONParameterEncoding];
    
    NSOperationQueue __weak* operationQueue=self.operationQueue;
    [self setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        operationQueue.suspended = (status == AFNetworkReachabilityStatusNotReachable);
    }];
    return self;
}

- (NSDictionary *)representationOfAttributes:(NSDictionary *)attributes
                             ofManagedObject:(NSManagedObject *)managedObject
{
    NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary];
    [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj != nil || ![obj isEqual:[NSNull null]]) {
            // Use NSString representation of NSDate to avoid NSInvalidArgumentException when serializing JSON
            if ([obj isKindOfClass:[NSDate class]]) {
                [mutableAttributes setObject:[obj description] forKey:key];
            } else {
                [mutableAttributes setObject:obj forKey:key];
            }
        }
    }];
    
    return mutableAttributes;
}
/*
- (NSDictionary *)attributesForRepresentation:(NSDictionary *)representation
                                     ofEntity:(NSEntityDescription *)entity
                                 fromResponse:(NSHTTPURLResponse *)response {
    NSDictionary * dictObject=[super attributesForRepresentation:representation
                                                        ofEntity:entity
                                                    fromResponse:response];
    NSMutableDictionary * mutableDictObject=[NSMutableDictionary
                                             dictionaryWithDictionary:dictObject];

    if ([response statusCode]==200) {
        if ([[mutableDictObject objectForKey:@"version"] isKindOfClass:[NSNull class]]) {
            [mutableDictObject setObject:[NSNumber numberWithLong:kVersionStartNumber] forKey:@"version"];
        } else {
            long oldVersion=[[mutableDictObject objectForKey:@"version"] longValue];
            NSNumber * newVersion=[NSNumber numberWithLong:++oldVersion];
            [mutableDictObject setObject:newVersion forKey:@"version"];
        }
        
    }
   
   return mutableDictObject;
}
*/

- (NSString *)resourceIdentifierForRepresentation:(NSDictionary *)representation
                                         ofEntity:(NSEntityDescription *)entity
                                     fromResponse:(NSHTTPURLResponse *)response
{
    static NSMutableArray * _candidateKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _candidateKeys=[NSMutableArray array];
        NSManagedObjectModel * model=self.mObjectModel;
        NSString * primaryKey=nil;
        for (NSEntityDescription *entity in model) {
            primaryKey=[[entity userInfo] objectForKey:@"primaryKey"];
            if (primaryKey) {
                [_candidateKeys addObject:primaryKey];
            }
        }
    });
    
    NSString *key = [[representation allKeys] firstObjectCommonWithArray:_candidateKeys];
    if (key) {
        id value = [representation valueForKey:key];
        if (value) {
            return [value description];
        }
    }
    
    return nil;
}

- (NSString *)localResourceIdentifierForManagedObject:(NSManagedObject *)object {
    if ([object isKindOfClass:[NSManagedObject class]]) {
        NSDictionary * userInfo=[[object entity] userInfo];
        if ([userInfo isKindOfClass:[NSDictionary class]]) {
            NSString * primaryKey=[[[object entity] userInfo] valueForKey:@"primaryKey"];
            NSLog(@"primaryKey = %@\n", primaryKey);
            return primaryKey;
        }
    }
    return nil;
}

- (BOOL)shouldFetchRemoteValuesForRelationship:(NSRelationshipDescription *)relationship
                               forObjectWithID:(NSManagedObjectID *)objectID
                        inManagedObjectContext:(NSManagedObjectContext *)context {


    return NO;
}

- (BOOL)shouldFetchRemoteAttributeValuesForObjectWithID:(NSManagedObjectID *)objectID
                                 inManagedObjectContext:(NSManagedObjectContext *)context
{
    return NO;
    
}

#define VALIDDICTPROPERTY(property) (property)?property:[NSNull null]
#define VALIDPROPERTY(property) (property)?property:[NSNull null]
-(NSDictionary *)retrieveJSONRepresentationFromManagedObject:(NSManagedObject *)insertedObject {
    NSEntityDescription * entity=[insertedObject entity];
    NSArray * entityPropertiesKeys=[[entity propertiesByName] allKeys];
    NSDictionary * relationshipNames=[entity relationshipsByName];

    NSMutableDictionary *entityParams = [[self
                                          representationOfAttributes:[insertedObject dictionaryWithValuesForKeys:entityPropertiesKeys]
                                          ofManagedObject:insertedObject] mutableCopy];
    [entityParams removeObjectForKey:@"created"];
    [entityParams removeObjectForKey:@"modified"];
    
    for (NSString * relationshipName in relationshipNames) {
        NSArray *relationshipObjects=nil;
        
        if ([[relationshipNames objectForKey:relationshipName] isToMany]) {
            relationshipObjects = [[insertedObject valueForKey:relationshipName] allObjects];
        } else {
            relationshipObjects = [NSArray arrayWithObject:VALIDDICTPROPERTY([insertedObject valueForKey:relationshipName])];
        }
        
        NSMutableArray *relationshipObjectsJSON = [NSMutableArray arrayWithCapacity:[relationshipObjects count]];
       // NSMutableDictionary * objectJSON=nil;
        NSString * primaryKey=nil;
        
        for (NSManagedObject * objectInRelationship in relationshipObjects) {
            
            primaryKey=[self localResourceIdentifierForManagedObject:objectInRelationship];
            if (primaryKey) {
//                NSArray * allKeys=[[[objectInRelationship entity] attributesByName] allKeys];
                //objectJSON=[[objectInRelationship dictionaryWithValuesForKeys:[NSArray arrayWithObject:primaryKey]] mutableCopy];
#if 0
                if (![[objectJSON objectForKey:@"created"] isKindOfClass:[NSNull class]]) {
                    [objectJSON setObject:[objectJSON objectForKey:@"created"] forKey:@"created"];
                } else {
                    [objectJSON setObject:[NSNull null] forKey:@"created"];
                }
                if (![[objectJSON objectForKey:@"modified"] isKindOfClass:[NSNull class]]) {
                    [objectJSON setObject:[objectJSON objectForKey:@"modified"] forKey:@"modified"];
                } else {
                    [objectJSON setObject:[NSNull null] forKey:@"modified"];
                }
#endif
                [relationshipObjectsJSON addObject:[objectInRelationship valueForKey:primaryKey]];
            }
        }
        
        [entityParams setObject:relationshipObjectsJSON forKey:relationshipName];
    }
    return entityParams;
}

-(NSDictionary *)retrieveJSONRepresentationFromManagedObject:(NSManagedObject *)updatedObject
                                                     forKeys:(NSArray *)updatedKeys {
    
    NSArray * attributesKeys=[[[updatedObject entity] attributesByName] allKeys];
    NSArray * relationshipsKeys=[[[updatedObject entity] relationshipsByName] allKeys];
    NSDictionary * relationshipNames=[[updatedObject entity] relationshipsByName];
    //NSArray * entityPropertiesKeys=[[[updatedObject entity] propertiesByName] allKeys];

    NSMutableDictionary *entityParams = [[self representationOfAttributes:[updatedObject dictionaryWithValuesForKeys:attributesKeys]
                                                                             ofManagedObject:updatedObject] mutableCopy];
    //[entityParams removeObjectForKey:@"created"];
    //[entityParams removeObjectForKey:@"modified"];
    
    
    for (NSString * key in updatedKeys) {
        if ([attributesKeys containsObject:key]) {
           [entityParams setObject:VALIDDICTPROPERTY([updatedObject valueForKey:key]) forKey:key];
        } else if ([relationshipsKeys containsObject:key]) {
            NSArray *relationshipObjects=nil;
            
            if ([[relationshipNames objectForKey:key] isToMany]) {
                relationshipObjects = [VALIDDICTPROPERTY([updatedObject valueForKey:key]) allObjects];
            } else {
                relationshipObjects = [NSArray arrayWithObject:VALIDDICTPROPERTY([updatedObject valueForKey:key])];
            }
            NSMutableArray *relationshipObjectsJSON = [NSMutableArray array];
            NSMutableDictionary * objectJSON=nil;
            NSString * primaryKey=nil;
            
            for (NSManagedObject * objectInRelationship in relationshipObjects) {
                
                primaryKey=[self localResourceIdentifierForManagedObject:objectInRelationship];
                if (primaryKey) {
                    //NSArray * allKeys=[[[objectInRelationship entity] attributesByName] allKeys];
                    objectJSON=[[objectInRelationship dictionaryWithValuesForKeys:[NSArray arrayWithObject:primaryKey]] mutableCopy];
#if 0
                    if (![[objectJSON objectForKey:@"created"] isKindOfClass:[NSNull class]]) {
                        [objectJSON setObject:[objectJSON objectForKey:@"created"] forKey:@"created"];
                    } else {
                        [objectJSON setObject:[NSNull null] forKey:@"created"];
                    }
                    if (![[objectJSON objectForKey:@"modified"] isKindOfClass:[NSNull class]]) {
                        [objectJSON setObject:[objectJSON objectForKey:@"modified"] forKey:@"modified"];
                    } else {
                        [objectJSON setObject:[NSNull null] forKey:@"modified"];
                    }
#endif
                    [relationshipObjectsJSON addObject:[objectInRelationship valueForKey:primaryKey]];
                }
            }
            if ([relationshipObjectsJSON count]) {
                [entityParams setObject:relationshipObjectsJSON forKey:key];
            }
            
        }
    }
    return entityParams;
}

-(void)beginIncrementalStoreTransaction {

    [self.jsonRequest removeAllObjects];
    [self.insertedObjects removeAllObjects];
    [self.updatedObjects removeAllObjects];
    [self.deletedObjects removeAllObjects];
}

-(void)endIncrementalStoreTransaction {

    if ([self.jsonRequest count]) {
        NSDictionary * localJSONRequest=[NSDictionary dictionaryWithDictionary:self.jsonRequest];
        NSSet * insertedObjects=[NSSet setWithSet:self.insertedObjects];
        NSSet * updatedObjects=[NSSet setWithSet:self.updatedObjects];
        NSSet * deletedObjects=[NSSet setWithSet:self.deletedObjects];
        NSString * baseURL=[[SLPreferenceManager sharedInstance] serverURL];

        NSMutableURLRequest * urlRequest=[self requestWithMethod:@"POST" path:baseURL
                                                                   parameters:localJSONRequest];
        AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:urlRequest success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSHTTPURLResponse * response=operation.response;
            NSUInteger responseCode=[response statusCode];
            
            if  ([responseObject isKindOfClass:[NSArray class]] &&
                 (responseCode==200)) {
                NSSaveChangesRequest *saveChangesRequest = [[NSSaveChangesRequest alloc] initWithInsertedObjects:insertedObjects
                                                                                              updatedObjects:updatedObjects
                                                                                              deletedObjects:deletedObjects
                                                                                              lockedObjects:nil];
                id<UIApplicationDelegateCoreDataProtocol> delegate=(id<UIApplicationDelegateCoreDataProtocol>)
                                                                   [[UIApplication sharedApplication] delegate];
                NSDictionary * dict=[NSDictionary dictionaryWithObjectsAndKeys:saveChangesRequest, @"saveChangeRequest",
                                                                           responseObject, @"responseObject",
                                                                           [delegate managedObjectContext], @"context",
                                                                            operation,@"operation",
                                                                            nil];
                [[NSNotificationCenter defaultCenter]
                                   postNotification:[NSNotification notificationWithName:AFIncrementalStoreSaveChangePostPoneRequestKey
                                                                                    object:dict]];
                //NSLog(@"Server committato with response code = %d\n", responseCode);
            }
        } failure:^(AFHTTPRequestOperation *request, NSError *error) {
            self.jsonRequest=nil;
            NSLog(@"Commit fallita, Request Failed with Error: %@, %@", error, error.userInfo);
        }];
        [self enqueueHTTPRequestOperation:operation];
    }
}

-(void)addObjectToInsertedSection:(NSManagedObject *)insertedObject {

    id insertedSection=[self.jsonRequest objectForKey:@"insertedObjects"];
    NSString * entityName=[[insertedObject entity] name];
    NSDictionary * entityParams=[self retrieveJSONRepresentationFromManagedObject:insertedObject];
    
    if (!insertedSection) {
        // lista vuota, aggiungo un dizionario con nome entity e oggetto
        NSMutableDictionary * section=[NSMutableDictionary
                                       dictionaryWithObjectsAndKeys:[NSMutableArray arrayWithObject:entityParams],
                                       @"listObjects",
                                       entityName,
                                       @"entityName", nil];
        
        [self.jsonRequest setValue:[NSMutableArray arrayWithObject:section] forKey:@"insertedObjects"];
    } else if ([insertedSection isKindOfClass:[NSArray class]]) {
        NSArray * mutableSection=(NSArray *)insertedSection;
        __block NSMutableDictionary * findSection=nil;
        [mutableSection indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL * stop) {
                    NSMutableDictionary * section=obj;
                    if ([[section objectForKey:@"entityName"] isEqualToString:entityName]) {
                        findSection=section;
                        *stop=TRUE;
                        return TRUE;
                    }
                return FALSE;
        }];
        if (findSection) {
            NSMutableArray * listOfObjects=[findSection objectForKey:@"listObjects"];
            [listOfObjects addObject:entityParams];
        } else {
            NSMutableDictionary * section=[NSMutableDictionary
                                           dictionaryWithObjectsAndKeys:[NSMutableArray arrayWithObject:entityParams],
                                           @"listObjects",
                                           entityName,
                                           @"entityName", nil];
            [insertedSection addObject:section];
        }
    }
    [self.insertedObjects addObject:insertedObject];
    
}

-(void)addObjectToUpdatedSection:(NSManagedObject *)updatedObject {
    
    id updatedSection=[self.jsonRequest objectForKey:@"updatedObjects"];
    
    NSString * entityName=[[updatedObject entity] name];
    NSMutableSet *mutableChangedAttributeKeys = [NSMutableSet setWithArray:[[updatedObject changedValues] allKeys]];
    if ([mutableChangedAttributeKeys count] == 0) {
        return;
    }
    NSDictionary * entityParams=[self retrieveJSONRepresentationFromManagedObject:updatedObject
                                                                          forKeys:[[updatedObject changedValues] allKeys]];
    if (!updatedSection) {
        // lista vuota, aggiungo un dizionario con nome entity e oggetto
        NSMutableDictionary * section=[NSMutableDictionary
                                       dictionaryWithObjectsAndKeys:[NSMutableArray arrayWithObject:entityParams],
                                       @"listObjects",
                                       entityName,
                                       @"entityName", nil];
        
        [self.jsonRequest setValue:[NSMutableArray arrayWithObject:section] forKey:@"updatedObjects"];
    } else if ([updatedSection isKindOfClass:[NSArray class]]) {
        NSArray * mutableSection=(NSArray *)updatedSection;
        __block NSMutableDictionary * findSection=nil;
        [mutableSection indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL * stop) {
            NSMutableDictionary * section=obj;
            if ([[section objectForKey:@"entityName"] isEqualToString:entityName]) {
                findSection=section;
                *stop=TRUE;
                return TRUE;
            }
            return FALSE;
        }];
        if (findSection) {
            NSMutableArray * listOfObjects=[findSection objectForKey:@"listObjects"];
            [listOfObjects addObject:entityParams];
        } else {
            NSMutableDictionary * section=[NSMutableDictionary
                                           dictionaryWithObjectsAndKeys:[NSMutableArray arrayWithObject:entityParams],
                                           @"listObjects",
                                           entityName,
                                           @"entityName", nil];
            [updatedSection addObject:section];
        }
    }
    [self.updatedObjects addObject:updatedObject];
}

-(void)addObjectToDeletedSection:(NSManagedObject *)deletedObject {
    
    id deletedSection=[self.jsonRequest objectForKey:@"deletedObjects"];
    NSString * entityName=[[deletedObject entity] name];
    NSString * primaryKeyIdentifier=[self localResourceIdentifierForManagedObject:deletedObject];
    NSString * primaryKey=[deletedObject valueForKey:primaryKeyIdentifier];
    
    if (!deletedSection) {
        // lista vuota, aggiungo un dizionario con nome entity e oggetto
        NSMutableDictionary * section=[NSMutableDictionary
                                       dictionaryWithObjectsAndKeys:[NSMutableArray arrayWithObject:primaryKey],
                                       @"listObjects",
                                       entityName,
                                       @"entityName", nil];
        
        [self.jsonRequest setValue:[NSMutableArray arrayWithObject:section] forKey:@"deletedObjects"];
    } else if ([deletedSection isKindOfClass:[NSArray class]]) {
        NSArray * mutableSection=(NSArray *)deletedSection;
        __block NSMutableDictionary * findSection=nil;
        [mutableSection indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL * stop) {
            NSMutableDictionary * section=obj;
            if ([[section objectForKey:@"entityName"] isEqualToString:entityName] ) {
                findSection=section;
                *stop=TRUE;
                return TRUE;
            }
            return FALSE;
        }];
        if (findSection) {
            NSMutableArray * listOfObjects=[findSection objectForKey:@"listObjects"];
            if (primaryKey) {
                [listOfObjects addObject:primaryKey];
            }
        } else {
            NSMutableDictionary * section=[NSMutableDictionary
                                           dictionaryWithObjectsAndKeys:[NSMutableArray arrayWithObject:primaryKey],
                                           @"listObjects",
                                           entityName,
                                           @"entityName", nil];
            [deletedSection addObject:section];
        }
    }
    [self.deletedObjects addObject:deletedObject];
}

- (NSMutableURLRequest *)requestForInsertedObject:(NSManagedObject *)insertedObject {
    
    [self addObjectToInsertedSection:insertedObject];
    
    return nil;
}

- (NSMutableURLRequest *)requestForUpdatedObject:(NSManagedObject *)updatedObject {

    [self addObjectToUpdatedSection:updatedObject];
    
    return nil;
    
#if 0
    NSMutableSet *mutableChangedAttributeKeys = [NSMutableSet setWithArray:[[updatedObject changedValues] allKeys]];
    if ([mutableChangedAttributeKeys count] == 0) {
        return nil;
    }
    #if 1
    NSDictionary * entityParams=[self retrieveJSONRepresentationFromManagedObject:updatedObject
                                                                          forKeys:[[updatedObject changedValues] allKeys]];
    
    if ([entityParams count]) {
        return [self requestWithMethod:@"PUT" path:[self pathForObject:updatedObject] parameters:entityParams];
    }
    return nil;
    
    #else
    return [self requestWithMethod:@"PUT" path:[self pathForObject:updatedObject]
                    parameters:[self representationOfAttributes:[[updatedObject changedValues]
                    dictionaryWithValuesForKeys:[mutableChangedAttributeKeys allObjects]] ofManagedObject:updatedObject]];
    #endif
#endif
}

- (NSMutableURLRequest *)requestForDeletedObject:(NSManagedObject *)deletedObject {
    
    [self addObjectToDeletedSection:deletedObject];
    
    return nil;

}

- (NSURLRequest *)requestWithPath:(NSString *)path withMethod:(NSString *) method
                      withObjects:(NSSaveChangesRequest *)snapshot {
    
    NSURL *url = [[NSURL alloc] initWithString:path];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:method];
    //[request setValue:[NSString stringWithFormat:@"application/json"] forHTTPHeaderField:@"Content-Type"];
    // qui prendo solo, tra gli oggetti inserted e updated, quelli non duplicati
    // per farlo verifico la primary key di ogni managed object, leggendo
    // l'identificativo dal dict userInfo
    if  (snapshot) {
        NSSet * insertedObjects=[snapshot insertedObjects];
        NSSet * updatedObjects=[snapshot updatedObjects];
        NSSet * filteredObjects=[updatedObjects
                             objectsPassingTest:^BOOL (id obj, BOOL * stop) {
                                NSManagedObject * mUpdatedObject=obj;
                                NSString * updatedEntityPrimaryKey=[[[mUpdatedObject entity]
                                                              userInfo] objectForKey:@"primaryKey"];
                                if (updatedEntityPrimaryKey) {
                                     NSSet * foundIndex;
                                     NSString * updatedObjectPrimaryKey=[mUpdatedObject valueForKey:updatedEntityPrimaryKey];
                                    foundIndex=[insertedObjects
                                                objectsPassingTest:^BOOL (id obj, BOOL * stop) {
                                                    NSManagedObject * mInserterdObject=obj;
                                                    NSString * insertedEntityPrimaryKey=[[[mInserterdObject entity]
                                                                                  userInfo] objectForKey:@"primaryKey"];
                                                    if (insertedEntityPrimaryKey) {
                                                        if (![insertedEntityPrimaryKey isEqualToString:updatedObjectPrimaryKey]) {
                                                            *stop=YES;
                                                            return YES;
                                                        }
                                                    }
                                                    return NO;
                                                }];
                                    if ([foundIndex count]) {
                                        return YES;
                                    }
                                }
                            return NO;
                            }];
    
        self.commonObjects=[insertedObjects setByAddingObjectsFromSet:filteredObjects];
    }
    return request;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex==1) {
        [[NSNotificationCenter defaultCenter]
                    postNotificationName:AFISClientForceSyncNotification object:nil];
    }
}

-(void)showFailTransactionAlertView:(AFISTransactionObject *) transaction {
    NSOperationQueue * mainQueue=[NSOperationQueue mainQueue];
    UIAlertView * alertView=[[UIAlertView alloc] initWithTitle:@"Attenzione" message:@"Allineamento al server non riuscito. Vuoi riprovare ad allineare la tua base dati? Le ultime modifiche saranno perdute." delegate:self cancelButtonTitle:@"Cancella" otherButtonTitles:@"Allinea dati", nil];
    [mainQueue addOperationWithBlock:^{
            [alertView show];
    }];
}
    
- (void) commitOnSuccess: (NSNotification* )note {
    NSLog(@"****************************************************** IncrementaleStore sincronizzato, chiamo commit");
    NSSaveChangesRequest * saveChangesRequest=[[note userInfo] objectForKey:AFIncrementalStorePersistentStoreRequestKey];
    NSString * baseURL=[[SLPreferenceManager sharedInstance] serverURL];
    NSURLRequest * request=[self requestWithPath:[baseURL stringByAppendingString:@"storage"] withMethod:@"POST" withObjects:saveChangesRequest];
    AFISTransactionObject * __block currentTransaction=[[AFISTransactionObject alloc] initWithChangeRequest:saveChangesRequest];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"Server committato with response code = %d\n", [response statusCode]);
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        NSLog(@"Commit fallita, Request Failed with Error: %@, %@, %@", error, error.userInfo, JSON);
        NSURLRequest * deleteRequest=[self requestWithPath:[baseURL stringByAppendingString:@"storage"] withMethod:@"DELETE" withObjects:nil];
        AFJSONRequestOperation *deleteOperation = [AFJSONRequestOperation JSONRequestOperationWithRequest:deleteRequest success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            NSLog(@"Server risposto a storage/delete  with response code = %d\n", [response statusCode]);
            [self showFailTransactionAlertView:currentTransaction];
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
            NSLog(@"storage/delete fallita, Request Failed with Error: %@, %@, %@", error, error.userInfo, JSON);
            [self showFailTransactionAlertView:currentTransaction];            
        }];
        [deleteOperation start];
    }];
    [operation start];
    
}

- (void) executeDeletedService: (NSNotification* )note {
    NSLog(@"****************************************************** IncrementaleStore sincronizzato, chiamo deleted");
    NSString * baseURL=[[SLPreferenceManager sharedInstance] serverURL];
    NSURLRequest * request=[self requestWithPath:[baseURL stringByAppendingString:@"deletedentities"] withMethod:@"GET" withObjects:nil];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSLog(@"Server committato with response code = %d, JSON = %@\n", [response statusCode], JSON);
        [[NSNotificationCenter defaultCenter]
                               postNotification:
                               [NSNotification notificationWithName:ESSLIncrementalStoredeletedFromAPIClient
                                                             object:JSON]];
        
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        NSLog(@"deleted fallita, Request Failed with Error: %@, %@, %@", error, error.userInfo, JSON);
        [[NSNotificationCenter defaultCenter]
         postNotification:
         [NSNotification notificationWithName:ESSLIncrementalStoredeletedFailFromAPIClient
                                       object:JSON]];
    }];
    [operation start];
}

#pragma mark -
@end

NSString * AFISClientForceSyncNotification=@"AFISClientForceSyncNotification";
NSString * ESSLIncrementalStoredeletedObjectNotification=@"ESSLIncrementalStoredeletedObjectNotification";
NSString * ESSLIncrementalStoredeletedFromAPIClient=@"ESSLIncrementalStoredeletedFromAPIClient";
NSString * ESSLIncrementalStoredeletedFailFromAPIClient=@"ESSLIncrementalStoredeletedFailFromAPIClient";

