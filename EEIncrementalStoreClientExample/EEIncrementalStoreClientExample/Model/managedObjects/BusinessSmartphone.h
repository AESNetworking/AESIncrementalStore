//
//  BusinessSmartphone.h
//  Pods
//
//  Created by roberto avanzi on 03/09/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Employee;

@interface BusinessSmartphone : NSManagedObject

@property (nonatomic, retain) NSString * businesssmartphone_id;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSString * dataAcquisto;
@property (nonatomic, retain) NSString * modello;
@property (nonatomic, retain) NSDate * modified;
@property (nonatomic, retain) NSString * tipo;
@property (nonatomic, retain) NSNumber * version;
@property (nonatomic, retain) Employee *employee;

@end
