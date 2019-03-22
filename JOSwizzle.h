//
//  JOSwizzle.h
//  JOBridge
//
//  Created by Wei on 2018/9/21.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JODefs.h"

JOEXTERN void JOGlobalCSwizzle(void);
JOEXTERN void JOGlobalSwizzle(void);
JOEXTERN void JOGlobalBlockGetParams(void);
JOEXTERN JOINLINE void JOConstructReturnValue(__autoreleasing JSValue *ret, char type);

#endif
