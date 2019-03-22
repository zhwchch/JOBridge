//
//  JOInvocation.m
//  JOBridge
//
//  Created by Wei on 2018/12/6.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import "JOInvocation.h"
#import <objc/runtime.h>
#import <os/lock.h>
#import <pthread.h>
#import "JOTools.h"

static NSMutableDictionary *_JOInvocationCache = nil;
static NSMutableDictionary *_JOSignatureCache = nil;
static void *_JOInvocationLock;


JOLOADER(115) void JOInvocationInit() {
    _JOInvocationCache = [NSMutableDictionary dictionary];
    _JOSignatureCache = [NSMutableDictionary dictionary];
    JOTools.initLock((void *)&_JOInvocationLock);
}


/** Signature和Invocation分开存储，如果缓存中有对应的NSInvocation则取出复用，复用期间移除缓存，复用完后再添加缓存。
 也就是同一时刻NSInvocation只能被一个调用使用，如果异步或者并发使用同一个NSInvocation，可能会出问题，所以这时候
 就新建一个NSInvocation返回。
 NSMethodSignature则不太一样，NSMethodSignature只读的，不用像NSInvocation一样设置参数，所以单独存储并复用。
 */
JOINLINE NSInvocation *JOGetInvocation(__unsafe_unretained id obj, SEL sel) {
    if (!obj || !sel) return nil;
    Class class = object_getClass(obj);
    JOTools.lock(_JOInvocationLock);
    
    //class可以直接作为key，而selector则转成NSNumbero后作为key，由于可以利用Tagged Pointer机制，比构建字符串快很多
    NSMutableDictionary *selectors = _JOInvocationCache[(id<NSCopying>)class];
    if (!selectors) {
        selectors = [NSMutableDictionary dictionary];
        _JOInvocationCache[(id<NSCopying>)class] = selectors;
    }
    
    NSNumber *selKey = @((NSUInteger)(void *)sel);
    NSInvocation *invoke = selectors[selKey];
    if (invoke) {
        selectors[selKey] = nil;
    } else {
        NSMethodSignature *sign = _JOSignatureCache[selKey];
        if (!sign && [obj respondsToSelector:sel]) {
            sign = [obj methodSignatureForSelector:sel];
            _JOSignatureCache[selKey] = sign;
        }
        if (sign) {
            invoke = [NSInvocation invocationWithMethodSignature:sign];
        }
    }
    JOTools.unlock(_JOInvocationLock);
    
    return invoke;
}

JOINLINE void JOStoreInvocation(__unsafe_unretained id obj, SEL sel, __unsafe_unretained NSInvocation *invoke, BOOL isStore) {
    if (!isStore || !obj || !sel || !invoke) return;
    Class class = object_getClass(obj);
    NSNumber *selKey = @((NSUInteger)(void *)sel);
    
    JOTools.lock(_JOInvocationLock);
    _JOInvocationCache[class][selKey] = invoke;
    JOTools.unlock(_JOInvocationLock);
}

#endif
