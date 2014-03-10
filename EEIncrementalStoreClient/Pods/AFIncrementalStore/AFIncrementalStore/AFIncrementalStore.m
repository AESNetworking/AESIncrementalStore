    // AFIncrementalStore.m
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

#import "AFIncrementalStore.h"
#import "AFHTTPClient.h"
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

NSString * const AFIncrementalStoreUnimplementedMethodException = @"com.alamofire.incremental-store.exceptions.unimplemented-method";

NSString * const AFIncrementalStoreContextWillFetchRemoteValues = @"AFIncrementalStoreContextWillFetchRemoteValues";
NSString * const AFIncrementalStoreContextWillSaveRemoteValues = @"AFIncrementalStoreContextWillSaveRemoteValues";
NSString * const AFIncrementalStoreContextDidFetchRemoteValues = @"AFIncrementalStoreContextDidFetchRemoteValues";
NSString * const AFIncrementalStoreContextDidSaveRemoteValues = @"AFIncrementalStoreContextDidSaveRemoteValues";
NSString * const AFIncrementalStoreContextWillFetchNewValuesForObject = @"AFIncrementalStoreContextWillFetchNewValuesForObject";
NSString * const AFIncrementalStoreContextDidFetchNewValuesForObject = @"AFIncrementalStoreContextDidFetchNewValuesForObject";
NSString * const AFIncrementalStoreContextWillFetchNewValuesForRelationship = @"AFIncrementalStoreContextWillFetchNewValuesForRelationship";
NSString * const AFIncrementalStoreContextDidFetchNewValuesForRelationship = @"AFIncrementalStoreContextDidFetchNewValuesForRelationship";

NSString * const AFIncrementalStoreRequestOperationsKey = @"AFIncrementalStoreRequestOperations";
NSString * const AFIncrementalStoreFetchedObjectIDsKey = @"AFIncrementalStoreFetchedObjectIDs";
NSString * const AFIncrementalStoreFaultingObjectIDKey = @"AFIncrementalStoreFaultingObjectID";
NSString * const AFIncrementalStoreFaultingRelationshipKey = @"AFIncrementalStoreFaultingRelationship";
NSString * const AFIncrementalStorePersistentStoreRequestKey = @"AFIncrementalStorePersistentStoreRequest";
// Roberto ADD
NSString * const AFIncrementalStoreFetchSaveRequestErrorKey = @"AFIncrementalStoreFetchSaveRequestError";

static char kAFResourceIdentifierObjectKey;

static NSString * const kAFIncrementalStoreResourceIdentifierAttributeName = @"__af_resourceIdentifier";
static NSString * const kAFIncrementalStoreLastModifiedAttributeName = @"__af_lastModified";

static NSString * const kAFReferenceObjectPrefix = @"__af_";

// Roberto ADD, used for EEIncrementalStore customization
static NSString * const kAFIncrementalStoreAlignedAttributeName = @"__af_aligned";
static NSString * const kAFIncrementalStoreVersionAttributeName = @"version";
static NSString * const kAFIncrementalStoreCreatedAttributeName = @"created";
static NSString * const kAFIncrementalStoreModifiedAttributeName = @"modified";
static NSString * const kAFIncrementalStoreEntityJournalingLastUpdateAttributeName = @"lastUpdate";
static NSString * const kAFIncrementalStoreEntityJournalingNomeEntityAttributeName = @"nomeEntity";
static NSString * const kAFIncrementalStoreBusinessIdAttributeName = @"businessId";

/* a key for NSSaveChangeRequest postponed modification */
NSString * const AFIncrementalStoreSaveChangePostPoneRequestKey=@"AFIncrementalStoreSaveChangePostPoneRequestKey";


inline NSString * AFReferenceObjectFromResourceIdentifier(NSString *resourceIdentifier) {
    if (!resourceIdentifier) {
        return nil;
    }
    
    return [kAFReferenceObjectPrefix stringByAppendingString:resourceIdentifier];    
}

inline NSString * AFResourceIdentifierFromReferenceObject(id referenceObject) {
    if (!referenceObject) {
        return nil;
    }
    
    NSString *string = [referenceObject description];
    return [string hasPrefix:kAFReferenceObjectPrefix] ? [string substringFromIndex:[kAFReferenceObjectPrefix length]] : string;
}

static inline void AFSaveManagedObjectContextOrThrowInternalConsistencyException(NSManagedObjectContext *managedObjectContext, NSError * __autoreleasing *error) {
    NSError * __autoreleasing * localError=nil;
    [managedObjectContext performBlockAndWait:^{
        if (![managedObjectContext save:localError]) {
            if (!localError) {
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoreDataError userInfo:nil];
            } else {
                *error=*localError;
            }

            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[*error localizedFailureReason] userInfo:[NSDictionary dictionaryWithObject:*error forKey:NSUnderlyingErrorKey]];
        }
    }];
}

@interface NSManagedObject (_AFIncrementalStoreHidden)
@property (readwrite, nonatomic, copy, setter = af_setResourceIdentifier:) NSString *af_resourceIdentifier;

@end

@implementation NSManagedObject (_AFIncrementalStoreHidden)
@dynamic af_resourceIdentifier;

- (NSString *)af_resourceIdentifier {
    NSString *identifier = (NSString *)objc_getAssociatedObject(self, &kAFResourceIdentifierObjectKey);
    
    if (!identifier) {
        if ([self.objectID.persistentStore isKindOfClass:[AFIncrementalStore class]]) {
            id referenceObject = [(AFIncrementalStore *)self.objectID.persistentStore referenceObjectForObjectID:self.objectID];
            if ([referenceObject isKindOfClass:[NSString class]]) {
                return AFResourceIdentifierFromReferenceObject(referenceObject);
            }
        }
    }
    
    return identifier;
}

- (void)af_setResourceIdentifier:(NSString *)resourceIdentifier {
    objc_setAssociatedObject(self, &kAFResourceIdentifierObjectKey, resourceIdentifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}


@end

// Roberto ADD
@implementation NSManagedObject (AFIncrementalStorePublic)
@dynamic af_aligned;


static char kAlignedAttributeObjectKey;

- (NSString *)af_aligned {
    
    NSString *aligned = (NSString *)objc_getAssociatedObject(self, &kAlignedAttributeObjectKey);
    
    return aligned;
}

- (void)af_setAlignedAttribute:(NSNumber *)af_aligned {
    objc_setAssociatedObject(self, &kAlignedAttributeObjectKey,
                             af_aligned, OBJC_ASSOCIATION_COPY_NONATOMIC);
}


// Roberto END

@end

#pragma mark -

@implementation AFIncrementalStore {
@private
    NSCache *_backingObjectIDByObjectID;
    NSMutableDictionary *_registeredObjectIDsByEntityNameAndNestedResourceIdentifier;
    NSPersistentStoreCoordinator *_backingPersistentStoreCoordinator;
    dispatch_queue_t _successRequestQueue;
    dispatch_queue_t _failureRequestQueue;
    //NSManagedObjectContext *_backingManagedObjectContext;
}

@synthesize HTTPClient = _HTTPClient;
@synthesize backingPersistentStoreCoordinator = _backingPersistentStoreCoordinator;
@synthesize backingManagedObjectContext=_backingManagedObjectContext;

+ (NSString *)type {
    @throw([NSException exceptionWithName:AFIncrementalStoreUnimplementedMethodException reason:NSLocalizedString(@"Unimplemented method: +type. Must be overridden in a subclass", nil) userInfo:nil]);
}

+ (NSManagedObjectModel *)model {
    @throw([NSException exceptionWithName:AFIncrementalStoreUnimplementedMethodException reason:NSLocalizedString(@"Unimplemented method: +model. Must be overridden in a subclass", nil) userInfo:nil]);
}

#pragma mark -


- (void)notifyManagedObjectContext:(NSManagedObjectContext *)context
             aboutRequestOperation:(AFHTTPRequestOperation *)operation
                   forFetchRequest:(NSFetchRequest *)fetchRequest
                  fetchedObjectIDs:(NSArray *)fetchedObjectIDs
                         withError:(NSError *)error
{
    NSString *notificationName = [operation isFinished] ? AFIncrementalStoreContextDidFetchRemoteValues : AFIncrementalStoreContextWillFetchRemoteValues;
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:[NSArray arrayWithObject:operation] forKey:AFIncrementalStoreRequestOperationsKey];
    [userInfo setObject:fetchRequest forKey:AFIncrementalStorePersistentStoreRequestKey];
    [userInfo setObject:context forKey:@"context"]; // Rob ADD
    if ([operation isFinished] && fetchedObjectIDs) {
        [userInfo setObject:fetchedObjectIDs forKey:AFIncrementalStoreFetchedObjectIDsKey];
    }
    if (error) {
        [userInfo setObject:error forKey:AFIncrementalStoreFetchSaveRequestErrorKey];
    }
   
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:context userInfo:userInfo];
}

- (void)notifyManagedObjectContext:(NSManagedObjectContext *)context
            aboutRequestOperations:(NSArray *)operations
             forSaveChangesRequest:(NSSaveChangesRequest *)saveChangesRequest
                         withError:(NSError *)error

{
    NSString *notificationName = [[operations lastObject] isFinished] ? AFIncrementalStoreContextDidSaveRemoteValues : AFIncrementalStoreContextWillSaveRemoteValues;
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:operations forKey:AFIncrementalStoreRequestOperationsKey];
    [userInfo setObject:saveChangesRequest forKey:AFIncrementalStorePersistentStoreRequestKey];
    if (error) {
        [userInfo setObject:error forKey:AFIncrementalStoreFetchSaveRequestErrorKey];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:context userInfo:userInfo];
}

- (void)notifyManagedObjectContext:(NSManagedObjectContext *)context
             aboutRequestOperation:(AFHTTPRequestOperation *)operation
       forNewValuesForObjectWithID:(NSManagedObjectID *)objectID
                         withError:(NSError *)error
{
    NSString *notificationName = [operation isFinished] ? AFIncrementalStoreContextWillFetchNewValuesForObject : AFIncrementalStoreContextDidFetchNewValuesForObject;

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:[NSArray arrayWithObject:operation] forKey:AFIncrementalStoreRequestOperationsKey];
    if (objectID) {
        [userInfo setObject:objectID forKey:AFIncrementalStoreFaultingObjectIDKey];
    }
    if (error) {
        [userInfo setObject:error forKey:AFIncrementalStoreFetchSaveRequestErrorKey];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:context userInfo:userInfo];
}

- (void)notifyManagedObjectContext:(NSManagedObjectContext *)context
             aboutRequestOperation:(AFHTTPRequestOperation *)operation
       forNewValuesForRelationship:(NSRelationshipDescription *)relationship
                   forObjectWithID:(NSManagedObjectID *)objectID
                         withError:(NSError *)error
{
    NSString *notificationName = [operation isFinished] ? AFIncrementalStoreContextWillFetchNewValuesForRelationship : AFIncrementalStoreContextDidFetchNewValuesForRelationship;

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:[NSArray arrayWithObject:operation] forKey:AFIncrementalStoreRequestOperationsKey];
    [userInfo setObject:objectID forKey:AFIncrementalStoreFaultingObjectIDKey];
    [userInfo setObject:relationship forKey:AFIncrementalStoreFaultingRelationshipKey];
    if (error) {
        [userInfo setObject:error forKey:AFIncrementalStoreFetchSaveRequestErrorKey];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:context userInfo:userInfo];
}

#pragma mark -

- (NSManagedObjectContext *)backingManagedObjectContext {
    if (!_backingManagedObjectContext) {
        _backingManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _backingManagedObjectContext.persistentStoreCoordinator = _backingPersistentStoreCoordinator;
        [_backingManagedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        _backingManagedObjectContext.retainsRegisteredObjects = YES;
    }
    
    return _backingManagedObjectContext;
}

- (NSManagedObjectID *)objectIDForEntity:(NSEntityDescription *)entity
                  withResourceIdentifier:(NSString *)resourceIdentifier
{
    if (!resourceIdentifier) {
        return nil;
    }
    
    NSManagedObjectID *objectID = nil;
    NSMutableDictionary *objectIDsByResourceIdentifier = [_registeredObjectIDsByEntityNameAndNestedResourceIdentifier objectForKey:entity.name];
    if (objectIDsByResourceIdentifier) {
        objectID = [objectIDsByResourceIdentifier objectForKey:resourceIdentifier];
    }
        
    if (!objectID) {
        objectID = [self newObjectIDForEntity:entity referenceObject:AFReferenceObjectFromResourceIdentifier(resourceIdentifier)];
    }
    
    NSParameterAssert([objectID.entity.name isEqualToString:entity.name]);
    
    return objectID;
}

- (NSManagedObjectID *)objectIDForBackingObjectForEntity:(NSEntityDescription *)entity
                                  withResourceIdentifier:(NSString *)resourceIdentifier
{
    if (!resourceIdentifier) {
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[entity name]];
    fetchRequest.resultType = NSManagedObjectIDResultType;
    fetchRequest.fetchLimit = 1;
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K = %@", kAFIncrementalStoreResourceIdentifierAttributeName, resourceIdentifier];
    
    __block NSArray *results = nil;
    __block NSError *error = nil;
    
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    [backingContext performBlockAndWait:^{
        results = [backingContext executeFetchRequest:fetchRequest error:&error];
    }];
    
    if (error) {
        NSLog(@"Error: %@", error);
        return nil;
    }
    
    return [results lastObject];
}

- (NSManagedObjectID *)objectIDForBackingObjectForEntity:(NSEntityDescription *)entity
                                  withPrimaryKey:(NSString *)primaryKeyIdentifier
{
    if (!primaryKeyIdentifier) {
        return nil;
    }
    NSString * primaryKeyName=[[entity userInfo] objectForKey:@"primaryKey"];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[entity name]];
    fetchRequest.resultType = NSManagedObjectIDResultType;
    fetchRequest.fetchLimit = 1;
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K = %@", primaryKeyName, primaryKeyIdentifier];
    
    __block NSArray *results = nil;
    __block NSError *error = nil;
    
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    [backingContext performBlockAndWait:^{
        results = [backingContext executeFetchRequest:fetchRequest error:&error];
    }];
    
    if (error) {
        NSLog(@"Error: %@", error);
        return nil;
    }
    
    return [results lastObject];
}

#pragma mark - Esselunga modification
- (void)updateBackingObject:(NSManagedObject *)backingObject
withAttributeAndRelationshipValuesFromManagedObject:(NSManagedObject *)managedObject
{
    NSMutableDictionary *mutableRelationshipValues = [[NSMutableDictionary alloc] init];
    for (NSRelationshipDescription *relationship in [managedObject.entity.relationshipsByName allValues]) {
        id relationshipValue = [managedObject valueForKey:relationship.name];
        if (!relationshipValue) {
            continue;
        }
        
        if ([relationship isToMany]) {
            id mutableBackingRelationshipValue = nil;
            if ([relationship isOrdered]) {
                mutableBackingRelationshipValue = [NSMutableOrderedSet orderedSetWithCapacity:[relationshipValue count]];
            } else {
                mutableBackingRelationshipValue = [NSMutableSet setWithCapacity:[relationshipValue count]];
            }
            
            for (NSManagedObject *relationshipManagedObject in relationshipValue) {
				if (![[relationshipManagedObject objectID] isTemporaryID]) { // nota che le relationship saranno sempre temporary...
					/*NSManagedObjectID *backingRelationshipObjectID = [self objectIDForBackingObjectForEntity:relationship.destinationEntity withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:relationshipManagedObject.objectID])];*/
                    NSEntityDescription * destinationEntity=relationship.destinationEntity;
                    NSString * primaryKeyName=[[destinationEntity userInfo] objectForKey:@"primaryKey"];
                    NSManagedObjectID *backingRelationshipObjectID = [self objectIDForBackingObjectForEntity:destinationEntity
                                                                                              withPrimaryKey:[relationshipManagedObject valueForKey:primaryKeyName]];
					if (backingRelationshipObjectID) {
						NSManagedObject *backingRelationshipObject = [backingObject.managedObjectContext existingObjectWithID:backingRelationshipObjectID error:nil];
						if (backingRelationshipObject) {
							[mutableBackingRelationshipValue addObject:backingRelationshipObject];
						}
					}
				} 
            }
            
            [mutableRelationshipValues setValue:mutableBackingRelationshipValue forKey:relationship.name];
        } else {
			if (![[relationshipValue objectID] isTemporaryID]) { // nota che le relationship saranno sempre temporary...
				/*NSManagedObjectID *backingRelationshipObjectID = [self objectIDForBackingObjectForEntity:relationship.destinationEntity withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:[relationshipValue objectID]])];*/
                NSEntityDescription * destinationEntity=relationship.destinationEntity;
                NSString * primaryKeyName=[[destinationEntity userInfo] objectForKey:@"primaryKey"];
                NSManagedObjectID *backingRelationshipObjectID = [self objectIDForBackingObjectForEntity:destinationEntity
                                                                                          withPrimaryKey:[relationshipValue valueForKey:primaryKeyName]];
				if (backingRelationshipObjectID) {
					NSManagedObject *backingRelationshipObject = [backingObject.managedObjectContext existingObjectWithID:backingRelationshipObjectID error:nil];
                    [mutableRelationshipValues setValue:backingRelationshipObject forKey:relationship.name];
				}
			} 
        }
    }
    
    [backingObject setValuesForKeysWithDictionary:mutableRelationshipValues];
    [backingObject setValuesForKeysWithDictionary:[managedObject dictionaryWithValuesForKeys:[managedObject.entity.attributesByName allKeys]]];
}

#pragma mark -

- (BOOL)insertOrUpdateObjectsFromRepresentations:(id)representationOrArrayOfRepresentations
                                        ofEntity:(NSEntityDescription *)entity
                                    fromResponse:(NSHTTPURLResponse *)response
                                     withContext:(NSManagedObjectContext *)context
                                           error:(NSError *__autoreleasing *)error
                                 completionBlock:(void (^)(NSArray *managedObjects, NSArray *backingObjects))completionBlock
{
    if (!representationOrArrayOfRepresentations) {
        return NO;
    }

    NSParameterAssert([representationOrArrayOfRepresentations isKindOfClass:[NSArray class]] ||
                      [representationOrArrayOfRepresentations isKindOfClass:[NSDictionary class]]);
    
    if ([representationOrArrayOfRepresentations count] == 0) {
        if (completionBlock) {
            completionBlock([NSArray array], [NSArray array]);
        }
        
        return NO;
    }
    
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    NSString *lastModified = [[response allHeaderFields] valueForKey:@"Last-Modified"];
    NSArray *representations = nil;
    if ([representationOrArrayOfRepresentations isKindOfClass:[NSArray class]]) {
        representations = representationOrArrayOfRepresentations;
    } else if ([representationOrArrayOfRepresentations isKindOfClass:[NSDictionary class]]) {
        representations = [NSArray arrayWithObject:representationOrArrayOfRepresentations];
    }

    NSUInteger numberOfRepresentations = [representations count];
    NSMutableArray *mutableManagedObjects = [NSMutableArray arrayWithCapacity:numberOfRepresentations];
    NSMutableArray *mutableBackingObjects = [NSMutableArray arrayWithCapacity:numberOfRepresentations];
    
    for (NSDictionary *representation in representations) {
        NSString *resourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:entity fromResponse:response];
        NSDictionary *attributes = [self.HTTPClient attributesForRepresentation:representation ofEntity:entity fromResponse:response];
        
        __block NSManagedObject *managedObject = nil;
        [context performBlockAndWait:^{
            managedObject = [context existingObjectWithID:[self objectIDForEntity:entity withResourceIdentifier:resourceIdentifier] error:nil];
        }];
        
        [managedObject setValuesForKeysWithDictionary:attributes];
        
        NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:entity withResourceIdentifier:resourceIdentifier];
        __block NSManagedObject *backingObject = nil;
        [backingContext performBlockAndWait:^{
            if (backingObjectID) {
                backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
            } else {
                backingObject = [NSEntityDescription insertNewObjectForEntityForName:entity.name inManagedObjectContext:backingContext];
                [backingObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObject] error:nil];
            }
            [backingObject setValue:resourceIdentifier forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
            [backingObject setValue:lastModified forKey:kAFIncrementalStoreLastModifiedAttributeName];
            [backingObject setValuesForKeysWithDictionary:attributes];
            [backingObject setValue:@"1" forKey:kAFIncrementalStoreAlignedAttributeName];
        }];
        
        if (!backingObjectID) {
            [context insertObject:managedObject];
        }
        
        NSDictionary *relationshipRepresentations = [self.HTTPClient representationsForRelationshipsFromRepresentation:representation ofEntity:entity fromResponse:response];
        for (NSString *relationshipName in relationshipRepresentations) {
            NSRelationshipDescription *relationship = [[entity relationshipsByName] valueForKey:relationshipName];
            id relationshipRepresentation = [relationshipRepresentations objectForKey:relationshipName];
            if (!relationship || (relationship.isOptional && (!relationshipRepresentation || [relationshipRepresentation isEqual:[NSNull null]]))) {
                continue;
            }
                        
            if (!relationshipRepresentation || [relationshipRepresentation isEqual:[NSNull null]] || [relationshipRepresentation count] == 0) {
                [managedObject setValue:nil forKey:relationshipName];
                [backingObject setValue:nil forKey:relationshipName];
                continue;
            }
            
            [self insertOrUpdateObjectsFromRepresentations:relationshipRepresentation ofEntity:relationship.destinationEntity fromResponse:response withContext:context error:error completionBlock:^(NSArray *managedObjects, NSArray *backingObjects) {
                if ([relationship isToMany]) {
                    if ([relationship isOrdered]) {
                        [managedObject setValue:[NSOrderedSet orderedSetWithArray:managedObjects] forKey:relationship.name];
                        [backingObject setValue:[NSOrderedSet orderedSetWithArray:backingObjects] forKey:relationship.name];
                    } else {
                        [managedObject setValue:[NSSet setWithArray:managedObjects] forKey:relationship.name];
                        [backingObject setValue:[NSSet setWithArray:backingObjects] forKey:relationship.name];
                    }
                } else {
                    [managedObject setValue:[managedObjects lastObject] forKey:relationship.name];
                    [backingObject setValue:[backingObjects lastObject] forKey:relationship.name];
                }
            }];
        }
        
        [mutableManagedObjects addObject:managedObject];
        [mutableBackingObjects addObject:backingObject];
    }
    
    if (completionBlock) {
        completionBlock(mutableManagedObjects, mutableBackingObjects);
    }

    return YES;
}

#include <time.h>
#include <xlocale.h>
static NSDate * TTTDateFromISO8601Timestamp(NSString *timestamp) {
    static unsigned int const ISO_8601_MAX_LENGTH = 25;
    
    const char *source = [timestamp cStringUsingEncoding:NSUTF8StringEncoding];
    if (source) {
        char destination[ISO_8601_MAX_LENGTH];
        size_t length = strlen(source);
        
        if (length == 0) {
            return nil;
        }
        
        if (length == 20 && source[length - 1] == 'Z') {
            memcpy(destination, source, length - 1);
            strncpy(destination + length - 1, "+0000\0", 6);
        } else if (length == 25 && source[22] == ':') {
            memcpy(destination, source, 22);
            memcpy(destination + 22, source + 23, 2);
        } else {
            memcpy(destination, source, MIN(length, ISO_8601_MAX_LENGTH - 1));
        }
        
        destination[sizeof(destination) - 1] = NULL;
        
        struct tm time = {
            .tm_isdst = -1,
        };
        
        strptime_l(destination, "%Y-%m-%d %H:%M:%S %z", &time, NULL);
        
        return [NSDate dateWithTimeIntervalSince1970:mktime(&time)];
    }
    return nil;
}

static NSDate * TTTDateFromHTTPTimestamp(NSString *timestamp) {

    if (timestamp) {
        const char *source = [timestamp cStringUsingEncoding:NSUTF8StringEncoding];
            
        struct tm time = {
            .tm_isdst = -1,
        };
        
        strptime_l(source, "%A, %d %b %Y %H:%M:%S %z", &time, NULL);
            
        NSDate * date=[NSDate dateWithTimeIntervalSince1970:mktime(&time)];
        return date;
    }
    return nil;
}

static NSString * TTTISO8601TimestampFromDate(NSDate *date) {
    static NSDateFormatter *_iso8601DateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _iso8601DateFormatter = [[NSDateFormatter alloc] init];
        [_iso8601DateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss z"];
        [_iso8601DateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [_iso8601DateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
        
    });
    
    return [_iso8601DateFormatter stringFromDate:date];
}

-(NSString *)retrieveMinLastModifiedFromEntityName:(NSString *)entityName {
    
    NSError *__autoreleasing * error=nil;
    NSManagedObjectContext * backingContext=self.backingManagedObjectContext;
    NSManagedObjectModel *backingModel = self.backingPersistentStoreCoordinator.managedObjectModel;
	NSFetchRequest *backingFetchRequest = [backingModel fetchRequestFromTemplateWithName:@"FetchEntityUpdatingJournalWithName"
                                                                   substitutionVariables:
                                                                   [NSDictionary dictionaryWithObject:entityName forKey:@"NOME_ENTITY"]];
    backingFetchRequest.resultType = NSDictionaryResultType;
    backingFetchRequest.propertiesToFetch = [NSArray arrayWithObject:[[backingFetchRequest.entity attributesByName] valueForKey:@"lastUpdate"]];
    __block NSArray *results=nil;
    [backingContext performBlockAndWait:^{
        results = [backingContext executeFetchRequest:backingFetchRequest error:error];
    }];

    NSString * returnedString=TTTISO8601TimestampFromDate([[results lastObject] valueForKey:@"lastUpdate"]);
    
    return (returnedString)?(returnedString):TTTISO8601TimestampFromDate([NSDate distantPast]);
    
}

-(NSManagedObject *)retrieveJournalManagedObjectWithEntityName:(NSString *)entityName {
    
    NSError *__autoreleasing * error=nil;
    NSManagedObjectContext * backingContext=self.backingManagedObjectContext;
    NSManagedObjectModel *backingModel = self.backingPersistentStoreCoordinator.managedObjectModel;
	NSFetchRequest *backingFetchRequest = [backingModel fetchRequestFromTemplateWithName:@"FetchEntityUpdatingJournalWithName"
                                                                   substitutionVariables:
                                           [NSDictionary dictionaryWithObject:entityName forKey:@"NOME_ENTITY"]];
    backingFetchRequest.resultType = NSManagedObjectResultType;
    NSArray *results = [backingContext executeFetchRequest:backingFetchRequest error:error];
    
    return [results lastObject];

}

-(void)updateJournalingTableWithResponse:(NSHTTPURLResponse *)response
                           andEntityName:(NSString *)entityName {
    
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    NSString *lastModified = [[response allHeaderFields] valueForKey:@"Last-Modified"];
    [backingContext performBlockAndWait:^{
        if (lastModified) {
            NSManagedObject * journalEntity=[self retrieveJournalManagedObjectWithEntityName:entityName];
            if (!journalEntity) {
                // new entity, create it
                journalEntity=[NSEntityDescription insertNewObjectForEntityForName:@"EntityUpdatingJournal"
                                                            inManagedObjectContext:backingContext];
                [journalEntity setValue:entityName forKey:@"nomeEntity"];
            }
            [journalEntity setValue:TTTDateFromHTTPTimestamp(lastModified) forKey:@"lastUpdate"];
            //NSLog(@"Update Timestamp = %@ for entity = %@\n",lastModified, entityName);
        }
        NSError *__autoreleasing * error=nil;
        AFSaveManagedObjectContextOrThrowInternalConsistencyException(backingContext, error);

    }];
}

- (id)executeFetchRequest:(NSFetchRequest *)fetchRequest
              withContext:(NSManagedObjectContext *)context
                    error:(NSError *__autoreleasing *)error
{
    NSMutableURLRequest *request = [[self.HTTPClient requestForFetchRequest:fetchRequest withContext:context] mutableCopy];
    NSString * minLastModified=[self retrieveMinLastModifiedFromEntityName:fetchRequest.entityName];
    NSLog(@"GET with if-modified-since = %@ for entity Name = %@\n", minLastModified, fetchRequest.entityName);
    if ([request URL]) {
        [request setValue:minLastModified forHTTPHeaderField:@"If-Modified-Since"];
        AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
            [context performBlockAndWait:^{
                id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsOfEntity:fetchRequest.entity fromResponseObject:responseObject];
                
                // caso in cui la risposta incrementale del server è nulla, cioè
                // nessuna modifica da inserire nel DB locale, eseguo un refresh dell'interfaccia
                
                if ([representationOrArrayOfRepresentations count] == 0) {
                    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
                    NSFetchRequest *backingFetchRequest = [fetchRequest copy];
                    backingFetchRequest.entity = [NSEntityDescription entityForName:fetchRequest.entityName inManagedObjectContext:backingContext];
                    backingFetchRequest.resultType = NSDictionaryResultType;
                    backingFetchRequest.propertiesToFetch = [NSArray arrayWithObject:kAFIncrementalStoreResourceIdentifierAttributeName];
                    NSArray *results = [backingContext executeFetchRequest:backingFetchRequest error:error];
                    
                    for (NSString *resourceIdentifier in [results valueForKeyPath:kAFIncrementalStoreResourceIdentifierAttributeName]) {
                        NSManagedObjectID *objectID = [self objectIDForEntity:fetchRequest.entity withResourceIdentifier:resourceIdentifier];
                        NSManagedObject *object = [context objectWithID:objectID];
                        NSManagedObject *parentObject = [context objectWithID:objectID];
                        object.af_resourceIdentifier = resourceIdentifier;
                        object.af_aligned=@"1";
                        [context refreshObject:parentObject mergeChanges:NO];
                    }
                    [backingContext performBlockAndWait:^{
                        AFSaveManagedObjectContextOrThrowInternalConsistencyException(backingContext, error);
                    }];
                    [self notifyManagedObjectContext:context aboutRequestOperation:operation forFetchRequest:fetchRequest fetchedObjectIDs:[results valueForKeyPath:@"objectID"] withError:nil];
                    return;
                }
                NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
                childContext.parentContext = context;
                childContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
                // here, try to update only journaling of root entity
                [self updateJournalingTableWithResponse:operation.response
                                          andEntityName:fetchRequest.entityName];

                [childContext performBlockAndWait:^{
                    [self insertOrUpdateObjectsFromRepresentations:representationOrArrayOfRepresentations ofEntity:fetchRequest.entity fromResponse:operation.response withContext:childContext error:error completionBlock:^(NSArray *managedObjects, NSArray *backingObjects) {
                        NSSet *childObjects = [childContext registeredObjects];
                        AFSaveManagedObjectContextOrThrowInternalConsistencyException(childContext, error);

                        NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
                        [backingContext performBlockAndWait:^{
                            AFSaveManagedObjectContextOrThrowInternalConsistencyException(backingContext, error);
                        }];

                        [context performBlockAndWait:^{
                            for (NSManagedObject *childObject in childObjects) {
                                NSManagedObject *parentObject = [context objectWithID:childObject.objectID];
                                parentObject.af_aligned=@"1";
                                [context refreshObject:parentObject mergeChanges:NO];
                            }
                        }];
                        [self notifyManagedObjectContext:context aboutRequestOperation:operation forFetchRequest:fetchRequest fetchedObjectIDs:[managedObjects valueForKeyPath:@"objectID"] withError:nil];
                    }];
                }];
            }];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Error: %@", error);
            [self notifyManagedObjectContext:context aboutRequestOperation:operation forFetchRequest:fetchRequest fetchedObjectIDs:nil withError:error];
        }];

        [self notifyManagedObjectContext:context aboutRequestOperation:operation forFetchRequest:fetchRequest fetchedObjectIDs:nil withError:nil];
        operation.successCallbackQueue=self->_successRequestQueue;
        operation.failureCallbackQueue=self->_failureRequestQueue;
        [self.HTTPClient enqueueHTTPRequestOperation:operation];
    }
    
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
	NSFetchRequest *backingFetchRequest = [fetchRequest copy];
	backingFetchRequest.entity = [NSEntityDescription entityForName:fetchRequest.entityName inManagedObjectContext:backingContext];

    switch (fetchRequest.resultType) {
        case NSManagedObjectResultType: {
            backingFetchRequest.resultType = NSDictionaryResultType;
            backingFetchRequest.propertiesToFetch = [NSArray arrayWithObject:kAFIncrementalStoreResourceIdentifierAttributeName];
            NSArray *results = [backingContext executeFetchRequest:backingFetchRequest error:error];

            NSMutableArray *mutableObjects = [NSMutableArray arrayWithCapacity:[results count]];
            for (NSString *resourceIdentifier in [results valueForKeyPath:kAFIncrementalStoreResourceIdentifierAttributeName]) {
                NSManagedObjectID *objectID = [self objectIDForEntity:fetchRequest.entity withResourceIdentifier:resourceIdentifier];
                NSManagedObject *object = [context objectWithID:objectID];
                object.af_resourceIdentifier = resourceIdentifier;
                //object.af_aligned=@"0";
                [mutableObjects addObject:object];
            }
            
            return mutableObjects;
        }
        case NSManagedObjectIDResultType: {
            NSArray *backingObjectIDs = [backingContext executeFetchRequest:backingFetchRequest error:error];
            NSMutableArray *managedObjectIDs = [NSMutableArray arrayWithCapacity:[backingObjectIDs count]];
            
            for (NSManagedObjectID *backingObjectID in backingObjectIDs) {
                NSManagedObject *backingObject = [backingContext objectWithID:backingObjectID];
                NSString *resourceID = [backingObject valueForKey:kAFIncrementalStoreResourceIdentifierAttributeName];
                [managedObjectIDs addObject:[self objectIDForEntity:fetchRequest.entity withResourceIdentifier:resourceID]];
            }
            
            return managedObjectIDs;
        }
        case NSDictionaryResultType:
        case NSCountResultType:
            return [backingContext executeFetchRequest:backingFetchRequest error:error];
        default:
            return nil;
    }
}

-(void)saveInsertedObject:(NSManagedObject *)insertedObject
                inContext:(NSManagedObjectContext *)context {
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    NSString *primaryKeyName = [self.HTTPClient localResourceIdentifierForManagedObject:insertedObject];
    NSString *primaryKeyValue = [insertedObject valueForKey:primaryKeyName];

    assert(insertedObject.managedObjectContext==context);
    
    [backingContext performBlockAndWait:^{
        // Roberto UPDATE, prendol'identificativo da un nuovo metodo del protocollo AFIncrementalStoreHTTPClient
        NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[insertedObject entity] withResourceIdentifier:primaryKeyName];
        __block NSManagedObject *backingObject = nil;
        if (backingObjectID) {
            [backingContext performBlockAndWait:^{
                backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
            }];
        }
        if (!backingObject) {
            backingObject = [NSEntityDescription insertNewObjectForEntityForName:insertedObject.entity.name inManagedObjectContext:backingContext];
            [backingObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObject] error:nil];
        }
        [backingObject setValue:primaryKeyValue forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
        [self updateBackingObject:backingObject withAttributeAndRelationshipValuesFromManagedObject:insertedObject];
        [backingContext save:nil];
    }];
    
    [insertedObject willChangeValueForKey:@"objectID"];
    [context obtainPermanentIDsForObjects:[NSArray arrayWithObject:insertedObject] error:nil];
    [insertedObject didChangeValueForKey:@"objectID"];
    
    [context refreshObject:insertedObject mergeChanges:NO];
}

// Roberto ADD
-(void)executePostDeleteWithObjects:(NSNotification *)notification {
    NSArray * deletedObjects=notification.object;
    NSManagedObjectContext * context=[notification.userInfo objectForKey:@"context"];
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    NSString * entityName=nil, * deletedKey;
    NSManagedObjectID * objectID;
    NSEntityDescription * entityDesc;
    for (NSDictionary * dictDeletedObject in deletedObjects) {
        entityName=[dictDeletedObject objectForKey:@"entityName"];
        deletedKey=[dictDeletedObject objectForKey:@"deletedKey"];
        entityDesc=[NSEntityDescription entityForName:entityName inManagedObjectContext:context];
        objectID=[self objectIDForEntity:entityDesc withResourceIdentifier:deletedKey];
        if (objectID) {
            NSManagedObject *backingObject = [backingContext existingObjectWithID:objectID error:nil];
            if (backingObject) {
                [backingContext performBlockAndWait:^{
                    [backingContext deleteObject:backingObject];
                    [backingContext save:nil];
                }];
            }
            [context performBlockAndWait:^{
                NSManagedObject * object=[context objectRegisteredForID:objectID];
                if (object) {
                    [context deleteObject:object];
                }
            }];
        }
    }
}

-(NSDictionary *)retrieveObjectWithIdentifier:(NSString *)primaryKey
                           fromResponseObject:(NSArray *)response {
    for (NSDictionary * responseObject in response) {
        for (NSString * key in responseObject) {
            id value=[responseObject objectForKey:key];
            if ([value isKindOfClass:[NSString class]] &&
                [value isEqualToString:primaryKey]) {
                return responseObject;
            }
        }
    }
    return nil;
}
-(void)postPonedSaveChangeRequest:(NSNotification *)notification {
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    NSDictionary * dictNotif=notification.object;
    NSSaveChangesRequest * saveChangesRequest=[dictNotif objectForKey:@"saveChangeRequest"];
    id responseObject=[dictNotif objectForKey:@"responseObject"];
    AFHTTPRequestOperation * operation=[dictNotif objectForKey:@"operation"];
    NSManagedObjectContext * context=[dictNotif objectForKey:@"context"];
    
        for (NSManagedObject *insertedObject in [saveChangesRequest insertedObjects]) {
        
                id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsOfEntity:[insertedObject entity]  fromResponseObject:responseObject];
                if ([representationOrArrayOfRepresentations isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *representation = (NSDictionary *)representationOrArrayOfRepresentations;
                    
                    NSString *resourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:[insertedObject entity] fromResponse:responseObject];
                    NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[insertedObject entity] withResourceIdentifier:resourceIdentifier];
                    insertedObject.af_resourceIdentifier = resourceIdentifier;
                    [insertedObject setValuesForKeysWithDictionary:[self.HTTPClient attributesForRepresentation:representation ofEntity:insertedObject.entity fromResponse:responseObject]];
                    
                    [backingContext performBlockAndWait:^{
                        __block NSManagedObject *backingObject = nil;
                        if (backingObjectID) {
                            [backingContext performBlockAndWait:^{
                                backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                            }];
                        }
                        
                        if (!backingObject) {
                            backingObject = [NSEntityDescription insertNewObjectForEntityForName:insertedObject.entity.name inManagedObjectContext:backingContext];
                            [backingObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObject] error:nil];
                        }
                        [self updateBackingObject:backingObject withAttributeAndRelationshipValuesFromManagedObject:insertedObject];
                        [backingObject setValue:resourceIdentifier forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
                        backingObject.af_aligned=@"1";
                        [backingContext save:nil];
                    }];
                    
                    [insertedObject willChangeValueForKey:@"objectID"];
                    [context obtainPermanentIDsForObjects:[NSArray arrayWithObject:insertedObject] error:nil];
                    [insertedObject didChangeValueForKey:@"objectID"];
                    
                    insertedObject.af_aligned=@"1";
                    [context refreshObject:insertedObject mergeChanges:NO];
                // FIXME, risposta dal server sempre di tipo array, sono sempre in questo else if
                } else if ([representationOrArrayOfRepresentations isKindOfClass:[NSArray class]]) {
                
                    NSDictionary *representation = (NSDictionary *)[insertedObject dictionaryWithValuesForKeys:[[[insertedObject entity] attributesByName] allKeys]];
                    NSString *resourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:[insertedObject entity] fromResponse:responseObject];
                    NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[insertedObject entity] withResourceIdentifier:resourceIdentifier];
                    insertedObject.af_resourceIdentifier = resourceIdentifier;
                    NSDictionary * object=[self retrieveObjectWithIdentifier:resourceIdentifier fromResponseObject:responseObject];
                    NSDate * createdDate=TTTDateFromISO8601Timestamp([object valueForKey:@"created"]);
                    NSDate * modifiedDate=TTTDateFromISO8601Timestamp([object valueForKey:@"modified"]);
                    if (createdDate) {
                        [insertedObject setValue:createdDate forKey:@"created"];
                    }
                    if (modifiedDate) {
                        [insertedObject setValue:modifiedDate forKey:@"modified"];
                    }
                    [backingContext performBlockAndWait:^{
                        NSManagedObject *backingObject = nil;
                        NSError * error=nil;
                        BOOL saved=FALSE;
                        
                        if (backingObjectID) {
                            backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                        }

                        if (!backingObject) {
                            backingObject = [NSEntityDescription insertNewObjectForEntityForName:insertedObject.entity.name inManagedObjectContext:backingContext];
                            [backingObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObject] error:nil];
                        }
                        [self updateBackingObject:backingObject withAttributeAndRelationshipValuesFromManagedObject:insertedObject];
                        [backingObject setValue:resourceIdentifier forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
                        backingObject.af_aligned=@"1";
                        [backingObject setValue:[NSNumber numberWithInt:1] forKey:@"version"];
                        saved=[backingContext save:&error];
                        if (!saved) {
                            NSLog(@"Backing Context not saved = %@\n", error);
                        }
                    }];
                    
                    [insertedObject willChangeValueForKey:@"objectID"];
                    [context obtainPermanentIDsForObjects:[NSArray arrayWithObject:insertedObject] error:nil];
                    [insertedObject didChangeValueForKey:@"objectID"];
                    
                    insertedObject.af_aligned=@"1";
                    [insertedObject setValue:[NSNumber numberWithInt:1] forKey:@"version"];
                    [context refreshObject:insertedObject mergeChanges:NO];
  
                }
        }
    
        for (NSManagedObject *updatedObject in [saveChangesRequest updatedObjects]) {
            NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[updatedObject entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:updatedObject.objectID])];
                id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsOfEntity:[updatedObject entity]  fromResponseObject:responseObject];
                if ([representationOrArrayOfRepresentations isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *representation = (NSDictionary *)representationOrArrayOfRepresentations;
                    [updatedObject setValuesForKeysWithDictionary:[self.HTTPClient attributesForRepresentation:representation ofEntity:updatedObject.entity fromResponse:responseObject]];
                    
                    [backingContext performBlockAndWait:^{
                        NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                        [self updateBackingObject:backingObject withAttributeAndRelationshipValuesFromManagedObject:updatedObject];
                        backingObject.af_aligned=@"1";
                        NSNumber * version=[backingObject valueForKey:@"version"];
                        [backingObject setValue:[NSNumber numberWithInt:([version intValue] + 1)] forKey:@"version"];
                        [backingContext save:nil];
                    }];
                    updatedObject.af_aligned=@"1";
                    NSNumber * version=[updatedObject valueForKey:@"version"];
                    [updatedObject setValue:[NSNumber numberWithInt:([version intValue] + 1)] forKey:@"version"];
                    [context refreshObject:updatedObject mergeChanges:NO];
                // FIXME, risposta dal server sempre di tipo array, sono sempre in questo else if
                } else if ([representationOrArrayOfRepresentations isKindOfClass:[NSArray class]]) {
                    NSDictionary * object=[self retrieveObjectWithIdentifier:updatedObject.af_resourceIdentifier fromResponseObject:responseObject];
                    NSDate * modifiedDate=TTTDateFromISO8601Timestamp([object valueForKey:@"modified"]);
                    if (modifiedDate) {
                        [updatedObject setValue:modifiedDate forKey:@"modified"];
                    }
                    [backingContext performBlockAndWait:^{
                        BOOL saved=FALSE;
                        NSError * error;
                        
                        NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                        [self updateBackingObject:backingObject withAttributeAndRelationshipValuesFromManagedObject:updatedObject];
                        backingObject.af_aligned=@"1";
                        NSNumber * version=[backingObject valueForKey:@"version"];
                        [backingObject setValue:[NSNumber numberWithInt:([version intValue] + 1)] forKey:@"version"];
                        saved=[backingContext save:&error];
                        if (!saved) {
                            NSLog(@"Error during saving backing context = %@", error);
                        }
                    }];
                    updatedObject.af_aligned=@"1";
                    NSNumber * version=[updatedObject valueForKey:@"version"];
                    [updatedObject setValue:[NSNumber numberWithInt:([version intValue] + 1)] forKey:@"version"];
                    [context refreshObject:updatedObject mergeChanges:NO];
                }
            
            
        }
    
        for (NSManagedObject *deletedObject in [saveChangesRequest deletedObjects]) {
            NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[deletedObject entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:deletedObject.objectID])];
            
                [backingContext performBlockAndWait:^{
                    if (backingObjectID) {
                        NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                        if (backingObject) {
                            [backingContext deleteObject:backingObject];
                            [backingContext save:nil];
                        }
                    }
                }];
        }
    
    [self notifyManagedObjectContext:context aboutRequestOperations:[NSArray arrayWithObject:operation] forSaveChangesRequest:saveChangesRequest withError:nil];
}

- (id)executeSaveChangesRequest:(NSSaveChangesRequest *)saveChangesRequest
                    withContext:(NSManagedObjectContext *)context
                          error:(NSError *__autoreleasing *)error
{
    NSMutableArray *mutableOperations = [NSMutableArray array];
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    
    [self.HTTPClient beginIncrementalStoreTransaction]; // Roberto ADD
    
    if ([self.HTTPClient respondsToSelector:@selector(requestForInsertedObject:)]) {
        //__block NSUInteger onlyOnePermanentIDs=FALSE;
        for (NSManagedObject *insertedObject in [saveChangesRequest insertedObjects]) {
            NSURLRequest *request = [self.HTTPClient requestForInsertedObject:insertedObject];
            if (!request) {
                //[self saveInsertedObject:insertedObject inContext:context];
                continue;
            }
            
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsOfEntity:[insertedObject entity]  fromResponseObject:responseObject];
                if ([representationOrArrayOfRepresentations isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *representation = (NSDictionary *)representationOrArrayOfRepresentations;

                    NSString *resourceIdentifier = [self.HTTPClient resourceIdentifierForRepresentation:representation ofEntity:[insertedObject entity] fromResponse:operation.response];
                    NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[insertedObject entity] withResourceIdentifier:resourceIdentifier];
                    insertedObject.af_resourceIdentifier = resourceIdentifier;
                    [insertedObject setValuesForKeysWithDictionary:[self.HTTPClient attributesForRepresentation:representation ofEntity:insertedObject.entity fromResponse:operation.response]];
                    

                    [backingContext performBlockAndWait:^{
                        __block NSManagedObject *backingObject = nil;
                        if (backingObjectID) {
                            [backingContext performBlockAndWait:^{
                                backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                            }];
                        }

                        if (!backingObject) {
                            backingObject = [NSEntityDescription insertNewObjectForEntityForName:insertedObject.entity.name inManagedObjectContext:backingContext];
                            [backingObject.managedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:backingObject] error:nil];
                        }

                        [backingObject setValue:resourceIdentifier forKey:kAFIncrementalStoreResourceIdentifierAttributeName];
                        [backingObject setValue:@"1" forKey:kAFIncrementalStoreAlignedAttributeName];
                        [self updateBackingObject:backingObject withAttributeAndRelationshipValuesFromManagedObject:insertedObject];
                        [backingContext save:nil];
                    }];
                    
                    [insertedObject willChangeValueForKey:@"objectID"];
                    [context obtainPermanentIDsForObjects:[NSArray arrayWithObject:insertedObject] error:nil];
                    [insertedObject didChangeValueForKey:@"objectID"];
                    
                    insertedObject.af_aligned=@"1";
                    [context refreshObject:insertedObject mergeChanges:NO];
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Insert Error: %@", error);

                // nota, qui forziamo il save dell'oggetto anche se non è stato allineato sul server
                // però notifichiamo all'utente che qualcosa non è andato a buon fine
                // FIXME, da filtrare con i valori di error codes dal server
                //[self saveInsertedObject:insertedObject inContext:context];
                [self notifyManagedObjectContext:context aboutRequestOperations:[NSArray arrayWithObject:operation] forSaveChangesRequest:saveChangesRequest withError:error];

            }];
            operation.successCallbackQueue=self->_successRequestQueue;
            operation.failureCallbackQueue=self->_failureRequestQueue;
            [mutableOperations addObject:operation];
        }
    }
    
    if ([self.HTTPClient respondsToSelector:@selector(requestForUpdatedObject:)]) {
        for (NSManagedObject *updatedObject in [saveChangesRequest updatedObjects]) {
            NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[updatedObject entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:updatedObject.objectID])];

            NSURLRequest *request = [self.HTTPClient requestForUpdatedObject:updatedObject];
            if (!request) {
                /*[backingContext performBlockAndWait:^{
                    NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                    [self updateBackingObject:backingObject withAttributeAndRelationshipValuesFromManagedObject:updatedObject];
                    [backingContext save:nil];
                }];
                */
                continue;
            }
            
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsOfEntity:[updatedObject entity]  fromResponseObject:responseObject];
                if ([representationOrArrayOfRepresentations isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *representation = (NSDictionary *)representationOrArrayOfRepresentations;
                    [updatedObject setValuesForKeysWithDictionary:[self.HTTPClient attributesForRepresentation:representation ofEntity:updatedObject.entity fromResponse:operation.response]];

                    [backingContext performBlockAndWait:^{
                        NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                        [self updateBackingObject:backingObject withAttributeAndRelationshipValuesFromManagedObject:updatedObject];
                        backingObject.af_aligned=@"1";
                        [backingContext save:nil];
                    }];
                    updatedObject.af_aligned=@"1";
                    [context refreshObject:updatedObject mergeChanges:NO];
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Update Error: %@", error);
                [context refreshObject:updatedObject mergeChanges:NO];
                [self notifyManagedObjectContext:context aboutRequestOperations:[NSArray arrayWithObject:operation] forSaveChangesRequest:saveChangesRequest withError:error];

            }];
            operation.successCallbackQueue=self->_successRequestQueue;
            operation.failureCallbackQueue=self->_failureRequestQueue;
            [mutableOperations addObject:operation];
        }
    }
    
    if ([self.HTTPClient respondsToSelector:@selector(requestForDeletedObject:)]) {
        for (NSManagedObject *deletedObject in [saveChangesRequest deletedObjects]) {
            NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[deletedObject entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:deletedObject.objectID])];

            NSURLRequest *request = [self.HTTPClient requestForDeletedObject:deletedObject];
            if (!request) {
            /*
                [backingContext performBlockAndWait:^{
                    NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                    [backingContext deleteObject:backingObject];
                    [backingContext save:nil];
                }];
            */
                continue;
            }
            
            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                [backingContext performBlockAndWait:^{
                    NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                    if (backingObject) {
                        [backingContext deleteObject:backingObject];
                        [backingContext save:nil];
                    }
                }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Delete Error: %@", error);
                // N.B: forziamo la cancellazione dell'oggetto anche nel backing store,
                // segnalando all'utente che la comunicazione con il server non va a buon fine
                // FIXME; bisogna filtrare l'esecuzione sulla base degli error code della risposta
                [backingContext performBlockAndWait:^{
                    NSManagedObject *backingObject = [backingContext existingObjectWithID:backingObjectID error:nil];
                    if (backingObject) {
                        [backingContext deleteObject:backingObject];
                        [backingContext save:nil];
                    }
                }];
                [self notifyManagedObjectContext:context aboutRequestOperations:[NSArray arrayWithObject:operation] forSaveChangesRequest:saveChangesRequest withError:error];
            }];
            operation.successCallbackQueue=self->_successRequestQueue;
            operation.failureCallbackQueue=self->_failureRequestQueue;
            [mutableOperations addObject:operation];
        }
    }
    
    // NSManagedObjectContext removes object references from an NSSaveChangesRequest as each object is saved, so create a copy of the original in order to send useful information in AFIncrementalStoreContextDidSaveRemoteValues notification.
    NSSaveChangesRequest *saveChangesRequestCopy = [[NSSaveChangesRequest alloc] initWithInsertedObjects:[saveChangesRequest.insertedObjects copy] updatedObjects:[saveChangesRequest.updatedObjects copy] deletedObjects:[saveChangesRequest.deletedObjects copy] lockedObjects:[saveChangesRequest.lockedObjects copy]];
    
    [self notifyManagedObjectContext:context aboutRequestOperations:mutableOperations forSaveChangesRequest:saveChangesRequestCopy withError:nil];

    [self.HTTPClient enqueueBatchOfHTTPRequestOperations:mutableOperations progressBlock:nil completionBlock:^(NSArray *operations) {
        [self notifyManagedObjectContext:context aboutRequestOperations:operations forSaveChangesRequest:saveChangesRequestCopy withError:nil];
    }];
    
    [self.HTTPClient endIncrementalStoreTransaction]; // Roberto ADD
    
    return [NSArray array];
}

#pragma mark - NSIncrementalStore

/* aggiunge al modello Core Data dell'applicativo una serie di parametri necessari
 * per la comunicazione con mobile sync server */
+(NSManagedObjectModel *)addHiddenModelToBackingModel:(NSManagedObjectModel *)model {
    for (NSEntityDescription *entity in model.entities) {
        // Don't add properties for sub-entities, as they already exist in the super-entity
        if ([entity superentity]) {
            continue;
        }
        
        NSAttributeDescription *resourceIdentifierProperty = [[NSAttributeDescription alloc] init];
        [resourceIdentifierProperty setName:kAFIncrementalStoreResourceIdentifierAttributeName];
        [resourceIdentifierProperty setAttributeType:NSStringAttributeType];
        [resourceIdentifierProperty setIndexed:YES];
        
        NSAttributeDescription *lastModifiedProperty = [[NSAttributeDescription alloc] init];
        [lastModifiedProperty setName:kAFIncrementalStoreLastModifiedAttributeName];
        [lastModifiedProperty setAttributeType:NSStringAttributeType];
        [lastModifiedProperty setIndexed:NO];
        
        // Roberto ADD
        NSAttributeDescription *alignedProperty = [[NSAttributeDescription alloc] init];
        [alignedProperty setName:kAFIncrementalStoreAlignedAttributeName];
        [alignedProperty setAttributeType:NSStringAttributeType];
        [alignedProperty setIndexed:NO];
        
        NSArray * arrayHiddenProperties=[NSArray arrayWithObjects:resourceIdentifierProperty, lastModifiedProperty, alignedProperty,
                                                                  nil];
        
        [entity setProperties:[entity.properties arrayByAddingObjectsFromArray:arrayHiddenProperties]];
        // Roberto END
        
    }
    
    // here add hidden entity used for GET incremental journaling
    NSEntityDescription * entityUpdatingJournal=[NSEntityDescription new];
    
    NSAttributeDescription *lastUpdateProperty = [[NSAttributeDescription alloc] init];
    [lastUpdateProperty setName:kAFIncrementalStoreEntityJournalingLastUpdateAttributeName];
    [lastUpdateProperty setAttributeType:NSDateAttributeType];
    [lastUpdateProperty setIndexed:NO];
    
    NSAttributeDescription *nomeEntityProperty = [[NSAttributeDescription alloc] init];
    [nomeEntityProperty setName:kAFIncrementalStoreEntityJournalingNomeEntityAttributeName];
    [nomeEntityProperty setAttributeType:NSStringAttributeType];
    [nomeEntityProperty setIndexed:NO];
    
    entityUpdatingJournal.name=@"EntityUpdatingJournal";
    entityUpdatingJournal.properties=@[lastUpdateProperty, nomeEntityProperty];
    
    [model setEntities:[model.entities arrayByAddingObject:entityUpdatingJournal]];
    
    // here add fetch request template for EntityUpdatingJournal hidden entity description
    NSFetchRequest * fetchRequest=[[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entityUpdatingJournal];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"nomeEntity == $NOME_ENTITY"]];
    [model setFetchRequestTemplate:fetchRequest forName:@"FetchEntityUpdatingJournalWithName"];
    
    return model;
}

+(NSManagedObjectModel *)addHiddenModelToApplicationModel:(NSManagedObjectModel *)model {

    for (NSEntityDescription *entity in model.entities) {
        // Don't add properties for sub-entities, as they already exist in the super-entity
        if ([entity superentity]) {
            continue;
        }
        
        NSAttributeDescription *versionProperty = [[NSAttributeDescription alloc] init];
        [versionProperty setName:kAFIncrementalStoreVersionAttributeName];
        [versionProperty setAttributeType:NSInteger64AttributeType];
        [versionProperty setIndexed:NO];
        
        NSAttributeDescription *createdDateProperty = [[NSAttributeDescription alloc] init];
        [createdDateProperty setName:kAFIncrementalStoreCreatedAttributeName];
        [createdDateProperty setAttributeType:NSDateAttributeType];
        [createdDateProperty setIndexed:NO];
        
        NSAttributeDescription *modifiedDateProperty = [[NSAttributeDescription alloc] init];
        [modifiedDateProperty setName:kAFIncrementalStoreModifiedAttributeName];
        [modifiedDateProperty setAttributeType:NSDateAttributeType];
        [modifiedDateProperty setIndexed:NO];
        
        NSAttributeDescription *businessIdProperty = [[NSAttributeDescription alloc] init];
        [businessIdProperty setName:kAFIncrementalStoreBusinessIdAttributeName];
        [businessIdProperty setAttributeType:NSStringAttributeType];
        [businessIdProperty setIndexed:NO];
        
        NSArray * arrayHiddenProperties=[NSArray arrayWithObjects:versionProperty, createdDateProperty,
                                                                  modifiedDateProperty, businessIdProperty, nil];
        
        [entity setProperties:[entity.properties arrayByAddingObjectsFromArray:arrayHiddenProperties]];
        // Roberto END
        
    }
    
    return model;
}

#pragma optional methods
+ (id)identifierForNewStoreAtURL:(NSURL *)storeURL {

    CFUUIDRef UUID = CFUUIDCreate(NULL);
    NSString *resourceIdentifier = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, UUID);
    CFRelease(UUID);
    return resourceIdentifier;
    
}

#pragma mark required methods
- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
    if (!_backingObjectIDByObjectID) {
        NSMutableDictionary *mutableMetadata = [NSMutableDictionary dictionary];
        [mutableMetadata setValue:[AFIncrementalStore identifierForNewStoreAtURL:nil] forKey:NSStoreUUIDKey];
        [mutableMetadata setValue:NSStringFromClass([self class]) forKey:NSStoreTypeKey];
        [self setMetadata:mutableMetadata];
        
        _backingObjectIDByObjectID = [[NSCache alloc] init];
        _registeredObjectIDsByEntityNameAndNestedResourceIdentifier = [[NSMutableDictionary alloc] init];
        
        NSManagedObjectModel *originalModel = [self.persistentStoreCoordinator.managedObjectModel copy];
        NSManagedObjectModel * model=[[self class] addHiddenModelToBackingModel:originalModel];
        _backingPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        _successRequestQueue=dispatch_queue_create("ESLSuccessRESTQueue", DISPATCH_QUEUE_SERIAL);
        _failureRequestQueue=dispatch_queue_create("ESLFailureRESTQueue", DISPATCH_QUEUE_SERIAL);
        return YES;
    } else {
        return NO;
    }
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError **)error {
    NSMutableArray *mutablePermanentIDs = [NSMutableArray arrayWithCapacity:[array count]];
    for (NSManagedObject *managedObject in array) {
        NSManagedObjectID *managedObjectID = managedObject.objectID;
        if ([managedObjectID isTemporaryID] && managedObject.af_resourceIdentifier) {
            NSManagedObjectID *objectID = [self objectIDForEntity:managedObject.entity withResourceIdentifier:managedObject.af_resourceIdentifier];
            [mutablePermanentIDs addObject:objectID];
        } else {
            [mutablePermanentIDs addObject:managedObjectID];
        }
    }
    
    return mutablePermanentIDs;
}

- (id)executeRequest:(NSPersistentStoreRequest *)persistentStoreRequest
         withContext:(NSManagedObjectContext *)context
               error:(NSError *__autoreleasing *)error
{
    if (persistentStoreRequest.requestType == NSFetchRequestType) {
        return [self executeFetchRequest:(NSFetchRequest *)persistentStoreRequest withContext:context error:error];
    } else if (persistentStoreRequest.requestType == NSSaveRequestType) {
        return [self executeSaveChangesRequest:(NSSaveChangesRequest *)persistentStoreRequest withContext:context error:error];
    } else {
        NSMutableDictionary *mutableUserInfo = [NSMutableDictionary dictionary];
        [mutableUserInfo setValue:[NSString stringWithFormat:NSLocalizedString(@"Unsupported NSFetchRequestResultType, %d", nil), persistentStoreRequest.requestType] forKey:NSLocalizedDescriptionKey];
        if (error) {
            *error = [[NSError alloc] initWithDomain:AFNetworkingErrorDomain code:0 userInfo:mutableUserInfo];
        }
        
        return nil;
    }
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID
                                         withContext:(NSManagedObjectContext *)context
                                               error:(NSError *__autoreleasing *)error
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[[objectID entity] name]];
    fetchRequest.resultType = NSDictionaryResultType;
    fetchRequest.fetchLimit = 1;
    fetchRequest.includesSubentities = NO;
    
    NSArray *attributes = [[[NSEntityDescription entityForName:fetchRequest.entityName inManagedObjectContext:context] attributesByName] allValues];
    NSArray *intransientAttributes = [attributes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isTransient == NO"]];
    fetchRequest.propertiesToFetch = [[intransientAttributes valueForKeyPath:@"name"] arrayByAddingObject:kAFIncrementalStoreLastModifiedAttributeName];
    
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"%K = %@", kAFIncrementalStoreResourceIdentifierAttributeName, AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
    
    __block NSArray *results;
    NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
    [backingContext performBlockAndWait:^{
        results = [backingContext executeFetchRequest:fetchRequest error:error];
    }];
    NSDictionary *attributeValues = [results lastObject] ?: [NSDictionary dictionary];
#if 0
    NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:attributeValues version:CFAbsoluteTimeGetCurrent()];
#else
    NSNumber * version=[attributeValues objectForKey:@"version"];
    int64_t versionNumber=([version isKindOfClass:[NSNull class]])?1:[version intValue];
    NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:attributeValues
                                                                            version:versionNumber];
#endif

    //NSLog(@"All'interno di newValuesForObjectWithID con values = %@\n", attributeValues);
    if ([self.HTTPClient respondsToSelector:@selector(shouldFetchRemoteAttributeValuesForObjectWithID:inManagedObjectContext:)] && [self.HTTPClient shouldFetchRemoteAttributeValuesForObjectWithID:objectID inManagedObjectContext:context]) {
        if (attributeValues) {
            NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            childContext.parentContext = context;
            childContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
            
            NSMutableURLRequest *request = [self.HTTPClient requestWithMethod:@"GET" pathForObjectWithID:objectID withContext:context];
            NSString *lastModified = [attributeValues objectForKey:kAFIncrementalStoreLastModifiedAttributeName];
            if (lastModified) {
                [request setValue:lastModified forHTTPHeaderField:@"Last-Modified"];
            }
            
            if ([request URL]) {
                if ([attributeValues valueForKey:kAFIncrementalStoreLastModifiedAttributeName]) {
                    [request setValue:[[attributeValues valueForKey:kAFIncrementalStoreLastModifiedAttributeName] description] forHTTPHeaderField:@"If-Modified-Since"];
                }

                AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, NSDictionary *representation) {
                    [childContext performBlock:^{
                        NSManagedObject *managedObject = [childContext existingObjectWithID:objectID error:error];

                        NSMutableDictionary *mutableAttributeValues = [attributeValues mutableCopy];
                        [mutableAttributeValues addEntriesFromDictionary:[self.HTTPClient attributesForRepresentation:representation ofEntity:managedObject.entity fromResponse:operation.response]];
                        [mutableAttributeValues removeObjectForKey:kAFIncrementalStoreLastModifiedAttributeName];
                        [managedObject setValuesForKeysWithDictionary:mutableAttributeValues];

                        NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[objectID entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
                        NSManagedObject *backingObject = [[self backingManagedObjectContext] existingObjectWithID:backingObjectID error:nil];
                        [backingObject setValuesForKeysWithDictionary:mutableAttributeValues];

                        NSString *lastModified = [[operation.response allHeaderFields] valueForKey:@"Last-Modified"];
                        if (lastModified) {
                            [backingObject setValue:lastModified forKey:kAFIncrementalStoreLastModifiedAttributeName];
                        }

                        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:childContext queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                            [context mergeChangesFromContextDidSaveNotification:note];
                        }];

                        [childContext performBlockAndWait:^{
                            AFSaveManagedObjectContextOrThrowInternalConsistencyException(childContext, error);

                            NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
                            [backingContext performBlockAndWait:^{
                                AFSaveManagedObjectContextOrThrowInternalConsistencyException(backingContext, error);
                            }];
                        }];
                        
                        [[NSNotificationCenter defaultCenter] removeObserver:observer];

                        [self notifyManagedObjectContext:context aboutRequestOperation:operation forNewValuesForObjectWithID:objectID withError:nil];
                    }];

                } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    NSLog(@"Error: %@, %@", operation, error);
                    [self notifyManagedObjectContext:context aboutRequestOperation:operation forNewValuesForObjectWithID:objectID withError:error];
                }];

                [self notifyManagedObjectContext:context aboutRequestOperation:operation forNewValuesForObjectWithID:objectID withError:nil];
                [self.HTTPClient enqueueHTTPRequestOperation:operation];
            }
        }
    }
    
    return node;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship
              forObjectWithID:(NSManagedObjectID *)objectID
                  withContext:(NSManagedObjectContext *)context
                        error:(NSError *__autoreleasing *)error
{
    if ([self.HTTPClient respondsToSelector:@selector(shouldFetchRemoteValuesForRelationship:forObjectWithID:inManagedObjectContext:)] && [self.HTTPClient shouldFetchRemoteValuesForRelationship:relationship forObjectWithID:objectID inManagedObjectContext:context]) {
        NSURLRequest *request = [self.HTTPClient requestWithMethod:@"GET" pathForRelationship:relationship forObjectWithID:objectID withContext:context];
        
        if ([request URL] && ![[context existingObjectWithID:objectID error:nil] hasChanges]) {
            NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            childContext.parentContext = context;
            childContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

            AFHTTPRequestOperation *operation = [self.HTTPClient HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
                [childContext performBlock:^{
                    id representationOrArrayOfRepresentations = [self.HTTPClient representationOrArrayOfRepresentationsOfEntity:relationship.destinationEntity fromResponseObject:responseObject];
                
                    [self insertOrUpdateObjectsFromRepresentations:representationOrArrayOfRepresentations ofEntity:relationship.destinationEntity fromResponse:operation.response withContext:childContext error:error completionBlock:^(NSArray *managedObjects, NSArray *backingObjects) {
                        NSManagedObject *managedObject = [childContext objectWithID:objectID];
                        
						NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[objectID entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
                        NSManagedObject *backingObject = (backingObjectID == nil) ? nil : [[self backingManagedObjectContext] existingObjectWithID:backingObjectID error:nil];

                        if ([relationship isToMany]) {
                            if ([relationship isOrdered]) {
                                [managedObject setValue:[NSOrderedSet orderedSetWithArray:managedObjects] forKey:relationship.name];
                                [backingObject setValue:[NSOrderedSet orderedSetWithArray:backingObjects] forKey:relationship.name];
                            } else {
                                [managedObject setValue:[NSSet setWithArray:managedObjects] forKey:relationship.name];
                                [backingObject setValue:[NSSet setWithArray:backingObjects] forKey:relationship.name];
                            }
                        } else {
                            [managedObject setValue:[managedObjects lastObject] forKey:relationship.name];
                            [backingObject setValue:[backingObjects lastObject] forKey:relationship.name];
                        }
                        
                        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:childContext queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                            [context mergeChangesFromContextDidSaveNotification:note];
                        }];

                        [childContext performBlockAndWait:^{
                            AFSaveManagedObjectContextOrThrowInternalConsistencyException(childContext, error);

                            NSManagedObjectContext *backingContext = [self backingManagedObjectContext];
                            [backingContext performBlockAndWait:^{
                                AFSaveManagedObjectContextOrThrowInternalConsistencyException(backingContext, error);
                            }];
                        }];

                        [[NSNotificationCenter defaultCenter] removeObserver:observer];

                        [self notifyManagedObjectContext:context aboutRequestOperation:operation forNewValuesForRelationship:relationship forObjectWithID:objectID withError:nil];
                    }];
                }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Error: %@, %@", operation, error);
                [self notifyManagedObjectContext:context aboutRequestOperation:operation forNewValuesForRelationship:relationship forObjectWithID:objectID withError:nil];
            }];

            [self.HTTPClient enqueueHTTPRequestOperation:operation];
        }
    }
    
    NSManagedObjectID *backingObjectID = [self objectIDForBackingObjectForEntity:[objectID entity] withResourceIdentifier:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
    NSManagedObject *backingObject = (backingObjectID == nil) ? nil : [[self backingManagedObjectContext] existingObjectWithID:backingObjectID error:nil];
    
    if (backingObject) {
        id backingRelationshipObject = [backingObject valueForKeyPath:relationship.name];
        if ([relationship isToMany]) {
            NSMutableArray *mutableObjects = [NSMutableArray arrayWithCapacity:[backingRelationshipObject count]];
            for (NSString *resourceIdentifier in [backingRelationshipObject valueForKeyPath:kAFIncrementalStoreResourceIdentifierAttributeName]) {
                NSManagedObjectID *objectID = [self objectIDForEntity:relationship.destinationEntity withResourceIdentifier:resourceIdentifier];
                [mutableObjects addObject:objectID];
            }
                        
            return mutableObjects;            
        } else {
            NSString *resourceIdentifier = [backingRelationshipObject valueForKeyPath:kAFIncrementalStoreResourceIdentifierAttributeName];
            NSManagedObjectID *objectID = [self objectIDForEntity:relationship.destinationEntity withResourceIdentifier:resourceIdentifier];
            
            return objectID ?: [NSNull null];
        }
    } else {
        if ([relationship isToMany]) {
            return [NSArray array];
        } else {
            return [NSNull null];
        }
    }
}

- (void)managedObjectContextDidRegisterObjectsWithIDs:(NSArray *)objectIDs {
    [super managedObjectContextDidRegisterObjectsWithIDs:objectIDs];
    
    for (NSManagedObjectID *objectID in objectIDs) {
        id referenceObject = [self referenceObjectForObjectID:objectID];
        if (!referenceObject) {
            continue;
        }
        
        NSMutableDictionary *objectIDsByResourceIdentifier = [_registeredObjectIDsByEntityNameAndNestedResourceIdentifier objectForKey:objectID.entity.name] ?: [NSMutableDictionary dictionary];
        [objectIDsByResourceIdentifier setObject:objectID forKey:AFResourceIdentifierFromReferenceObject(referenceObject)];
        
        [_registeredObjectIDsByEntityNameAndNestedResourceIdentifier setObject:objectIDsByResourceIdentifier forKey:objectID.entity.name];
    }
}

- (void)managedObjectContextDidUnregisterObjectsWithIDs:(NSArray *)objectIDs {
    [super managedObjectContextDidUnregisterObjectsWithIDs:objectIDs];
    
    for (NSManagedObjectID *objectID in objectIDs) {
        [[_registeredObjectIDsByEntityNameAndNestedResourceIdentifier objectForKey:objectID.entity.name] removeObjectForKey:AFResourceIdentifierFromReferenceObject([self referenceObjectForObjectID:objectID])];
    }
}

@end
