//
//  JOCFunction.m
//  JOBridge
//
//  Created by Wei on 2018/10/31.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import "JOCFunction.h"
#import "JOObject.h"
#import <objc/runtime.h>
#import "JOSwizzle.h"
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "JOBridge.h"


static NSMutableDictionary *_JOCFunctions;

JOINLINE void *JOGetCFunction(id obj, SEL cmd) {
    JOPointerObj *p = [[obj pluginStore] objectForKey:NSStringFromSelector(cmd)];
    return p.ptr;
}

CGContextRef __nullable JOCGBitmapContextCreate( void * __nullable data,
                                                size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow,
                                                CGColorSpaceRef cg_nullable space, uint32_t bitmapInfo) __attribute__((optnone)) {
    uint32_t p;
    asm volatile("add x9, x29, #0xd0");
    asm volatile("ldr x10, [x9]");
    asm volatile("str x10, %0":"=m"(p));
    return CGBitmapContextCreate(data, width, height, bitsPerComponent, bytesPerRow, space, p);
}

CGImageRef __nullable JOCGImageMaskCreate(size_t width, size_t height,
                                          size_t bitsPerComponent, size_t bitsPerPixel, size_t bytesPerRow,
                                          CGDataProviderRef cg_nullable provider, const CGFloat * __nullable decode,
                                          bool shouldInterpolate) __attribute__((optnone)) {
    CGFloat *p;
    bool p1;
    asm volatile("add x9, x29, #0xd0");
    asm volatile("ldr x10, [x9]");
    asm volatile("str x10, %0":"=m"(p));
    
    asm volatile("ldr x10, [x9, #0x8]");
    asm volatile("str x10, %0":"=m"(p1));
    
    return CGImageMaskCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, provider, p, p1);
}

@implementation JOCFunction

+ (void)load {
    [self registerPlugin];
}

+ (NSMutableDictionary *)pluginStore {
    if (!_JOCFunctions) {
        _JOCFunctions = [NSMutableDictionary dictionary];
    }
    return _JOCFunctions;
}

/*
 本函数做的事情是，将C方法实现映射到一个OC的类method，并给以对应签名，这样就可以通过调用OC的method去调用C函数。这样做的工作量就转变成
 对现有的C方法进行签名，并关联C函数，这个既可以手工完成，也可以通过脚本甚至bffi来完成，可以大幅减少工作量。
 这里我将方法添加到OC类中，主要是为了复用JOBridge中NSInvocation可以很好的将JS的传参解析并传递过来。当然我们也可以在JOBridge中JS对
 ynative的调用特殊处理，直接到_cFunctions寻找函数入口地址，不过这样的话就必须得手动传参，写入寄存器，实现起来比较麻烦，所以目前先用简单
 做法。
 */
+ (void)mapCFunction:(NSString *)name type:(NSString *)type imp:(void *)imp {
    if (name.length <= 0 || !imp || ![self pluginStore]) return;
    
    NSRange range = [type rangeOfString:@"@:"];
    if (range.length <= 0) return;
    
    if (JOBridge.isDebug) {
        printf("JOMapCFunction(%s,@\"%s\");\n", name.UTF8String, type.UTF8String);
    }
    //有参数默认实现为JOGlobalCSwizzle，没有参数就不用解析参数，直接调用即可
    if ([type substringFromIndex:range.location + range.length].length > 0) {
        [[self pluginStore] setValue:JOMakePointerObj(imp) forKey:name];
        class_addMethod(object_getClass([self class]), NSSelectorFromString(name), (IMP)JOGlobalCSwizzle, [type UTF8String]);
    } else {
        class_addMethod(object_getClass([self class]), NSSelectorFromString(name), (IMP)imp, [type UTF8String]);
    }
}


//MARK: 注册具体的方法
+ (void)initPlugin {
    /*  1、JOGlobalCSwizzle最多支持6个整型参数和8个浮点参数，一些特殊结构结构体算多个参数：
        1.1、结构体全是同种浮点数，且个数不大于4个，且剩余浮点寄存器不小于4个，比如：CGRect算4个浮点参数，CGSize，CGPoint算2个浮点参数；CGAffineTransform存储在栈上则算一个整型指针。
        1.2、结构体不是同种类型，但总长度小于16Byte（要计算对齐），此种算一个或两个整型寄存器
     
        2、当参数较多时可以参考JOCGBitmapContextCreate临时解决方案。0xd0大小固定，是JOGlobalCSwizzle中sp增长的长度0xb0 + 两个
        (x29,x30)0x20，然后手动从栈上获取参数，注意对齐。
     */
    [self addGCD];
    [self addFundation];
    [self addUIKit];
    [self addCGImage];
    [self addCGBitmapContext];
    [self addCGRect];
    [self addCGPath];
    [self addCGColor];
    [self addCGContext];
    [self addCGAffineTransform];
    [self addCoreFundation];
    [self addMath];

    [self registerObject:JOMakeObj([self class]) name:@"JC" needTransform:YES];
}


+ (void)addCoreFundation {
    
    JOMapCFunction(CFAbsoluteTimeGetCurrent, JOSignReturn(CFAbsoluteTime));

    JOMapCFunction(CFArrayCreateMutable, JOSigns(CFMutableArrayRef, CFAllocatorRef, CFIndex, const CFArrayCallBacks *));
    JOMapCFunction(CFArrayAppendValue, JOSigns(void, CFMutableArrayRef, const void *));
    JOMapCFunction(CFRelease, JOSigns(void, CFTypeRef));
    JOMapCFunction(CFRetain, JOSigns(void, CFTypeRef));
    
    JOMapCFunction(CFAbsoluteTimeGetCurrent,@"d@:");
    JOMapCFunction(CFArrayCreateMutable,@"^{__CFArray=}@:^{__CFAllocator=}qr^{?=q^?^?^?^?}");
    JOMapCFunction(CFArrayAppendValue,@"v@:^{__CFArray=}r^v");
    JOMapCFunction(CFRelease,@"v@:^v");
    JOMapCFunction(CFRetain,@"v@:^v");
}

+ (void)addFundation {
    
    JOMapCFunction(NSMakeRange, JOSigns(NSRange, NSUInteger, NSUInteger));
}


+ (void)addUIKit  {
    
//    JOMapCFunction(UIImageJPEGRepresentation, JOSigns(NSData *, UIImage *, CGFloat));
//    JOMapCFunction(UIImagePNGRepresentation, JOSigns(NSData *, UIImage *));
//    JOMapCFunction(UIEdgeInsetsMake, JOSigns(UIEdgeInsets, CGFloat, CGFloat, CGFloat, CGFloat));
//
//    JOMapCFunction(UIGraphicsBeginImageContext, JOSigns(void, CGSize));
//    JOMapCFunction(UIGraphicsBeginImageContextWithOptions, JOSigns(void, CGSize, BOOL, CGFloat));
//    JOMapCFunction(UIGraphicsGetImageFromCurrentImageContext, JOSignReturn(id));
//    JOMapCFunction(UIGraphicsEndImageContext, JOSignReturn(void));
//    JOMapCFunction(UIGraphicsGetCurrentContext, JOSignReturn(CGContextRef));
//    JOMapCFunction(UIGraphicsPushContext, JOSigns(void, CGContextRef));
//    JOMapCFunction(UIGraphicsPopContext, JOSignReturn(CGContextRef));
//    JOMapCFunction(UIRectFillUsingBlendMode, JOSigns(void, CGRect, CGBlendMode));
//    JOMapCFunction(UIRectFill, JOSigns(void, CGRect));
//    JOMapCFunction(UIRectFrameUsingBlendMode, JOSigns(void, CGRect, CGBlendMode));
//    JOMapCFunction(UIRectFrame, JOSigns(void, CGRect));
//    JOMapCFunction(UIRectClip, JOSigns(void, CGRect));
    
    
    JOMapCFunction(UIImageJPEGRepresentation,@"@@:@d");
    JOMapCFunction(UIImagePNGRepresentation,@"@@:@");
    JOMapCFunction(UIEdgeInsetsMake,@"{UIEdgeInsets=dddd}@:dddd");
    JOMapCFunction(UIGraphicsBeginImageContext,@"v@:{CGSize=dd}");
    JOMapCFunction(UIGraphicsBeginImageContextWithOptions,@"v@:{CGSize=dd}Bd");
    JOMapCFunction(UIGraphicsGetImageFromCurrentImageContext,@"@@:");
    JOMapCFunction(UIGraphicsEndImageContext,@"v@:");
    JOMapCFunction(UIGraphicsGetCurrentContext,@"^{CGContext=}@:");
    JOMapCFunction(UIGraphicsPushContext,@"v@:^{CGContext=}");
    JOMapCFunction(UIGraphicsPopContext,@"^{CGContext=}@:");
    JOMapCFunction(UIRectFillUsingBlendMode,@"v@:{CGRect={CGPoint=dd}{CGSize=dd}}i");
    JOMapCFunction(UIRectFill,@"v@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(UIRectFrameUsingBlendMode,@"v@:{CGRect={CGPoint=dd}{CGSize=dd}}i");
    JOMapCFunction(UIRectFrame,@"v@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(UIRectClip,@"v@:{CGRect={CGPoint=dd}{CGSize=dd}}");
}

+ (void)addGCD {
    
//    JOMapCFunction(dispatch_async, JOSigns(void, dispatch_queue_t, dispatch_block_t));
//    JOMapCFunction(dispatch_get_main_queue, JOSignReturn(dispatch_queue_main_t));
//    JOMapCFunction(dispatch_time, JOSigns(dispatch_time_t, dispatch_time_t, int64_t));
//    JOMapCFunction(dispatch_after, JOSigns(void, dispatch_time_t, dispatch_queue_t, dispatch_block_t));
//    JOMapCFunction(dispatch_sync, JOSigns(void, dispatch_queue_t, dispatch_block_t));
//    JOMapCFunction(dispatch_get_global_queue, JOSigns(dispatch_queue_global_t, long, unsigned long));
//    JOMapCFunction(dispatch_source_create, JOSigns(dispatch_source_t, dispatch_source_type_t, uintptr_t, unsigned long, dispatch_queue_t));
//    JOMapCFunction(dispatch_apply, JOSigns(long, size_t, dispatch_queue_t, void (^)(size_t)));
//    JOMapCFunction(dispatch_source_set_timer, JOSigns(void, dispatch_source_t, dispatch_time_t, uint64_t, uint64_t));
//    JOMapCFunction(dispatch_source_set_event_handler, JOSigns(void, dispatch_source_t, dispatch_block_t));
//    JOMapCFunction(dispatch_source_cancel, JOSigns(void, dispatch_object_t));
//    JOMapCFunction(dispatch_resume, JOSigns(void, dispatch_object_t));
//    JOMapCFunction(dispatch_walltime, JOSigns(dispatch_time_t, const struct timespec *, int64_t));
//    JOMapCFunction(dispatch_barrier_async, JOSigns(void, dispatch_queue_t, dispatch_block_t));
//    JOMapCFunction(dispatch_barrier_sync, JOSigns(void, dispatch_queue_t, dispatch_block_t));
//    JOMapCFunction(dispatch_queue_create, JOSigns(dispatch_queue_t, const char *, dispatch_queue_attr_t));
//    JOMapCFunction(dispatch_group_create, JOSignReturn(dispatch_group_t));
//    JOMapCFunction(dispatch_group_async, JOSigns(void, dispatch_group_t, dispatch_queue_t, dispatch_block_t));
//    JOMapCFunction(dispatch_group_wait, JOSigns(long, dispatch_group_t, dispatch_time_t));
//    JOMapCFunction(dispatch_group_notify, JOSigns(long, dispatch_group_t, dispatch_queue_t, dispatch_block_t));
//    JOMapCFunction(dispatch_group_enter, JOSigns(void, dispatch_group_t));
//    JOMapCFunction(dispatch_group_leave, JOSigns(void, dispatch_group_t));
//    JOMapCFunction(dispatch_semaphore_create, JOSigns(dispatch_semaphore_t, long));
//    JOMapCFunction(dispatch_semaphore_wait, JOSigns(long, dispatch_semaphore_t, dispatch_time_t));
//    JOMapCFunction(dispatch_semaphore_signal, JOSigns(long, dispatch_semaphore_t));
//
    JOMapCFunction(dispatch_async,@"v@:@@?");
    JOMapCFunction(dispatch_get_main_queue,@"@@:");
    JOMapCFunction(dispatch_time,@"Q@:Qq");
    JOMapCFunction(dispatch_after,@"v@:Q@@?");
    JOMapCFunction(dispatch_sync,@"v@:@@?");
    JOMapCFunction(dispatch_get_global_queue,@"@@:qQ");
    JOMapCFunction(dispatch_source_create,@"@@:^{dispatch_source_type_s=}QQ@");
    JOMapCFunction(dispatch_apply,@"q@:Q@@?");
    JOMapCFunction(dispatch_source_set_timer,@"v@:@QQQ");
    JOMapCFunction(dispatch_source_set_event_handler,@"v@:@@?");
    JOMapCFunction(dispatch_source_cancel,@"v@:@");
    JOMapCFunction(dispatch_resume,@"v@:@");
    JOMapCFunction(dispatch_walltime,@"Q@:r^{timespec=qq}q");
    JOMapCFunction(dispatch_barrier_async,@"v@:@@?");
    JOMapCFunction(dispatch_barrier_sync,@"v@:@@?");
    JOMapCFunction(dispatch_queue_create,@"@@:r*@");
    JOMapCFunction(dispatch_group_create,@"@@:");
    JOMapCFunction(dispatch_group_async,@"v@:@@@?");
    JOMapCFunction(dispatch_group_wait,@"q@:@Q");
    JOMapCFunction(dispatch_group_notify,@"q@:@@@?");
    JOMapCFunction(dispatch_group_enter,@"v@:@");
    JOMapCFunction(dispatch_group_leave,@"v@:@");
    JOMapCFunction(dispatch_semaphore_create,@"@@:q");
    JOMapCFunction(dispatch_semaphore_wait,@"q@:@Q");
    JOMapCFunction(dispatch_semaphore_signal,@"q@:@");
}

+ (void)addCGColor {
//    JOMapCFunction(CGColorCreate, JOSigns(CGColorRef, CGColorSpaceRef, const CGFloat *));
//    JOMapCFunction(CGColorEqualToColor, JOSigns(bool, CGColorRef, CGColorRef));
//    JOMapCFunction(CGColorGetNumberOfComponents, JOSigns(size_t, CGColorRef));
//    JOMapCFunction(CGColorGetComponents, JOSigns(const CGFloat *, CGColorRef));
//    JOMapCFunction(CGColorGetAlpha, JOSigns(CGFloat, CGColorRef));
//    JOMapCFunction(CGColorGetColorSpace, JOSigns(CGColorSpaceRef, CGColorRef));
//    JOMapCFunction(CGColorGetPattern, JOSigns(CGPatternRef, CGColorRef));
//    JOMapCFunction(CGColorSpaceCreateDeviceGray, JOSignReturn(CGColorSpaceRef));
//    JOMapCFunction(CGColorSpaceCreateDeviceRGB, JOSignReturn(CGColorSpaceRef));
//    JOMapCFunction(CGColorSpaceCreateDeviceCMYK, JOSignReturn(CGColorSpaceRef));
//    JOMapCFunction(CGColorSpaceCreatePattern, JOSigns(CGColorSpaceRef, CGColorSpaceRef));
//    JOMapCFunction(CGColorCreateWithPattern, JOSigns(CGColorRef, CGColorSpaceRef, CGPatternRef, const CGFloat *));
//    JOMapCFunction(CGColorCreateCopy, JOSigns(CGColorRef, CGColorRef));
//    JOMapCFunction(CGColorCreateCopyWithAlpha, JOSigns(CGColorRef, CGColorRef, CGFloat));
    
    JOMapCFunction(CGColorCreate,@"^{CGColor=}@:^{CGColorSpace=}r^d");
    JOMapCFunction(CGColorEqualToColor,@"B@:^{CGColor=}^{CGColor=}");
    JOMapCFunction(CGColorGetNumberOfComponents,@"Q@:^{CGColor=}");
    JOMapCFunction(CGColorGetComponents,@"r^d@:^{CGColor=}");
    JOMapCFunction(CGColorGetAlpha,@"d@:^{CGColor=}");
    JOMapCFunction(CGColorGetColorSpace,@"^{CGColorSpace=}@:^{CGColor=}");
    JOMapCFunction(CGColorGetPattern,@"^{CGPattern=}@:^{CGColor=}");
    JOMapCFunction(CGColorSpaceCreateDeviceGray,@"^{CGColorSpace=}@:");
    JOMapCFunction(CGColorSpaceCreateDeviceRGB,@"^{CGColorSpace=}@:");
    JOMapCFunction(CGColorSpaceCreateDeviceCMYK,@"^{CGColorSpace=}@:");
    JOMapCFunction(CGColorSpaceCreatePattern,@"^{CGColorSpace=}@:^{CGColorSpace=}");
    JOMapCFunction(CGColorCreateWithPattern,@"^{CGColor=}@:^{CGColorSpace=}^{CGPattern=}r^d");
    JOMapCFunction(CGColorCreateCopy,@"^{CGColor=}@:^{CGColor=}");
    JOMapCFunction(CGColorCreateCopyWithAlpha,@"^{CGColor=}@:^{CGColor=}d");
}

+ (void)addCGBitmapContext {
//    JOMapCFunction(CGBitmapContextCreate, JOSigns(CGContextRef, void *, size_t, size_t, size_t, size_t, CGColorSpaceRef, uint32_t));
    [self mapCFunction:@"CGBitmapContextCreate" type:JOSigns(CGContextRef, void *, size_t, size_t, size_t, size_t, CGColorSpaceRef, uint32_t) imp:(IMP)JOCGBitmapContextCreate];

//    JOMapCFunction(CGBitmapContextCreateImage, JOSigns(CGImageRef, CGContextRef));
//    JOMapCFunction(CGBitmapContextGetData, JOSigns(void *, CGContextRef));
//    JOMapCFunction(CGBitmapContextGetWidth, JOSigns(size_t, CGContextRef));
//    JOMapCFunction(CGBitmapContextGetHeight, JOSigns(size_t, CGContextRef));
//    JOMapCFunction(CGBitmapContextGetBitsPerComponent, JOSigns(size_t, CGContextRef));
//    JOMapCFunction(CGBitmapContextGetBitsPerPixel, JOSigns(size_t, CGContextRef));
//    JOMapCFunction(CGBitmapContextGetBytesPerRow, JOSigns(size_t, CGContextRef));
//    JOMapCFunction(CGBitmapContextCreateImage, JOSigns(CGImageRef, CGContextRef));
  
    
    JOMapCFunction(CGBitmapContextCreateImage,@"^{CGImage=}@:^{CGContext=}");
    JOMapCFunction(CGBitmapContextGetData,@"^v@:^{CGContext=}");
    JOMapCFunction(CGBitmapContextGetWidth,@"Q@:^{CGContext=}");
    JOMapCFunction(CGBitmapContextGetHeight,@"Q@:^{CGContext=}");
    JOMapCFunction(CGBitmapContextGetBitsPerComponent,@"Q@:^{CGContext=}");
    JOMapCFunction(CGBitmapContextGetBitsPerPixel,@"Q@:^{CGContext=}");
    JOMapCFunction(CGBitmapContextGetBytesPerRow,@"Q@:^{CGContext=}");
    JOMapCFunction(CGBitmapContextCreateImage,@"^{CGImage=}@:^{CGContext=}");
}

+ (void)addCGContext {
    
//    JOMapCFunction(CGContextSaveGState, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextRestoreGState, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextScaleCTM, JOSigns(void, CGContextRef, CGFloat, CGFloat));
//    JOMapCFunction(CGContextTranslateCTM, JOSigns(void, CGContextRef, CGFloat, CGFloat));
//    JOMapCFunction(CGContextRotateCTM, JOSigns(void, CGContextRef, CGFloat));
//    JOMapCFunction(CGContextConcatCTM, JOSigns(void, CGContextRef, CGAffineTransform));
//    JOMapCFunction(CGContextGetCTM, JOSigns(CGAffineTransform, CGContextRef));
//    JOMapCFunction(CGContextSetLineWidth, JOSigns(void, CGContextRef, CGFloat));
//    JOMapCFunction(CGContextSetLineCap, JOSigns(void, CGContextRef, CGLineCap));
//    JOMapCFunction(CGContextSetLineJoin, JOSigns(void, CGContextRef, CGLineJoin));
//    JOMapCFunction(CGContextSetMiterLimit, JOSigns(void, CGContextRef, CGFloat));
//    JOMapCFunction(CGContextSetLineDash, JOSigns(void, CGContextRef, CGFloat, const CGFloat *, size_t));
//    JOMapCFunction(CGContextSetFlatness, JOSigns(void, CGContextRef, CGFloat));
//    JOMapCFunction(CGContextSetAlpha, JOSigns(void, CGContextRef, CGFloat));
//    JOMapCFunction(CGContextSetBlendMode, JOSigns(void, CGContextRef, CGBlendMode));
//    JOMapCFunction(CGContextBeginPath, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextMoveToPoint, JOSigns(void, CGContextRef, CGFloat, CGFloat));
//    JOMapCFunction(CGContextAddLineToPoint, JOSigns(void, CGContextRef, CGFloat, CGFloat));
//    JOMapCFunction(CGContextAddCurveToPoint, JOSigns(void, CGContextRef, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGContextAddQuadCurveToPoint, JOSigns(void, CGContextRef, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGContextClosePath, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextAddRect, JOSigns(void, CGContextRef, CGRect));
//    JOMapCFunction(CGContextAddRects, JOSigns(void, CGContextRef, const CGRect *, size_t));
//    JOMapCFunction(CGContextAddEllipseInRect, JOSigns(void, CGContextRef, CGRect));
//    JOMapCFunction(CGContextAddArc, JOSigns(void, CGContextRef, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, int));
//    JOMapCFunction(CGContextAddArcToPoint, JOSigns(void, CGContextRef, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGContextAddPath, JOSigns(void, CGContextRef, CGPathRef));
//    JOMapCFunction(CGContextReplacePathWithStrokedPath, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextIsPathEmpty, JOSigns(bool, CGContextRef));
//    JOMapCFunction(CGContextGetPathCurrentPoint, JOSigns(CGPoint, CGContextRef));
//    JOMapCFunction(CGContextGetPathBoundingBox, JOSigns(CGRect, CGContextRef));
//    JOMapCFunction(CGContextCopyPath, JOSigns(CGPathRef, CGContextRef));
//    JOMapCFunction(CGContextPathContainsPoint, JOSigns(bool, CGContextRef, CGPoint, CGPathDrawingMode));
//    JOMapCFunction(CGContextDrawPath, JOSigns(void, CGContextRef, CGPathDrawingMode));
//    JOMapCFunction(CGContextFillPath, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextEOFillPath, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextStrokePath, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextFillRect, JOSigns(void, CGContextRef, CGRect));
//    JOMapCFunction(CGContextFillRects, JOSigns(void, CGContextRef, const CGRect *, size_t));
//    JOMapCFunction(CGContextStrokeRect, JOSigns(void, CGContextRef, CGRect));
//    JOMapCFunction(CGContextStrokeRectWithWidth, JOSigns(void, CGContextRef, CGRect, CGFloat));
//    JOMapCFunction(CGContextClearRect, JOSigns(void, CGContextRef, CGRect));
//    JOMapCFunction(CGContextFillEllipseInRect, JOSigns(void, CGContextRef, CGRect));
//    JOMapCFunction(CGContextStrokeEllipseInRect, JOSigns(void, CGContextRef, CGRect));
//    JOMapCFunction(CGContextStrokeLineSegments, JOSigns(void, CGContextRef, const CGPoint *, size_t));
//    JOMapCFunction(CGContextClip, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextEOClip, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextResetClip, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextClipToMask, JOSigns(void, CGContextRef, CGRect, CGImageRef));
//    JOMapCFunction(CGContextGetClipBoundingBox, JOSigns(CGRect, CGContextRef));
//    JOMapCFunction(CGContextClipToRect, JOSigns(void, CGContextRef, CGRect));
//    JOMapCFunction(CGContextClipToRects, JOSigns(void, CGContextRef, const CGRect*, size_t));
//    JOMapCFunction(CGContextSetFillColorWithColor, JOSigns(void, CGContextRef, CGColorRef));
//    JOMapCFunction(CGContextSetStrokeColorWithColor, JOSigns(void, CGContextRef, CGColorRef));
//    JOMapCFunction(CGContextSetFillColorSpace, JOSigns(void, CGContextRef, CGColorSpaceRef));
//    JOMapCFunction(CGContextSetStrokeColorSpace, JOSigns(void, CGContextRef, CGColorSpaceRef));
//    JOMapCFunction(CGContextSetFillColor, JOSigns(void, CGContextRef, const CGFloat *));
//    JOMapCFunction(CGContextSetStrokeColor, JOSigns(void, CGContextRef, const CGFloat *));
//    JOMapCFunction(CGContextSetFillPattern, JOSigns(void, CGContextRef, CGPatternRef,  const CGFloat *));
//    JOMapCFunction(CGContextSetStrokePattern, JOSigns(void, CGContextRef, CGPatternRef,  const CGFloat *));
//    JOMapCFunction(CGContextSetPatternPhase, JOSigns(void, CGContextRef, CGSize));
//    JOMapCFunction(CGContextSetGrayFillColor, JOSigns(void, CGContextRef, CGFloat, CGFloat));
//    JOMapCFunction(CGContextSetRGBFillColor, JOSigns(void, CGContextRef, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGContextSetRGBStrokeColor, JOSigns(void, CGContextRef, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGContextSetCMYKFillColor, JOSigns(void, CGContextRef, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGContextSetCMYKStrokeColor, JOSigns(void, CGContextRef, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGContextSetRenderingIntent, JOSigns(void, CGContextRef, CGColorRenderingIntent));
//    JOMapCFunction(CGContextDrawImage, JOSigns(void, CGContextRef, CGImageRef));
//    JOMapCFunction(CGContextDrawTiledImage, JOSigns(void, CGContextRef, CGRect, CGImageRef));
//    JOMapCFunction(CGContextGetInterpolationQuality, JOSigns(CGInterpolationQuality, CGContextRef));
//    JOMapCFunction(CGContextSetInterpolationQuality, JOSigns(void, CGContextRef, CGInterpolationQuality));
//    JOMapCFunction(CGContextSetShadowWithColor, JOSigns(void, CGContextRef, CGSize, CGFloat, CGColorRef));
//    JOMapCFunction(CGContextSetShadow, JOSigns(void, CGContextRef, CGSize, CGFloat));
//    JOMapCFunction(CGContextDrawLinearGradient, JOSigns(void, CGContextRef, CGGradientRef, CGPoint, CGPoint, CGGradientDrawingOptions));
//    JOMapCFunction(CGContextDrawRadialGradient, JOSigns(void, CGContextRef, CGGradientRef, CGPoint, CGFloat, CGPoint, CGFloat, CGGradientDrawingOptions));
//    JOMapCFunction(CGContextDrawShading, JOSigns(void, CGContextRef, CGShadingRef));
//    JOMapCFunction(CGContextSetCharacterSpacing, JOSigns(void, CGContextRef, CGFloat));
//    JOMapCFunction(CGContextSetTextPosition, JOSigns(void, CGContextRef, CGFloat, CGFloat));
//    JOMapCFunction(CGContextGetTextPosition, JOSigns(CGPoint, CGContextRef));
//    JOMapCFunction(CGContextSetTextMatrix, JOSigns(void, CGContextRef, CGAffineTransform));
//    JOMapCFunction(CGContextGetTextMatrix, JOSigns(CGAffineTransform, CGContextRef));
//    JOMapCFunction(CGContextSetTextDrawingMode, JOSigns(void, CGContextRef, CGTextDrawingMode));
//    JOMapCFunction(CGContextSetFont, JOSigns(void, CGContextRef, CGFontRef));
//    JOMapCFunction(CGContextSetFontSize, JOSigns(void, CGContextRef, CGFloat));
//    JOMapCFunction(CGContextShowGlyphsAtPositions, JOSigns(void, CGContextRef, const CGGlyph *, const CGPoint *, size_t));
//    JOMapCFunction(CGContextDrawPDFPage, JOSigns(void, CGContextRef, CGPDFPageRef));
//    JOMapCFunction(CGContextBeginPage, JOSigns(void, CGContextRef, const CGRect *));
//    JOMapCFunction(CGContextEndPage, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextRetain, JOSigns(CGContextRef, CGContextRef));
//    JOMapCFunction(CGContextRelease, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextFlush, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextSetShouldAntialias, JOSigns(void, CGContextRef, bool));
//    JOMapCFunction(CGContextSetAllowsAntialiasing, JOSigns(void, CGContextRef, bool));
//    JOMapCFunction(CGContextSetShouldSmoothFonts, JOSigns(void, CGContextRef, bool));
//    JOMapCFunction(CGContextSetAllowsFontSmoothing, JOSigns(void, CGContextRef, bool));
//    JOMapCFunction(CGContextSetShouldSubpixelPositionFonts, JOSigns(void, CGContextRef, bool));
//    JOMapCFunction(CGContextSetAllowsFontSubpixelPositioning, JOSigns(void, CGContextRef, bool));
//    JOMapCFunction(CGContextSetShouldSubpixelQuantizeFonts, JOSigns(void, CGContextRef, bool));
//    JOMapCFunction(CGContextSetAllowsFontSubpixelQuantization, JOSigns(void, CGContextRef, bool));
//    JOMapCFunction(CGContextBeginTransparencyLayer, JOSigns(void, CGContextRef, CFDictionaryRef));
//    JOMapCFunction(CGContextBeginTransparencyLayerWithRect, JOSigns(void, CGContextRef, CGRect, CFDictionaryRef));
//    JOMapCFunction(CGContextEndTransparencyLayer, JOSigns(void, CGContextRef));
//    JOMapCFunction(CGContextGetUserSpaceToDeviceSpaceTransform, JOSigns(CGAffineTransform, CGContextRef));
//    JOMapCFunction(CGContextGetUserSpaceToDeviceSpaceTransform, JOSigns(CGPoint, CGContextRef, CGPoint));
//    JOMapCFunction(CGContextConvertPointToUserSpace, JOSigns(CGPoint, CGContextRef, CGPoint));
//    JOMapCFunction(CGContextConvertSizeToDeviceSpace, JOSigns(CGSize, CGContextRef, CGSize));
//    JOMapCFunction(CGContextConvertSizeToUserSpace, JOSigns(CGSize, CGContextRef, CGSize));
//    JOMapCFunction(CGContextConvertRectToDeviceSpace, JOSigns(CGRect, CGContextRef, CGRect));
//    JOMapCFunction(CGContextConvertRectToUserSpace, JOSigns(CGRect, CGContextRef, CGRect));
//
    JOMapCFunction(CGContextSaveGState,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextRestoreGState,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextScaleCTM,@"v@:^{CGContext=}dd");
    JOMapCFunction(CGContextTranslateCTM,@"v@:^{CGContext=}dd");
    JOMapCFunction(CGContextRotateCTM,@"v@:^{CGContext=}d");
    JOMapCFunction(CGContextConcatCTM,@"v@:^{CGContext=}{CGAffineTransform=dddddd}");
    JOMapCFunction(CGContextGetCTM,@"{CGAffineTransform=dddddd}@:^{CGContext=}");
    JOMapCFunction(CGContextSetLineWidth,@"v@:^{CGContext=}d");
    JOMapCFunction(CGContextSetLineCap,@"v@:^{CGContext=}i");
    JOMapCFunction(CGContextSetLineJoin,@"v@:^{CGContext=}i");
    JOMapCFunction(CGContextSetMiterLimit,@"v@:^{CGContext=}d");
    JOMapCFunction(CGContextSetLineDash,@"v@:^{CGContext=}dr^dQ");
    JOMapCFunction(CGContextSetFlatness,@"v@:^{CGContext=}d");
    JOMapCFunction(CGContextSetAlpha,@"v@:^{CGContext=}d");
    JOMapCFunction(CGContextSetBlendMode,@"v@:^{CGContext=}i");
    JOMapCFunction(CGContextBeginPath,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextMoveToPoint,@"v@:^{CGContext=}dd");
    JOMapCFunction(CGContextAddLineToPoint,@"v@:^{CGContext=}dd");
    JOMapCFunction(CGContextAddCurveToPoint,@"v@:^{CGContext=}dddddd");
    JOMapCFunction(CGContextAddQuadCurveToPoint,@"v@:^{CGContext=}dddd");
    JOMapCFunction(CGContextClosePath,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextAddRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextAddRects,@"v@:^{CGContext=}r^{CGRect={CGPoint=dd}{CGSize=dd}}Q");
    JOMapCFunction(CGContextAddEllipseInRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextAddArc,@"v@:^{CGContext=}dddddi");
    JOMapCFunction(CGContextAddArcToPoint,@"v@:^{CGContext=}ddddd");
    JOMapCFunction(CGContextAddPath,@"v@:^{CGContext=}^{CGPath=}");
    JOMapCFunction(CGContextReplacePathWithStrokedPath,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextIsPathEmpty,@"B@:^{CGContext=}");
    JOMapCFunction(CGContextGetPathCurrentPoint,@"{CGPoint=dd}@:^{CGContext=}");
    JOMapCFunction(CGContextGetPathBoundingBox,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:^{CGContext=}");
    JOMapCFunction(CGContextCopyPath,@"^{CGPath=}@:^{CGContext=}");
    JOMapCFunction(CGContextPathContainsPoint,@"B@:^{CGContext=}{CGPoint=dd}i");
    JOMapCFunction(CGContextDrawPath,@"v@:^{CGContext=}i");
    JOMapCFunction(CGContextFillPath,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextEOFillPath,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextStrokePath,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextFillRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextFillRects,@"v@:^{CGContext=}r^{CGRect={CGPoint=dd}{CGSize=dd}}Q");
    JOMapCFunction(CGContextStrokeRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextStrokeRectWithWidth,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}d");
    JOMapCFunction(CGContextClearRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextFillEllipseInRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextStrokeEllipseInRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextStrokeLineSegments,@"v@:^{CGContext=}r^{CGPoint=dd}Q");
    JOMapCFunction(CGContextClip,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextEOClip,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextResetClip,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextClipToMask,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}^{CGImage=}");
    JOMapCFunction(CGContextGetClipBoundingBox,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:^{CGContext=}");
    JOMapCFunction(CGContextClipToRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextClipToRects,@"v@:^{CGContext=}r^{CGRect={CGPoint=dd}{CGSize=dd}}Q");
    JOMapCFunction(CGContextSetFillColorWithColor,@"v@:^{CGContext=}^{CGColor=}");
    JOMapCFunction(CGContextSetStrokeColorWithColor,@"v@:^{CGContext=}^{CGColor=}");
    JOMapCFunction(CGContextSetFillColorSpace,@"v@:^{CGContext=}^{CGColorSpace=}");
    JOMapCFunction(CGContextSetStrokeColorSpace,@"v@:^{CGContext=}^{CGColorSpace=}");
    JOMapCFunction(CGContextSetFillColor,@"v@:^{CGContext=}r^d");
    JOMapCFunction(CGContextSetStrokeColor,@"v@:^{CGContext=}r^d");
    JOMapCFunction(CGContextSetFillPattern,@"v@:^{CGContext=}^{CGPattern=}r^d");
    JOMapCFunction(CGContextSetStrokePattern,@"v@:^{CGContext=}^{CGPattern=}r^d");
    JOMapCFunction(CGContextSetPatternPhase,@"v@:^{CGContext=}{CGSize=dd}");
    JOMapCFunction(CGContextSetGrayFillColor,@"v@:^{CGContext=}dd");
    JOMapCFunction(CGContextSetRGBFillColor,@"v@:^{CGContext=}dddd");
    JOMapCFunction(CGContextSetRGBStrokeColor,@"v@:^{CGContext=}dddd");
    JOMapCFunction(CGContextSetCMYKFillColor,@"v@:^{CGContext=}ddddd");
    JOMapCFunction(CGContextSetCMYKStrokeColor,@"v@:^{CGContext=}ddddd");
    JOMapCFunction(CGContextSetRenderingIntent,@"v@:^{CGContext=}i");
    JOMapCFunction(CGContextDrawImage,@"v@:^{CGContext=}^{CGImage=}");
    JOMapCFunction(CGContextDrawTiledImage,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}^{CGImage=}");
    JOMapCFunction(CGContextGetInterpolationQuality,@"i@:^{CGContext=}");
    JOMapCFunction(CGContextSetInterpolationQuality,@"v@:^{CGContext=}i");
    JOMapCFunction(CGContextSetShadowWithColor,@"v@:^{CGContext=}{CGSize=dd}d^{CGColor=}");
    JOMapCFunction(CGContextSetShadow,@"v@:^{CGContext=}{CGSize=dd}d");
    JOMapCFunction(CGContextDrawLinearGradient,@"v@:^{CGContext=}^{CGGradient=}{CGPoint=dd}{CGPoint=dd}I");
    JOMapCFunction(CGContextDrawRadialGradient,@"v@:^{CGContext=}^{CGGradient=}{CGPoint=dd}d{CGPoint=dd}dI");
    JOMapCFunction(CGContextDrawShading,@"v@:^{CGContext=}^{CGShading=}");
    JOMapCFunction(CGContextSetCharacterSpacing,@"v@:^{CGContext=}d");
    JOMapCFunction(CGContextSetTextPosition,@"v@:^{CGContext=}dd");
    JOMapCFunction(CGContextGetTextPosition,@"{CGPoint=dd}@:^{CGContext=}");
    JOMapCFunction(CGContextSetTextMatrix,@"v@:^{CGContext=}{CGAffineTransform=dddddd}");
    JOMapCFunction(CGContextGetTextMatrix,@"{CGAffineTransform=dddddd}@:^{CGContext=}");
    JOMapCFunction(CGContextSetTextDrawingMode,@"v@:^{CGContext=}i");
    JOMapCFunction(CGContextSetFont,@"v@:^{CGContext=}^{CGFont=}");
    JOMapCFunction(CGContextSetFontSize,@"v@:^{CGContext=}d");
    JOMapCFunction(CGContextShowGlyphsAtPositions,@"v@:^{CGContext=}r^Sr^{CGPoint=dd}Q");
    JOMapCFunction(CGContextDrawPDFPage,@"v@:^{CGContext=}^{CGPDFPage=}");
    JOMapCFunction(CGContextBeginPage,@"v@:^{CGContext=}r^{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextEndPage,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextRetain,@"^{CGContext=}@:^{CGContext=}");
    JOMapCFunction(CGContextRelease,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextFlush,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextSetShouldAntialias,@"v@:^{CGContext=}B");
    JOMapCFunction(CGContextSetAllowsAntialiasing,@"v@:^{CGContext=}B");
    JOMapCFunction(CGContextSetShouldSmoothFonts,@"v@:^{CGContext=}B");
    JOMapCFunction(CGContextSetAllowsFontSmoothing,@"v@:^{CGContext=}B");
    JOMapCFunction(CGContextSetShouldSubpixelPositionFonts,@"v@:^{CGContext=}B");
    JOMapCFunction(CGContextSetAllowsFontSubpixelPositioning,@"v@:^{CGContext=}B");
    JOMapCFunction(CGContextSetShouldSubpixelQuantizeFonts,@"v@:^{CGContext=}B");
    JOMapCFunction(CGContextSetAllowsFontSubpixelQuantization,@"v@:^{CGContext=}B");
    JOMapCFunction(CGContextBeginTransparencyLayer,@"v@:^{CGContext=}^{__CFDictionary=}");
    JOMapCFunction(CGContextBeginTransparencyLayerWithRect,@"v@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}^{__CFDictionary=}");
    JOMapCFunction(CGContextEndTransparencyLayer,@"v@:^{CGContext=}");
    JOMapCFunction(CGContextGetUserSpaceToDeviceSpaceTransform,@"{CGAffineTransform=dddddd}@:^{CGContext=}");
    JOMapCFunction(CGContextGetUserSpaceToDeviceSpaceTransform,@"{CGPoint=dd}@:^{CGContext=}{CGPoint=dd}");
    JOMapCFunction(CGContextConvertPointToUserSpace,@"{CGPoint=dd}@:^{CGContext=}{CGPoint=dd}");
    JOMapCFunction(CGContextConvertSizeToDeviceSpace,@"{CGSize=dd}@:^{CGContext=}{CGSize=dd}");
    JOMapCFunction(CGContextConvertSizeToUserSpace,@"{CGSize=dd}@:^{CGContext=}{CGSize=dd}");
    JOMapCFunction(CGContextConvertRectToDeviceSpace,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGContextConvertRectToUserSpace,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:^{CGContext=}{CGRect={CGPoint=dd}{CGSize=dd}}");
}

+ (void)addCGPath {
//    JOMapCFunction(CGPathCreateMutable, JOSignReturn(CGMutablePathRef));
//    JOMapCFunction(CGPathCreateCopy, JOSigns(CGPathRef, CGPathRef));
//    JOMapCFunction(CGPathCreateCopyByTransformingPath, JOSigns(CGPathRef, CGPathRef, const CGAffineTransform *));
//    JOMapCFunction(CGPathCreateMutableCopy, JOSigns(CGMutablePathRef, CGPathRef));
//    JOMapCFunction(CGPathCreateMutableCopyByTransformingPath, JOSigns(CGMutablePathRef, CGPathRef, CGAffineTransform));
//    JOMapCFunction(CGPathCreateWithRect, JOSigns(CGPathRef, CGRect, const CGAffineTransform *));
//    JOMapCFunction(CGPathCreateWithEllipseInRect, JOSigns(CGPathRef, CGRect, const CGAffineTransform *));
//    JOMapCFunction(CGPathCreateWithRoundedRect, JOSigns(CGPathRef, CGRect, CGFloat, CGFloat, const CGAffineTransform *));
//    JOMapCFunction(CGPathAddRoundedRect, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGRect, CGFloat));
//    JOMapCFunction(CGPathCreateCopyByDashingPath, JOSigns(CGPathRef, CGPathRef, const CGAffineTransform *, CGFloat, const CGFloat *, size_t));
//    JOMapCFunction(CGPathCreateCopyByStrokingPath, JOSigns(CGPathRef, CGPathRef, const CGAffineTransform *, CGFloat, CGLineCap, CGLineJoin, CGFloat));
//    JOMapCFunction(CGPathRetain, JOSigns(CGPathRef, CGPathRef));
//    JOMapCFunction(CGPathRetain, JOSigns(void, CGPathRef));
//    JOMapCFunction(CGPathEqualToPath, JOSigns(bool, CGPathRef, CGPathRef));
//    JOMapCFunction(CGPathMoveToPoint, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGFloat, CGFloat));
//    JOMapCFunction(CGPathAddLineToPoint, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGFloat, CGFloat));
//    JOMapCFunction(CGPathAddQuadCurveToPoint, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGPathAddCurveToPoint, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGPathCloseSubpath, JOSigns(void, CGMutablePathRef));
//    JOMapCFunction(CGPathAddRect, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGRect));
//    JOMapCFunction(CGPathCloseSubpath, JOSigns(void, CGMutablePathRef));
//    JOMapCFunction(CGPathAddRects, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, const CGRect *, size_t));
//    JOMapCFunction(CGPathAddLines, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, const CGPoint *, size_t));
//    JOMapCFunction(CGPathAddEllipseInRect, JOSigns(void, CGMutablePathRef, const CGAffineTransform *));
//    JOMapCFunction(CGPathAddRelativeArc, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGPathAddArc, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, bool));
//    JOMapCFunction(CGPathAddArcToPoint, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGPathAddPath, JOSigns(void, CGMutablePathRef, const CGAffineTransform *, CGPathRef));
//    JOMapCFunction(CGPathIsEmpty, JOSigns(bool, CGPathRef));
//    JOMapCFunction(CGPathIsRect, JOSigns(bool, CGPathRef, CGRect *));
//    JOMapCFunction(CGPathGetCurrentPoint, JOSigns(CGPoint, CGPathRef));
//    JOMapCFunction(CGPathGetBoundingBox, JOSigns(CGRect, CGPathRef));
//    JOMapCFunction(CGPathGetPathBoundingBox, JOSigns(CGRect, CGPathRef));
//    JOMapCFunction(CGPathContainsPoint, JOSigns(bool, CGPathRef, const CGAffineTransform *, CGPoint, bool));
//
    
    JOMapCFunction(CGPathCreateMutable,@"^{CGPath=}@:");
    JOMapCFunction(CGPathCreateCopy,@"^{CGPath=}@:^{CGPath=}");
    JOMapCFunction(CGPathCreateCopyByTransformingPath,@"^{CGPath=}@:^{CGPath=}r^{CGAffineTransform=dddddd}");
    JOMapCFunction(CGPathCreateMutableCopy,@"^{CGPath=}@:^{CGPath=}");
    JOMapCFunction(CGPathCreateMutableCopyByTransformingPath,@"^{CGPath=}@:^{CGPath=}{CGAffineTransform=dddddd}");
    JOMapCFunction(CGPathCreateWithRect,@"^{CGPath=}@:{CGRect={CGPoint=dd}{CGSize=dd}}r^{CGAffineTransform=dddddd}");
    JOMapCFunction(CGPathCreateWithEllipseInRect,@"^{CGPath=}@:{CGRect={CGPoint=dd}{CGSize=dd}}r^{CGAffineTransform=dddddd}");
    JOMapCFunction(CGPathCreateWithRoundedRect,@"^{CGPath=}@:{CGRect={CGPoint=dd}{CGSize=dd}}ddr^{CGAffineTransform=dddddd}");
    JOMapCFunction(CGPathAddRoundedRect,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}{CGRect={CGPoint=dd}{CGSize=dd}}d");
    JOMapCFunction(CGPathCreateCopyByDashingPath,@"^{CGPath=}@:^{CGPath=}r^{CGAffineTransform=dddddd}dr^dQ");
    JOMapCFunction(CGPathCreateCopyByStrokingPath,@"^{CGPath=}@:^{CGPath=}r^{CGAffineTransform=dddddd}diid");
    JOMapCFunction(CGPathRetain,@"^{CGPath=}@:^{CGPath=}");
    JOMapCFunction(CGPathRetain,@"v@:^{CGPath=}");
    JOMapCFunction(CGPathEqualToPath,@"B@:^{CGPath=}^{CGPath=}");
    JOMapCFunction(CGPathMoveToPoint,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}dd");
    JOMapCFunction(CGPathAddLineToPoint,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}dd");
    JOMapCFunction(CGPathAddQuadCurveToPoint,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}dddd");
    JOMapCFunction(CGPathAddCurveToPoint,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}dddddd");
    JOMapCFunction(CGPathCloseSubpath,@"v@:^{CGPath=}");
    JOMapCFunction(CGPathAddRect,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGPathCloseSubpath,@"v@:^{CGPath=}");
    JOMapCFunction(CGPathAddRects,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}r^{CGRect={CGPoint=dd}{CGSize=dd}}Q");
    JOMapCFunction(CGPathAddLines,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}r^{CGPoint=dd}Q");
    JOMapCFunction(CGPathAddEllipseInRect,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}");
    JOMapCFunction(CGPathAddRelativeArc,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}ddddd");
    JOMapCFunction(CGPathAddArc,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}dddddB");
    JOMapCFunction(CGPathAddArcToPoint,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}ddddd");
    JOMapCFunction(CGPathAddPath,@"v@:^{CGPath=}r^{CGAffineTransform=dddddd}^{CGPath=}");
    JOMapCFunction(CGPathIsEmpty,@"B@:^{CGPath=}");
    JOMapCFunction(CGPathIsRect,@"B@:^{CGPath=}^{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGPathGetCurrentPoint,@"{CGPoint=dd}@:^{CGPath=}");
    JOMapCFunction(CGPathGetBoundingBox,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:^{CGPath=}");
    JOMapCFunction(CGPathGetPathBoundingBox,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:^{CGPath=}");
    JOMapCFunction(CGPathContainsPoint,@"B@:^{CGPath=}r^{CGAffineTransform=dddddd}{CGPoint=dd}B");
}

+ (void)addCGRect {
    //    JOMapCFunction(CGVectorMake, JOSigns(CGVector, CGFloat, CGFloat));
//    JOMapCFunction(CGSizeMake, JOSigns(CGSize, CGFloat, CGFloat));
//    JOMapCFunction(CGRectMake, JOSigns(CGRect, CGFloat, CGFloat, CGFloat, CGFloat));
//    JOMapCFunction(CGPointMake, JOSigns(CGPoint, CGFloat, CGFloat));
//    JOMapCFunction(CGRectGetMinX, JOSigns(CGFloat, CGRect));
//    JOMapCFunction(CGRectGetMidX, JOSigns(CGFloat, CGRect));
//    JOMapCFunction(CGRectGetMaxX, JOSigns(CGFloat, CGRect));
//    JOMapCFunction(CGRectGetMinY, JOSigns(CGFloat, CGRect));
//    JOMapCFunction(CGRectGetMidY, JOSigns(CGFloat, CGRect));
//    JOMapCFunction(CGRectGetMaxY, JOSigns(CGFloat, CGRect));
//    JOMapCFunction(CGRectGetWidth, JOSigns(CGFloat, CGRect));
//    JOMapCFunction(CGRectGetHeight, JOSigns(CGFloat, CGRect));
//    JOMapCFunction(CGRectGetWidth, JOSigns(CGFloat, CGRect));
    [self mapCFunction:@"CGPointEqualToPoint" type:JOSigns(bool, CGPoint, CGPoint) imp:__CGPointEqualToPoint];
    [self mapCFunction:@"CGSizeEqualToSize" type:JOSigns(bool, CGPoint, CGPoint) imp:__CGSizeEqualToSize];
//    JOMapCFunction(CGRectEqualToRect, JOSigns(bool, CGRect, CGRect));
//    JOMapCFunction(CGRectStandardize, JOSigns(CGRect, CGRect));
//    JOMapCFunction(CGRectIsEmpty, JOSigns(bool, CGRect));
//    JOMapCFunction(CGRectIsNull, JOSigns(bool, CGRect));
//    JOMapCFunction(CGRectIsInfinite, JOSigns(bool, CGRect));
//    JOMapCFunction(CGRectInset, JOSigns(CGRect, CGRect, CGFloat, CGFloat));
//    JOMapCFunction(CGRectIntegral, JOSigns(CGRect, CGRect));
//    JOMapCFunction(CGRectUnion, JOSigns(CGRect, CGRect, CGRect));
//    JOMapCFunction(CGRectIntersection, JOSigns(CGRect, CGRect, CGRect));
//    JOMapCFunction(CGRectOffset, JOSigns(CGRect, CGRect, CGFloat, CGFloat));
//    JOMapCFunction(CGRectDivide, JOSigns(void, CGRect, CGRect *, CGRect *, CGFloat, CGRectEdge));
//    JOMapCFunction(CGRectContainsPoint, JOSigns(bool, CGRect, CGPoint));
//    JOMapCFunction(CGRectContainsRect, JOSigns(bool, CGRect, CGRect));
//    JOMapCFunction(CGRectIntersectsRect, JOSigns(bool, CGRect, CGRect));
//    JOMapCFunction(CGPointCreateDictionaryRepresentation, JOSigns(CFDictionaryRef, CGPoint));
//    JOMapCFunction(CGPointMakeWithDictionaryRepresentation, JOSigns(bool, CFDictionaryRef, CGPoint *));
//    JOMapCFunction(CGRectCreateDictionaryRepresentation, JOSigns(CFDictionaryRef, CGRect));
//    JOMapCFunction(CGRectMakeWithDictionaryRepresentation, JOSigns(bool, CFDictionaryRef, CGRect *));
//    JOMapCFunction(CGRectCreateDictionaryRepresentation, JOSigns(CFDictionaryRef, CGRect));
    
    JOMapCFunction(CGSizeMake,@"{CGSize=dd}@:dd");
    JOMapCFunction(CGRectMake,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:dddd");
    JOMapCFunction(CGPointMake,@"{CGPoint=dd}@:dd");
    JOMapCFunction(CGRectGetMinX,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectGetMidX,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectGetMaxX,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectGetMinY,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectGetMidY,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectGetMaxY,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectGetWidth,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectGetHeight,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectGetWidth,@"d@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectEqualToRect,@"B@:{CGRect={CGPoint=dd}{CGSize=dd}}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectStandardize,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectIsEmpty,@"B@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectIsNull,@"B@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectIsInfinite,@"B@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectInset,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}dd");
    JOMapCFunction(CGRectIntegral,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectUnion,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectIntersection,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectOffset,@"{CGRect={CGPoint=dd}{CGSize=dd}}@:{CGRect={CGPoint=dd}{CGSize=dd}}dd");
    JOMapCFunction(CGRectDivide,@"v@:{CGRect={CGPoint=dd}{CGSize=dd}}^{CGRect={CGPoint=dd}{CGSize=dd}}^{CGRect={CGPoint=dd}{CGSize=dd}}dI");
    JOMapCFunction(CGRectContainsPoint,@"B@:{CGRect={CGPoint=dd}{CGSize=dd}}{CGPoint=dd}");
    JOMapCFunction(CGRectContainsRect,@"B@:{CGRect={CGPoint=dd}{CGSize=dd}}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectIntersectsRect,@"B@:{CGRect={CGPoint=dd}{CGSize=dd}}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGPointCreateDictionaryRepresentation,@"^{__CFDictionary=}@:{CGPoint=dd}");
    JOMapCFunction(CGPointMakeWithDictionaryRepresentation,@"B@:^{__CFDictionary=}^{CGPoint=dd}");
    JOMapCFunction(CGRectCreateDictionaryRepresentation,@"^{__CFDictionary=}@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectMakeWithDictionaryRepresentation,@"B@:^{__CFDictionary=}^{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGRectCreateDictionaryRepresentation,@"^{__CFDictionary=}@:{CGRect={CGPoint=dd}{CGSize=dd}}");
}


+ (void)addCGImage {
    JOMapCFunction(CGImageCreate,@"*@:QQQQQ*I**BI");
//    JOMapCFunction(CGImageMaskCreate, JOSigns(CGImageRef, size_t, size_t, size_t, size_t, size_t, CGDataProviderRef, const CGFloat *, bool));
    [self mapCFunction:@"CGImageMaskCreate" type:JOSigns(CGImageRef, size_t, size_t, size_t, size_t, size_t, CGDataProviderRef, const CGFloat *, bool) imp:(IMP)JOCGImageMaskCreate];
//    JOMapCFunction(CGImageCreateCopy, JOSigns(CGImageRef, CGImageRef));
//    JOMapCFunction(CGImageCreateWithJPEGDataProvider, JOSigns(CGImageRef, CGDataProviderRef, const CGFloat *, bool, CGColorRenderingIntent));
//    JOMapCFunction(CGImageCreateWithPNGDataProvider, JOSigns(CGImageRef, CGDataProviderRef, const CGFloat *, bool, CGColorRenderingIntent));
//    JOMapCFunction(CGImageCreateWithImageInRect, JOSigns(CGImageRef, CGImageRef, CGRect));
//    JOMapCFunction(CGImageCreateWithMask, JOSigns(CGImageRef, CGImageRef, CGImageRef));
//    JOMapCFunction(CGImageCreateWithMaskingColors, JOSigns(CGImageRef, CGImageRef, const CGFloat *));
//    JOMapCFunction(CGImageCreateCopyWithColorSpace, JOSigns(CGImageRef, CGImageRef, CGColorSpaceRef));
//    JOMapCFunction(CGImageRetain, JOSigns(CGImageRef, CGImageRef));
//    JOMapCFunction(CGImageRelease, JOSigns(void, CGImageRef));
//    JOMapCFunction(CGImageIsMask, JOSigns(bool, CGImageRef));
//    JOMapCFunction(CGImageGetWidth, JOSigns(size_t, CGImageRef));
//    JOMapCFunction(CGImageGetHeight, JOSigns(size_t, CGImageRef));
//    JOMapCFunction(CGImageGetBitsPerComponent, JOSigns(size_t, CGImageRef));
//    JOMapCFunction(CGImageGetBitsPerPixel, JOSigns(size_t, CGImageRef));
//    JOMapCFunction(CGImageGetBytesPerRow, JOSigns(size_t, CGImageRef));
//    JOMapCFunction(CGImageGetColorSpace, JOSigns(CGColorSpaceRef, CGImageRef));
//    JOMapCFunction(CGImageGetAlphaInfo, JOSigns(CGImageAlphaInfo, CGImageRef));
//    JOMapCFunction(CGImageGetDataProvider, JOSigns(CGDataProviderRef, CGImageRef));
//    JOMapCFunction(CGImageGetShouldInterpolate, JOSigns(bool, CGImageRef));
//    JOMapCFunction(CGImageGetRenderingIntent, JOSigns(CGColorRenderingIntent, CGImageRef));
//    JOMapCFunction(CGImageGetBitmapInfo, JOSigns(CGBitmapInfo, CGImageRef));
//    if (@available(iOS 12.0, *)) {
//        JOMapCFunction(CGImageGetByteOrderInfo, JOSigns(CGImageByteOrderInfo, CGImageRef));
//        JOMapCFunction(CGImageGetPixelFormatInfo, JOSigns(CGImagePixelFormatInfo, CGImageRef));
//    }
    
    JOMapCFunction(CGImageCreate,@"*@:QQQQQ*I**BI");
    JOMapCFunction(CGImageCreateCopy,@"^{CGImage=}@:^{CGImage=}");
    JOMapCFunction(CGImageCreateWithJPEGDataProvider,@"^{CGImage=}@:^{CGDataProvider=}r^dBi");
    JOMapCFunction(CGImageCreateWithPNGDataProvider,@"^{CGImage=}@:^{CGDataProvider=}r^dBi");
    JOMapCFunction(CGImageCreateWithImageInRect,@"^{CGImage=}@:^{CGImage=}{CGRect={CGPoint=dd}{CGSize=dd}}");
    JOMapCFunction(CGImageCreateWithMask,@"^{CGImage=}@:^{CGImage=}^{CGImage=}");
    JOMapCFunction(CGImageCreateWithMaskingColors,@"^{CGImage=}@:^{CGImage=}r^d");
    JOMapCFunction(CGImageCreateCopyWithColorSpace,@"^{CGImage=}@:^{CGImage=}^{CGColorSpace=}");
    JOMapCFunction(CGImageRetain,@"^{CGImage=}@:^{CGImage=}");
    JOMapCFunction(CGImageRelease,@"v@:^{CGImage=}");
    JOMapCFunction(CGImageIsMask,@"B@:^{CGImage=}");
    JOMapCFunction(CGImageGetWidth,@"Q@:^{CGImage=}");
    JOMapCFunction(CGImageGetHeight,@"Q@:^{CGImage=}");
    JOMapCFunction(CGImageGetBitsPerComponent,@"Q@:^{CGImage=}");
    JOMapCFunction(CGImageGetBitsPerPixel,@"Q@:^{CGImage=}");
    JOMapCFunction(CGImageGetBytesPerRow,@"Q@:^{CGImage=}");
    JOMapCFunction(CGImageGetColorSpace,@"^{CGColorSpace=}@:^{CGImage=}");
    JOMapCFunction(CGImageGetAlphaInfo,@"I@:^{CGImage=}");
    JOMapCFunction(CGImageGetDataProvider,@"^{CGDataProvider=}@:^{CGImage=}");
    JOMapCFunction(CGImageGetShouldInterpolate,@"B@:^{CGImage=}");
    JOMapCFunction(CGImageGetRenderingIntent,@"i@:^{CGImage=}");
    JOMapCFunction(CGImageGetBitmapInfo,@"I@:^{CGImage=}");
    if (@available(iOS 12.0, *)) {
        JOMapCFunction(CGImageGetByteOrderInfo,@"I@:^{CGImage=}");
        JOMapCFunction(CGImageGetPixelFormatInfo,@"I@:^{CGImage=}");
    }
}

+ (void)addCGAffineTransform {
    
    [self mapCFunction:@"CGAffineTransformMake" type:JOSigns(CGAffineTransform, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) imp:__CGAffineTransformMake];
//    JOMapCFunction(CGAffineTransformMakeTranslation, JOSigns(CGAffineTransform, CGFloat, CGFloat));
//    JOMapCFunction(CGAffineTransformMakeScale, JOSigns(CGAffineTransform, CGFloat, CGFloat));
//    JOMapCFunction(CGAffineTransformIsIdentity, JOSigns(bool, CGAffineTransform));
//    JOMapCFunction(CGAffineTransformTranslate, JOSigns(CGAffineTransform, CGAffineTransform, CGFloat, CGFloat));
//    JOMapCFunction(CGAffineTransformScale, JOSigns(CGAffineTransform, CGAffineTransform, CGFloat, CGFloat));
//    JOMapCFunction(CGAffineTransformRotate, JOSigns(CGAffineTransform, CGAffineTransform, CGFloat));
//    JOMapCFunction(CGAffineTransformInvert, JOSigns(CGAffineTransform, CGAffineTransform));
//    JOMapCFunction(CGAffineTransformConcat, JOSigns(CGAffineTransform, CGAffineTransform, CGAffineTransform));
//    JOMapCFunction(CGAffineTransformEqualToTransform, JOSigns(bool, CGAffineTransform, CGAffineTransform));
    [self mapCFunction:@"CGPointApplyAffineTransform" type:JOSigns(CGPoint, CGPoint, CGAffineTransform) imp:__CGPointApplyAffineTransform];
    [self mapCFunction:@"CGSizeApplyAffineTransform" type:JOSigns(CGSize, CGSize, CGAffineTransform) imp:__CGSizeApplyAffineTransform];
    
    JOMapCFunction(CGAffineTransformMakeTranslation,@"{CGAffineTransform=dddddd}@:dd");
    JOMapCFunction(CGAffineTransformMakeScale,@"{CGAffineTransform=dddddd}@:dd");
    JOMapCFunction(CGAffineTransformIsIdentity,@"B@:{CGAffineTransform=dddddd}");
    JOMapCFunction(CGAffineTransformTranslate,@"{CGAffineTransform=dddddd}@:{CGAffineTransform=dddddd}dd");
    JOMapCFunction(CGAffineTransformScale,@"{CGAffineTransform=dddddd}@:{CGAffineTransform=dddddd}dd");
    JOMapCFunction(CGAffineTransformRotate,@"{CGAffineTransform=dddddd}@:{CGAffineTransform=dddddd}d");
    JOMapCFunction(CGAffineTransformInvert,@"{CGAffineTransform=dddddd}@:{CGAffineTransform=dddddd}");
    JOMapCFunction(CGAffineTransformConcat,@"{CGAffineTransform=dddddd}@:{CGAffineTransform=dddddd}{CGAffineTransform=dddddd}");
    JOMapCFunction(CGAffineTransformEqualToTransform,@"B@:{CGAffineTransform=dddddd}{CGAffineTransform=dddddd}");
}

+ (void)addMath {

//    JOMapCFunction(sin, JOSigns(double, double));
//    JOMapCFunction(cos, JOSigns(double, double));
//    JOMapCFunction(tan, JOSigns(double, double));
//
//    JOMapCFunction(asin, JOSigns(double, double));
//    JOMapCFunction(atan, JOSigns(double, double));
//    JOMapCFunction(atan2, JOSigns(double, double, double));
//
//    JOMapCFunction(sinh, JOSigns(double, double));
//    JOMapCFunction(cosh, JOSigns(double, double));
//    JOMapCFunction(tanh, JOSigns(double, double));
//
//    JOMapCFunction(frexp, JOSigns(double, double, int *));
//    JOMapCFunction(ldexp, JOSigns(double, double, int));
//    JOMapCFunction(log, JOSigns(double, double));
//    JOMapCFunction(log2, JOSigns(double, double));
//    JOMapCFunction(log10, JOSigns(double, double));
//    JOMapCFunction(pow, JOSigns(double, double, double));
//    JOMapCFunction(exp, JOSigns(double, double));
//    JOMapCFunction(sqrt, JOSigns(double, double));
//
//    JOMapCFunction(ceil, JOSigns(double, double));
//    JOMapCFunction(floor, JOSigns(double, double));
//
//    JOMapCFunction(abs, JOSigns(double, double));
//    JOMapCFunction(fabs, JOSigns(double, double));
//
//    JOMapCFunction(frexp, JOSigns(double, double, int *));
//    JOMapCFunction(ldexp, JOSigns(double, double, int ));
//
//    JOMapCFunction(modf, JOSigns(double, double, double *));
//    JOMapCFunction(ldexp, JOSigns(double, double, double));
//
//    JOMapCFunction(hypot, JOSigns(double, double, double));
//    JOMapCFunction(ldexp, JOSigns(double, double, int));
    
    JOMapCFunction(sin,@"d@:d");
    JOMapCFunction(cos,@"d@:d");
    JOMapCFunction(tan,@"d@:d");
    JOMapCFunction(asin,@"d@:d");
    JOMapCFunction(atan,@"d@:d");
    JOMapCFunction(atan2,@"d@:dd");
    JOMapCFunction(sinh,@"d@:d");
    JOMapCFunction(cosh,@"d@:d");
    JOMapCFunction(tanh,@"d@:d");
    JOMapCFunction(frexp,@"d@:d^i");
    JOMapCFunction(ldexp,@"d@:di");
    JOMapCFunction(log,@"d@:d");
    JOMapCFunction(log2,@"d@:d");
    JOMapCFunction(log10,@"d@:d");
    JOMapCFunction(pow,@"d@:dd");
    JOMapCFunction(exp,@"d@:d");
    JOMapCFunction(sqrt,@"d@:d");
    JOMapCFunction(ceil,@"d@:d");
    JOMapCFunction(floor,@"d@:d");
    JOMapCFunction(abs,@"d@:d");
    JOMapCFunction(fabs,@"d@:d");
    JOMapCFunction(frexp,@"d@:d^i");
    JOMapCFunction(ldexp,@"d@:di");
    JOMapCFunction(modf,@"d@:d^d");
    JOMapCFunction(ldexp,@"d@:dd");
    JOMapCFunction(hypot,@"d@:dd");
    JOMapCFunction(ldexp,@"d@:di");

}
@end


#endif
