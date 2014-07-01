// EEIncrementalStoreRESTClient.m
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

#import "EEIncrementalStoreRESTClient.h"
#import "ESLPreferenceManager.h"
#import "ESLPersistenceManager.h"
#import "ESLIdentityManager.h"
#import "ESLPreferenceManager.h"

//#define SERVERHIBERNATE
#ifdef SERVERHIBERNATE
#define kVersionStartNumber 0
#else
#define kVersionStartNumber 1
#endif
@interface EEIncrementalStoreRESTClient()<UIAlertViewDelegate> {
    dispatch_queue_t _successRequestQueue;
    dispatch_queue_t _failureRequestQueue;
}

@property (nonatomic,strong) NSManagedObjectModel * mObjectModel;
@property (nonatomic,strong) NSSet * commonObjects;
@property (nonatomic,strong) NSMutableDictionary * jsonRequest;
@property (nonatomic,strong) NSMutableSet * insertedObjects;
@property (nonatomic,strong) NSMutableSet * updatedObjects;
@property (nonatomic,strong) NSMutableSet * deletedObjects;
//@property (nonatomic,strong)
@end

@implementation EEIncrementalStoreRESTClient

+ (EEIncrementalStoreRESTClient *)sharedClient {
    static EEIncrementalStoreRESTClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString * baseURL=[[ESLPreferenceManager sharedInstance] serverURL];
        _sharedClient = [[self alloc] initWithBaseURL:[NSURL URLWithString:baseURL]];
        ESLPersistenceManager * persistenceManager=[ESLPersistenceManager sharedInstance];
        _sharedClient.mObjectModel=[persistenceManager managedObjectModel];
        [[NSNotificationCenter defaultCenter] addObserver:_sharedClient
                                                 selector:@selector(executeDeletedService:)
                                                     name:AFIncrementalStoreContextDidFetchRemoteValues
                                                   object:[persistenceManager managedObjectContext]];
        _sharedClient.jsonRequest=[NSMutableDictionary dictionary];
        _sharedClient.insertedObjects=[NSMutableSet set];
        _sharedClient.updatedObjects=[NSMutableSet set];
        _sharedClient.deletedObjects=[NSMutableSet set];
        _sharedClient->_successRequestQueue=dispatch_queue_create("ESLSuccessRESTQueue", DISPATCH_QUEUE_SERIAL);
        _sharedClient->_failureRequestQueue=dispatch_queue_create("ESLFailureRESTQueue", DISPATCH_QUEUE_SERIAL);
        [AFHTTPRequestOperation addAcceptableStatusCodes:[NSIndexSet indexSetWithIndex:304]]; // add 304 as not modified
        // here insert credential with certificate
        NSURLCredential * credential=nil;
        
        ESLPreferenceManager * preferenceManager=[ESLPreferenceManager sharedInstance];
        
        if( [preferenceManager.useClientCert boolValue] ) {
            ESLIdentityManager * identityManager=[ESLIdentityManager sharedInstance];
            SecIdentityRef identity=[identityManager retrieveSecIdentityRefFromIdentifier:nil];
            if (identity) {
                SecCertificateRef certificate=[identityManager createCertificateFromIdentity:identity];
                if (certificate) {
                    credential=[NSURLCredential
                                credentialWithIdentity:identity certificates:[NSArray arrayWithObject:CFBridgingRelease(certificate)]
                                persistence:NSURLCredentialPersistenceNone];
                }
            }
        } else {
            NSString * username=[preferenceManager username];
            NSString * password=[preferenceManager serverPassword];
            credential=[NSURLCredential credentialWithUser:username
                                                  password:password
                                               persistence:NSURLCredentialPersistenceNone];
        }
        
        if (credential) {
            [_sharedClient setDefaultCredential:credential];
        }
        
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
    
    NSOperationQueue __weak * operationQueue=self.operationQueue;
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
        if (obj != nil) {
            if (![obj isEqual:[NSNull null]]) {
                // Use NSString representation of NSDate to avoid NSInvalidArgumentException when serializing JSON
                if ([obj isKindOfClass:[NSDate class]]) {
                    [mutableAttributes setObject:[obj description] forKey:key];
                } else {
                    [mutableAttributes setObject:obj forKey:key];
                }
            }
        }
    }];
    
    return mutableAttributes;
}

- (NSString *)resourceIdentifierForRepresentation:(NSDictionary *)representation
                                         ofEntity:(NSEntityDescription *)entity
                                     fromResponse:(NSHTTPURLResponse *)response
{
    NSString * primaryKey=nil;
    primaryKey=[[entity userInfo] objectForKey:@"primaryKey"];
    
    assert(primaryKey);
    
    id value = [representation valueForKey:primaryKey];
    if (value) {
        return [value description];
    }
    
    return nil;
}

- (NSString *)localResourceIdentifierForManagedObject:(NSManagedObject *)object {
    if ([object isKindOfClass:[NSManagedObject class]]) {
        NSDictionary * userInfo=[[object entity] userInfo];
        if ([userInfo isKindOfClass:[NSDictionary class]]) {
            NSString * primaryKey=[userInfo valueForKey:@"primaryKey"];
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

#define VALIDPROPERTY(property) (property)?property:[NSNull null]
#define VALIDDICTPROPERTY(property) VALIDPROPERTY(property)

-(NSDictionary *)retrieveJSONRepresentationFromManagedObject:(NSManagedObject *)insertedObject {
    NSEntityDescription * entity=[insertedObject entity];
    NSArray * entityPropertiesKeys=[[entity propertiesByName] allKeys];
    NSDictionary * relationshipNames=[entity relationshipsByName];
    NSString * primaryKey=nil;
    
    NSMutableDictionary *entityParams = [[self
                                          representationOfAttributes:[insertedObject dictionaryWithValuesForKeys:entityPropertiesKeys]
                                          ofManagedObject:insertedObject] mutableCopy];
    [entityParams removeObjectForKey:@"created"];
    [entityParams removeObjectForKey:@"modified"];
    
    for (NSString * relationshipName in relationshipNames) {
        NSArray *relationshipObjects=nil;
        
        if ([[relationshipNames objectForKey:relationshipName] isToMany]) {
            relationshipObjects = [[insertedObject valueForKey:relationshipName] allObjects];
            NSMutableArray *relationshipObjectsJSON = [NSMutableArray arrayWithCapacity:[relationshipObjects count]];
            // NSMutableDictionary * objectJSON=nil;
            
            for (NSManagedObject * objectInRelationship in relationshipObjects) {
                
                primaryKey=[self localResourceIdentifierForManagedObject:objectInRelationship];
                if (primaryKey) {
                    id managedObject=[objectInRelationship valueForKey:primaryKey];
                    if (managedObject) {
                        [relationshipObjectsJSON addObject:managedObject];
                    }
                }
            }
            [entityParams setObject:relationshipObjectsJSON forKey:relationshipName];
        } else {
            id relationshipObject=VALIDDICTPROPERTY([insertedObject valueForKey:relationshipName]);
            if ([relationshipObject isKindOfClass:[NSNull class]]) {
                [entityParams setObject:relationshipObject forKey:relationshipName];
            } else {
                primaryKey=[self localResourceIdentifierForManagedObject:relationshipObject];
                if (primaryKey) {
                    id managedObject=[relationshipObject valueForKey:primaryKey];
                    [entityParams setObject:managedObject forKey:relationshipName];
                }
            }
        }
    }
    return entityParams;
}

-(NSDictionary *)retrieveJSONRepresentationFromManagedObject:(NSManagedObject *)updatedObject
                                                     forKeys:(NSArray *)updatedKeys {
    
    NSArray * attributesKeys=[[[updatedObject entity] attributesByName] allKeys];
    NSArray * relationshipsKeys=[[[updatedObject entity] relationshipsByName] allKeys];
    NSDictionary * relationshipNames=[[updatedObject entity] relationshipsByName];
    //NSArray * entityPropertiesKeys=[[[updatedObject entity] propertiesByName] allKeys];
    NSString * primaryKey=nil;
    
    NSMutableDictionary *entityParams = [[self representationOfAttributes:[updatedObject dictionaryWithValuesForKeys:attributesKeys]
                                                          ofManagedObject:updatedObject] mutableCopy];
    
    for (NSString * key in updatedKeys) {
        if ([attributesKeys containsObject:key]) {
            [entityParams setObject:VALIDDICTPROPERTY([updatedObject valueForKey:key]) forKey:key];
        } else if ([relationshipsKeys containsObject:key]) {
            NSArray *relationshipObjects=nil;
            
            if ([[relationshipNames objectForKey:key] isToMany]) {
                relationshipObjects = [VALIDDICTPROPERTY([updatedObject valueForKey:key]) allObjects];
                NSMutableArray *relationshipObjectsJSON = [NSMutableArray array];
                
                for (NSManagedObject * objectInRelationship in relationshipObjects) {
                    
                    primaryKey=[self localResourceIdentifierForManagedObject:objectInRelationship];
                    if (primaryKey) {
                        [relationshipObjectsJSON addObject:[objectInRelationship valueForKey:primaryKey]];
                    }
                }
                [entityParams setObject:relationshipObjectsJSON forKey:key];
            } else {
                id relationshipObject=VALIDDICTPROPERTY([updatedObject valueForKey:key]);
                if ([relationshipObject isKindOfClass:[NSNull class]]) {
                    [entityParams setObject:relationshipObject forKey:key];
                } else {
                    primaryKey=[self localResourceIdentifierForManagedObject:relationshipObject];
                    if (primaryKey) {
                        id managedObject=[relationshipObject valueForKey:primaryKey];
                        [entityParams setObject:managedObject forKey:key];
                    }
                }
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
    
    NSManagedObjectContext * mObjectContext=[[ESLPersistenceManager sharedInstance] managedObjectContext];
    
    if ([self.jsonRequest count]) {
        NSDictionary * localJSONRequest=[NSDictionary dictionaryWithDictionary:self.jsonRequest];
        NSSet * insertedObjects=[NSSet setWithSet:self.insertedObjects];
        NSSet * updatedObjects=[NSSet setWithSet:self.updatedObjects];
        NSSet * deletedObjects=[NSSet setWithSet:self.deletedObjects];
        NSString * baseURL=[[ESLPreferenceManager sharedInstance] serverURL];
        
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
                NSDictionary * dict=[NSDictionary dictionaryWithObjectsAndKeys:saveChangesRequest, @"saveChangeRequest",
                                     responseObject, @"responseObject",
                                     mObjectContext, @"context",
                                     operation,@"operation",
                                     nil];
                [[NSNotificationCenter defaultCenter]
                 postNotification:[NSNotification notificationWithName:AFIncrementalStoreSaveChangePostPoneRequestKey
                                                                object:dict]];
                NSLog(@"Server committato with response code = %d\n%@", responseCode, responseObject);
            }
        } failure:^(AFHTTPRequestOperation *request, NSError *error) {
            [self.jsonRequest removeAllObjects];
            NSLog(@"Commit fallita, Request Failed with Error: %@, %@", error, error.userInfo);
            NSString *notificationName = AFIncrementalStoreSaveChangePostPoneRequestErrorKey;
            
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            if (error) {
                [userInfo setObject:error forKey:AFIncrementalStoreFetchSaveRequestErrorKey];
            }
            [userInfo setObject:mObjectContext forKey:@"context"];
            [userInfo setObject:request forKey:@"operation"];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:mObjectContext userInfo:userInfo];
            
        }];
        operation.successCallbackQueue=self->_successRequestQueue;
        operation.failureCallbackQueue=self->_failureRequestQueue;
        [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
        [self enqueueHTTPRequestOperation:operation];
    } else {
        
        [[NSNotificationCenter defaultCenter]
         postNotificationName:AFIncrementalStoreContextDidSaveRemoteValues
         object:mObjectContext userInfo:nil];
        
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
    
}

- (NSMutableURLRequest *)requestForDeletedObject:(NSManagedObject *)deletedObject {
    
    [self addObjectToDeletedSection:deletedObject];
    
    return nil;
    
}

- (void) executeDeletedService: (NSNotification* )note {
    NSError * error=[note.userInfo objectForKey:AFIncrementalStoreFetchSaveRequestErrorKey];
    // eseguiamo il servizio di delete solo se il save di incremental store è andato a buon fine e error è nil
    if (error==nil) {
        dispatch_async(self->_successRequestQueue, ^{
            NSLog(@"chiamo deleted");
            NSString * baseURL=[[ESLPreferenceManager sharedInstance] serverURL];
            NSURL * urlService=[[[NSURL alloc] initWithString:baseURL] URLByAppendingPathComponent:@"deletedentities"];
            NSManagedObjectContext * context=[note.userInfo objectForKey:@"context"];
            NSMutableURLRequest * request=[self requestWithMethod:@"GET" path:[urlService absoluteString] parameters:nil];
            NSManagedObject * lastSyncObject=[[[ESLPersistenceManager sharedInstance] incrementalStore] retrieveLastSyncObject];
            NSString * dateSyncString=[lastSyncObject valueForKey:@"lastSync"];
            [request setValue:dateSyncString forHTTPHeaderField:@"If-Modified-Since"];
            DEBUG_LOG(@"request of deletedentities with If-Modified-Since = %@\n", dateSyncString);
            __block AFHTTPRequestOperation *requestOperation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSHTTPURLResponse * response=operation.response;
                NSUInteger responseCode=[response statusCode];
                NSLog(@"Server committato with response code = %ld, JSON = %@\n", (long)responseCode, responseObject);
                NSString * lastDeletedSync=[[response allHeaderFields] valueForKey:@"Last-Modified"];
                DEBUG_LOG(@"response to deletedentities with Last Modified = %@\n", lastDeletedSync);
                NSDictionary * userInfo=[NSDictionary dictionaryWithObjectsAndKeys:context, @"context",
                                         lastDeletedSync, @"lastdeletedsync",
                                         requestOperation, @"operation",
                                         nil];
                NSNotification * notif=[NSNotification notificationWithName:ESLIncrementalStoredeletedFromAPIClient
                                                                     object:responseObject
                                                                   userInfo:userInfo];
                [[NSNotificationCenter defaultCenter]
                 postNotification:notif];
                
            } failure:^(AFHTTPRequestOperation *request, NSError *error) {
                NSLog(@"deleted fallita, Request Failed with Error: %@, %@", error, error.userInfo);
                [[NSNotificationCenter defaultCenter]
                 postNotification:
                 [NSNotification notificationWithName:ESLIncrementalStoredeletedFailFromAPIClient
                                               object:error]];
            }];
            //requestOperation.successCallbackQueue=self->_successRequestQueue;
            //requestOperation.failureCallbackQueue=self->_failureRequestQueue;
            [self enqueueHTTPRequestOperation:requestOperation];
        });
    }
    
}

- (void)failSave:(NSNotification *)note {
    
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      path:(NSString *)path
                                parameters:(NSDictionary *)parameters
{
    NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    
#ifdef DEBUG
    NSString *codaz = [ESLPreferenceManager sharedInstance].codaz;
    
    if( codaz.length ) {
        [request setValue:codaz forHTTPHeaderField:@"X-Codaz"];
    }
#endif
    
    return request;
}

#pragma mark -
@end

NSString * AFISClientForceSyncNotification=@"AFISClientForceSyncNotification";
NSString * ESLIncrementalStoredeletedObjectNotification=@"ESLIncrementalStoredeletedObjectNotification";
NSString * ESLIncrementalStoredeletedFromAPIClient=@"ESLIncrementalStoredeletedFromAPIClient";
NSString * ESLIncrementalStoredeletedFailFromAPIClient=@"ESLIncrementalStoredeletedFailFromAPIClient";

