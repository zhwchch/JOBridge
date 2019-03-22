//
//  JOObject.h
//  JOBridge
//
//  Created by Wei on 2018/9/21.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#import "JODefs.h"

typedef struct JOBOXABLE CGRect JOBoxCGRect;
typedef struct JOBOXABLE CGPoint JOBoxCGPoint;
typedef struct JOBOXABLE CGSize JOBoxCGSize;
typedef struct JOBOXABLE _NSRange JOBoxNSRange;
typedef struct JOBOXABLE UIEdgeInsets JOBoxUIEdgeInsets;
typedef struct JOBOXABLE UIOffset JOBoxUIOffset;
typedef struct JOBOXABLE CGAffineTransform JOBoxCGAffineTransform;

typedef union JOBOXABLE JODoubleWord6  {

    CGRect rect;
    JOBoxCGRect boxRect;
    
    CGPoint point;
    JOBoxCGPoint boxPoint;
    
    CGSize size;
    JOBoxCGSize boxSize;
    
    NSRange range;
    JOBoxNSRange boxRange;
    
    UIEdgeInsets edgeInsets;
    JOBoxUIEdgeInsets boxEdgeInsets;
    
    CGAffineTransform affineTransform;
    JOBoxCGAffineTransform boxAffineTransform;
    
    UIOffset offset;
    JOBoxUIOffset boxOffset;
    
    double d[6];
    
    NSInteger i[6];
    
} JODoubleWord6;

typedef union JODoubleWord {
    void *ptr;
    SEL *sel;
    __unsafe_unretained id obj;
    int64_t int64;
    uint64_t uint64;
} JODoubleWord;


#pragma mark - Class Define

@interface JOBaseObj : NSObject
@end

JONOSUBCLASS @interface JOPointerObj : JOBaseObj
@property (nonatomic, assign) void *ptr;
@end
JONOSUBCLASS @interface JOWeakObj : JOBaseObj
@property (nonatomic, weak) id obj;
@end

JONOSUBCLASS @interface JOSelObj : JOBaseObj
@property (nonatomic, assign) SEL sel;
@end

JONOSUBCLASS @interface JOObj : JOBaseObj
@property (nonatomic, strong) id obj;
@end


#pragma mark - Maker & Unmaker

//make会新建一个对象来封装数据
JOEXTERN JOINLINE JOPointerObj* JOMakePointerObj(void *p);
JOEXTERN JOINLINE JOWeakObj* JOMakeWeakObj(__unsafe_unretained id obj);
JOEXTERN JOINLINE JOSelObj* JOMakeSelObj(SEL sel);
JOEXTERN JOINLINE JOObj* JOMakeObj(__unsafe_unretained id obj);
//get在有可复用对象的时直接使用复用对象，否则新建一个对象来装载数据
JOEXTERN JOINLINE JOObj* JOGetObj(__unsafe_unretained id obj);
    
    
    
//如果是JOObj返回被封装对象，否则返回原对象
JOEXTERN JOINLINE JODoubleWord JOUnmakeObj(__unsafe_unretained id obj);
//如果是JOObj或者JOWeakObj返回被封装对象，否则返回原对象
JOEXTERN JOINLINE JODoubleWord JOUnmakeWeakOrObj(__unsafe_unretained id obj);
//如果是JOPointerObj或者JOSelObj返回指针，否则NULL
JOEXTERN JOINLINE JODoubleWord JOUnmakePointerOrSelObj(__unsafe_unretained id obj);
//4种封装对象返回被封装的数据，否则返回原对象
JOEXTERN JOINLINE JODoubleWord JOUnmakeAnyObj(__unsafe_unretained id obj);

#endif
