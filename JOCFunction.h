//
//  JOCFunction.h
//  JOBridge
//
//  Created by Wei on 2018/10/31.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import <Foundation/Foundation.h>
#import "JOPluginBase.h"

#define JO_PARAMS_NUM(...) JO_PARAMS_COUNTER(-1, ##__VA_ARGS__,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0)
#define JO_PARAMS_COUNTER(P1,P2,P3,P4,P5,P6,P7,P8,P9,P10,P11,P12,p13,p14,p15,p16,p17,p18,p19,p20,Pn,...) Pn

#define JO_PARAMS_INDEX_8(p1, p2, p3, p4, p5, p6, p7, p8, ...) p8
#define JO_PARAMS_INDEX_7(p1, p2, p3, p4, p5, p6, p7, ...) p7
#define JO_PARAMS_INDEX_6(p1, p2, p3, p4, p5, p6, ...) p6
#define JO_PARAMS_INDEX_5(p1, p2, p3, p4, p5, ...) p5
#define JO_PARAMS_INDEX_4(p1, p2, p3, p4, ...) p4
#define JO_PARAMS_INDEX_3(p1, p2, p3, ...) p3
#define JO_PARAMS_INDEX_2(p1, p2, ...) p2
#define JO_PARAMS_INDEX_1(p1, ...) p1


#define JOSignCat(p1, p2) [p2 stringByAppendingString:p1]
#define JOSignParams(...)\
({  NSString *sign = @"";\
    switch(JO_PARAMS_NUM(__VA_ARGS__)) {\
        case 8 : sign = JOSignCat(sign, JOSignCFunction(JO_PARAMS_INDEX_8(__VA_ARGS__,void,void,void,void,void,void,void,void)));\
        case 7 : sign = JOSignCat(sign, JOSignCFunction(JO_PARAMS_INDEX_7(__VA_ARGS__,void,void,void,void,void,void,void)));\
        case 6 : sign = JOSignCat(sign, JOSignCFunction(JO_PARAMS_INDEX_6(__VA_ARGS__,void,void,void,void,void,void)));\
        case 5 : sign = JOSignCat(sign, JOSignCFunction(JO_PARAMS_INDEX_5(__VA_ARGS__,void,void,void,void,void)));\
        case 4 : sign = JOSignCat(sign, JOSignCFunction(JO_PARAMS_INDEX_4(__VA_ARGS__,void,void,void,void)));\
        case 3 : sign = JOSignCat(sign, JOSignCFunction(JO_PARAMS_INDEX_3(__VA_ARGS__,void,void,void)));\
        case 2 : sign = JOSignCat(sign, JOSignCFunction(JO_PARAMS_INDEX_2(__VA_ARGS__,void,void)));\
        case 1 : sign = JOSignCat(sign, JOSignCFunction(JO_PARAMS_INDEX_1(__VA_ARGS__,void)));\
    }\
    sign;\
})

#define JOSignCFunction(type)\
    [NSString stringWithUTF8String:@encode(type)]
//将参数串生成签名字符串，至少包含一个参数
#define JOSigns(ret, ...)\
    [JOSignReturn(ret) stringByAppendingString:JOSignParams(__VA_ARGS__)]
//将返回值生成签名字符串，如果函数没有参数则只能调用本宏生成签名
#define JOSignReturn(ret) [JOSignCFunction(ret) stringByAppendingString:@"@:"]


//映射C函数到本类，如果使用JOSigns太多，可以设置JOBridge.isDebug来打印预处理的方法，然后复制输出日志直接注册签名字符串
#define JOMapCFunction(name, sign) [self mapCFunction:@#name type:sign imp:name];


JOEXTERN JOINLINE void *JOGetCFunction(id obj, SEL cmd);//根据selector获取对应实现，本函数未加锁，所以映射C函数的工作最好一次性完成。


//C函数映射可以从本类继承
@interface JOCFunction : JOPluginBase
/** 调用mapCFunction:type:imp:映射OC方法，默认给js开放全局对象"JC"，通过JC.CGRectMake()来调用对应方法 */
+ (void)mapCFunction:(NSString *)name type:(NSString *)type imp:(void *)imp;

@end



#endif
