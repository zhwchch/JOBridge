//
//  JOPluginBase.h
//  JOBridge
//
//  Created by Wei on 2019/1/21.
//  Copyright © 2019 Wei. All rights reserved.
//

#if __arm64__

#import <Foundation/Foundation.h>
#import "JODefs.h"

@interface JOPluginBase : NSObject
//以下方法供子类直接调用
//JOBridge初始化前注册自己为插件，JOBridge初始化时调用initPlugin
+ (void)registerPlugin;
//调用JOBridge的addObject:forKey:needTransform方法注册JS关键字和对应的对象，可以在initPlugin初始化完成后调用
+ (void)registerObject:(id)obj name:(NSString *)name needTransform:(BOOL)needTransform;


//以下方法子类可以重写
+ (void)initPlugin;//JOBridge初始化会回调该方法，其负责插件具体内容的初始化，不要调用父类的该方法
+ (NSMutableDictionary *)pluginStore;//如果需要改变存储容器需要重写本方法，不要调用父类的该方法
@end

#endif
