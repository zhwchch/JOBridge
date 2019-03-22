//
//  JOTools.h
//  JOBridge
//
//  Created by Wei on 2018/9/12.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import <Foundation/Foundation.h>
#import "JODefs.h"


typedef struct JOToolStruct {
    NSString* (*trim)(NSString *string);
    NSString* (*replace)(NSString *source, NSString *string1, NSString *string2);
    BOOL (*contains)(NSString *source, NSString *string);
    
    void (*retain)(__unsafe_unretained id obj);
    void (*release)(__unsafe_unretained id obj);
    void (*pc)(__unsafe_unretained id o, NSString *pre);
    
    void (*initLock)(void **lock);
    void (*lock)(void *lock);
    void (*unlock)(void *lock);
    
    BOOL (*isNull)(__unsafe_unretained id obj);
} JOToolStruct;


JOEXTERN JOToolStruct JOTools;
//OC是个半动态的语言，所以函数重载不是很好使，将就着用吧
JOEXTERN JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSInteger loc, NSInteger len);
JOEXTERN JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSInteger loc, BOOL isTo);
JOEXTERN JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSString *loc_s, NSInteger len);
JOEXTERN JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSString *loc_s, BOOL isTo);
JOEXTERN JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSString *loc_s1, NSString *loc_s2);


#endif
