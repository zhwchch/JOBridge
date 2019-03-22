//
//  JOInvocation.h
//  JOBridge
//
//  Created by Wei on 2018/12/6.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import <Foundation/Foundation.h>
#import "JODefs.h"

JOEXTERN JOINLINE NSInvocation *JOGetInvocation(__unsafe_unretained id obj, SEL sel);
JOEXTERN JOINLINE void JOStoreInvocation(__unsafe_unretained id obj, SEL sel, __unsafe_unretained NSInvocation *invoke, BOOL isStore);

#endif
