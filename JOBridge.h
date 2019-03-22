//
//  JOBridge.h
//  JOBridge
//
//  Created by Wei on 2018/9/12.
//  Copyright © 2018年 Wei. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JODefs.h"


@interface JOBridge : NSObject
@property (atomic, strong, class) JSContext *jsContext;//class语义Xcode8以后才支持
@property (atomic, assign, class) BOOL isDebug;//class语义Xcode8以后才支持

+ (void)bridge;
+ (void)evaluateScript:(NSString *)script;


//MARK:Plugin支持
+ (void)registerPlugin:(id)obj;
//needTransfor:YES则需要将js调用转换为._oc_('selector name', param)的形式，并通过通用Bridge来调用
+ (void)addObject:(id)obj forKey:(NSString *)key needTransform:(BOOL)trans;
+ (id)objectForKey:(NSString *)key;

@end
