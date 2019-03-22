//
//  JOClass.h
//  JOBridge
//
//  Created by Wei on 2018/9/12.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JODefs.h"

JOEXTERN JOINLINE JSValue *JOSearchJsMethod(Class class, NSString *selectorName);
JOEXTERN void JOClassParser(JSValue *className, JSValue *properties, JSValue *classMethods, JSValue *metaClassMethods);

#endif
