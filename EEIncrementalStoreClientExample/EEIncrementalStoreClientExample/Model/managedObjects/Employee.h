//
//  Employee.h
//  Pods
//
//  Created by Roberto Avanzi on 28/08/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class BusinessSmartphone, BusinessTablet, Department;

@interface Employee : NSManagedObject

@property (nonatomic, retain) NSString * cognome;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSDate * dataAssunzione;
@property (nonatomic, retain) NSNumber * dipendente;
@property (nonatomic, retain) NSString * employee_id;
@property (nonatomic, retain) NSNumber * livello;
@property (nonatomic, retain) NSDate * modified;
@property (nonatomic, retain) NSString * nome;
@property (nonatomic, retain) NSNumber * version;
@property (nonatomic, retain) NSSet *departments;
@property (nonatomic, retain) NSSet *smartphones;
@property (nonatomic, retain) NSSet *tablets;
@end

@interface Employee (CoreDataGeneratedAccessors)

- (void)addDepartmentsObject:(Department *)value;
- (void)removeDepartmentsObject:(Department *)value;
- (void)addDepartments:(NSSet *)values;
- (void)removeDepartments:(NSSet *)values;

- (void)addSmartphonesObject:(BusinessSmartphone *)value;
- (void)removeSmartphonesObject:(BusinessSmartphone *)value;
- (void)addSmartphones:(NSSet *)values;
- (void)removeSmartphones:(NSSet *)values;

- (void)addTabletsObject:(BusinessTablet *)value;
- (void)removeTabletsObject:(BusinessTablet *)value;
- (void)addTablets:(NSSet *)values;
- (void)removeTablets:(NSSet *)values;

@end
