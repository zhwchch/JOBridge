//
//  JOTools.m
//  JOBridge
//
//  Created by Wei on 2018/9/12.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import "JOTools.h"
#import <os/lock.h>
#import <pthread.h>

JOINLINE NSString* trim(NSString *string) {
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
JOINLINE NSString* replace(NSString *source, NSString *string1, NSString *string2) {
    return [source stringByReplacingOccurrencesOfString:string1 withString:string2];
}
JOINLINE BOOL contains(NSString *source, NSString *string) {
    return [source rangeOfString:string].location == NSNotFound;
}
JOINLINE void retain() {
//    asm volatile("stp    x29, x30, [sp, #-0x10]!");
//    asm volatile("mov    x29, sp");
//    asm volatile("bl _objc_retain");
//    asm volatile("mov    sp, x29");
//    asm volatile("ldp    x29, x30, [sp], #0x10");
    asm volatile("b _objc_retain");
}
JOINLINE void release() {
//    asm volatile("stp    x29, x30, [sp, #-0x10]!");
//    asm volatile("mov    x29, sp");
//    asm volatile("bl _objc_release");
//    asm volatile("mov    sp, x29");
//    asm volatile("ldp    x29, x30, [sp], #0x10");
    asm volatile("b _objc_release");
}
JOINLINE void initLock(void **lock) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    if (@available(iOS 10.0, *)) {
        *lock = malloc(sizeof(os_unfair_lock));
        (*(os_unfair_lock_t *)lock)->_os_unfair_lock_opaque = 0;
    }
#else
    pthread_mutex_init(lock, NULL);
#endif
}

JOINLINE void lock(void *lock) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    if (@available(iOS 10.0, *)) {
        os_unfair_lock_lock((os_unfair_lock_t)lock);
    }
#else
    pthread_mutex_lock(&lock);
#endif
}

JOINLINE void unlock(void *lock) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    if (@available(iOS 10.0, *)) {
        os_unfair_lock_unlock((os_unfair_lock_t)lock);
    }
#else
    pthread_mutex_unlock(&lock);
#endif
}

JOINLINE BOOL isNull(__unsafe_unretained id obj) {
    if (!obj || obj == NSNull.null) return YES;
    return NO;
}
JOINLINE void pc(__unsafe_unretained id o, NSString *pre) {
    void *p = JOTOPTR o;
    JOLog(@"%@ %@ %p：%@",pre, o, p, [o valueForKey:@"retainCount"]);
}

JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSInteger loc, NSInteger len) {
    if (loc < 0 || len <= 0 || loc + len < 0 || loc + len > source.length) return source;
    return [source substringWithRange:(NSRange){loc, len}];
}
JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSInteger loc, BOOL isTo) {
    if (loc < 0 || loc > source.length) return source;
    return isTo ? [source substringToIndex:loc] : [source substringFromIndex:loc];
}

JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSString *loc, NSInteger len) {
    NSRange range = [source rangeOfString:loc];
    if (range.location == NSNotFound || len <= 0 || range.location + len > source.length) return source;
    return [source substringWithRange:(NSRange){range.location, len}];
}

JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSString *loc_s, BOOL isTo) {
    NSRange range = [source rangeOfString:loc_s];
    if (range.location == NSNotFound) return source;
    return isTo ? [source substringToIndex:range.location]
                : [source substringFromIndex:range.location];
}

JOVERLOAD JOINLINE NSString* JOSubString(NSString *source, NSString *loc_s1, NSString *loc_s2) {
    NSInteger loc1 = [source rangeOfString:loc_s1].location;
    if (loc1 == NSNotFound) loc1 = 0;
    NSInteger loc2 = [source rangeOfString:loc_s2].location;
    if (loc2 == NSNotFound) loc2 = source.length;
    return [source substringWithRange:(NSRange){loc1, loc2 - loc1}];
}

JOToolStruct JOTools = {trim, replace, contains, retain, release, pc, initLock, lock, unlock, isNull};

#endif
