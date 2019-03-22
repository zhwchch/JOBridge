//
//  JOSwizzle.m
//  JOBridge
//
//  Created by Wei on 2018/9/21.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import "JOSwizzle.h"
#import <objc/runtime.h>
#import "JOObject.h"
#import "JOClass.h"
#import "JOBridge.h"
#import "JOCFunction.h"
#import "JOBlock.h"
#import <pthread.h>
#import "JOTools.h"


//JOBridge定义以下函数
JOEXTERN id JOPackBlockValue(void (^returnBlock)(void));
JOEXTERN id JOPackStructValue(const char *type, JODoubleWord6 v);

//处理结构体的签名信息，只使用一个指针大小，提高效率
typedef struct JOTypeInfo {
    char type;
    short length;
    short algin;
    short offset;
} JOTypeInfo;

typedef struct JOTypeInfoArray {
    union {
        NSUInteger index;//调用JOAddTypeInfoToArray时表示index，完成后表示count
        NSUInteger count;
    };
    JOTypeInfo typeArray[16];
} JOTypeInfoArray;



static pthread_mutex_t _JOSwizzleLock;


JOLOADER(113) void JOSwizzleInit() {
    pthread_mutexattr_t *attribute = malloc(sizeof(pthread_mutexattr_t));
    pthread_mutexattr_settype(attribute, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&_JOSwizzleLock, attribute);
    free(attribute);
}

#pragma mark - Proprocess Parameters

void JOGlobalBlockGetParams(void) JOPTNONE {
    asm volatile("stp    x29, x30, [sp, #-0x10]!");
    
    asm volatile("mov    x29, sp\n\
                 sub    sp, sp, #0xb0");
    /*  这里我存储的是d0-d7(8Byte)，而苹果源码中是保存的q0-q7(16Byte)，可以参考objc-msg-arm64.s文件中的MethodTableLookup
        我这么做主要是为了解析参数方便，而且一般是传参是用不了qx寄存器的，只有特殊情况，比如：做巨大数据的乘积运算才可能用到qx寄存器，
        另外x寄存器也一样，一般情况下一个参数和返回值（结构体或者乘积除外）只会用一个寄存器，所以这里就偷懒了，忽略了4-Word的情况
     */
    asm volatile("str    d7, [sp, #0x88]\n\
                 str    d6, [sp, #0x80]\n\
                 str    d5, [sp, #0x78]\n\
                 str    d4, [sp, #0x70]\n\
                 str    d3, [sp, #0x68]\n\
                 str    d2, [sp, #0x60]\n\
                 str    d1, [sp, #0x58]\n\
                 str    d0, [sp, #0x50]\n\
                 str    x8, [sp, #0x40]\n\
                 str    x7, [sp, #0x38]\n\
                 str    x6, [sp, #0x30]\n\
                 str    x5, [sp, #0x28]\n\
                 str    x4, [sp, #0x20]\n\
                 str    x3, [sp, #0x18]\n\
                 str    x2, [sp, #0x10]\n\
                 str    x1, [sp, #0x8]\n\
                 str    x0, [sp]\n\
                 mov    x2, sp\n\
                 add    x3, sp, #0x50\n\
                 add    x4, sp, #0xb0\n\
                 bl     _JOGlobalParamsResolver\n\
                 ");
    asm volatile("mov    sp, x29");
    asm volatile("ldp    x29, x30, [sp], #0x10");
}


void JOGlobalCSwizzle(void) JOPTNONE {
    asm volatile("stp    x29, x30, [sp, #-0x10]!");
    
    asm volatile("mov    x29, sp\n\
                 sub    sp, sp, #0xb0");

    asm volatile("str    d7, [sp, #0x88]\n\
                 str    d6, [sp, #0x80]\n\
                 str    d5, [sp, #0x78]\n\
                 str    d4, [sp, #0x70]\n\
                 str    d3, [sp, #0x68]\n\
                 str    d2, [sp, #0x60]\n\
                 str    d1, [sp, #0x58]\n\
                 str    d0, [sp, #0x50]\n\
                 str    x8, [sp, #0x40]\n\
                 str    x7, [sp, #0x38]\n\
                 str    x6, [sp, #0x30]\n\
                 str    x5, [sp, #0x28]\n\
                 str    x4, [sp, #0x20]\n\
                 str    x3, [sp, #0x18]\n\
                 str    x2, [sp, #0x10]\n\
                 str    x1, [sp, #0x8]\n\
                 str    x0, [sp]\n\
                 ");

//    asm volatile("mov    x0, x1");
    asm volatile("bl    _JOGetCFunction");

    //这里最多处理6个整型参数，多如果要处理更多的参数，就需要解析参数，比较麻烦
    asm volatile("mov    x17, x0");
    asm volatile("ldr    d7, [sp, #0x88]\n\
                 ldr    d6, [sp, #0x80]\n\
                 ldr    d5, [sp, #0x78]\n\
                 ldr    d4, [sp, #0x70]\n\
                 ldr    d3, [sp, #0x68]\n\
                 ldr    d2, [sp, #0x60]\n\
                 ldr    d1, [sp, #0x58]\n\
                 ldr    d0, [sp, #0x50]\n\
//                 ldr    x8, [sp, #0xb8]\n\
//                 ldr    x7, [sp, #0xb0]\n\
                 ldr    x6, [sp, #0x40]\n\
                 ldr    x5, [sp, #0x38]\n\
                 ldr    x4, [sp, #0x30]\n\
                 ldr    x3, [sp, #0x28]\n\
                 ldr    x2, [sp, #0x20]\n\
                 ldr    x1, [sp, #0x18]\n\
                 ");
    asm volatile("ldr    x0, [sp, #0x10]");

    asm volatile("blr    x17");

    asm volatile("mov    sp, x29");
    asm volatile("ldp    x29,   x30, [sp], #0x10");
}


//将所有参数取出来全部放入栈上，然后调用JOGlobalParamsResolver来根据签名来解析
void JOGlobalSwizzle(void) JOPTNONE {
    asm volatile("stp    x29, x30, [sp, #-0x10]!");
    
    asm volatile("mov    x29, sp\n\
                  sub    sp, sp, #0xb0");
    
    asm volatile("str    d7, [sp, #0x88]\n\
                  str    d6, [sp, #0x80]\n\
                  str    d5, [sp, #0x78]\n\
                  str    d4, [sp, #0x70]\n\
                  str    d3, [sp, #0x68]\n\
                  str    d2, [sp, #0x60]\n\
                  str    d1, [sp, #0x58]\n\
                  str    d0, [sp, #0x50]\n\
                  str    x8, [sp, #0x40]\n\
                  str    x7, [sp, #0x38]\n\
                  str    x6, [sp, #0x30]\n\
                  str    x5, [sp, #0x28]\n\
                  str    x4, [sp, #0x20]\n\
                  str    x3, [sp, #0x18]\n\
                  str    x2, [sp, #0x10]\n\
                  str    x1, [sp, #0x8]\n\
                  str    x0, [sp]\n\
                  mov    x2, sp\n\
                  add    x3, sp, #0x50\n\
                  add    x4, sp, #0xb0\n\
                  bl     _JOGlobalParamsResolver\n\
                  str    x0, [sp, #0x98]\n\
                  ");
    @autoreleasepool {

        asm volatile("str   x0, [sp, #0x90]");
        asm volatile("ldr   x0, [sp, #0x98]");
        asm volatile("bl    _JOCallJsFunction");

        asm volatile("str   x0, [sp, #0x98]");
        asm volatile("str   d0, [sp, #0xa0]");

        asm volatile("ldr   x0, [sp, #0x90]");
    }
    
    asm volatile("ldr    x0, [sp, 0x98]");
    asm volatile("ldr    d0, [sp, 0xa0]");

    asm volatile("mov    sp, x29");
    asm volatile("ldp    x29, x30, [sp], #0x10");
}

#pragma mark - Get Parameters

//返回每种数据类型的大小
JOINLINE int JOLenWithType(char token) {
    int len = 0;
    switch (token) {
        case 'B':
        case 'c':
        case 'C':  len = 1; break;
        case 's':
        case 'S':  len = 2; break;
        case 'i':
        case 'I':
        case 'f':  len = 4; break;
        case 'l':
        case 'L':
        case 'q':
        case 'Q':
        case 'd':
        case '^':
        case '@':
        case '#':
        case '*':
        case ':':  len = 8; break;
            
    }
    return len;
}

//内存对其计算offset=0x...45b1,align=4,return 0x...45b4
JOINLINE unsigned int JOCalcAlign(unsigned int offset,unsigned align) {
    return ((offset + align - 1) & (~(align - 1)));
}

//计算内存的布局，主要考虑内存对齐(嵌套struct和union暂时没有考虑)
JOINLINE void JOAddTypeInfoToArray(char *ch, int *offset, JOTypeInfoArray *infoArray) {
    int len = JOLenWithType(*ch);
    int newOffset = JOCalcAlign(*offset,len);
    
    JOTypeInfo info = {*ch, len, newOffset - *offset, *offset};
    infoArray->typeArray[infoArray->index++] = info;
    
    newOffset += len;
    *offset = newOffset;
}

//分析struct的类型
JOINLINE void JOAnalyzeStructType(char **pointer, int *offset, JOTypeInfoArray *infoArray) {
    
    *pointer = strchr(*pointer, '=');
    if ( (*pointer)++ != NULL) {
        while (*pointer != '\0') {
            switch (**pointer) {
                case '{': JOAnalyzeStructType(pointer, offset, infoArray); break;
                case '}': ++(*pointer); return;
                case '^': JOAddTypeInfoToArray(*pointer, offset, infoArray); ++(*pointer); ++(*pointer); break;
                default: JOAddTypeInfoToArray(*pointer, offset, infoArray); ++(*pointer); break;
            }
        }
    }
}


JOINLINE id JOGetParam(void **pointer, char* type, int *offset) {
    char *pos = (char *)pointer;
    pos += *offset;
    pointer = (void **)pos;
    switch (type[0]) {
        case '@':
        case '#': {
            if (OS_EXPECT(strlen(type) > 1 && type[1] == '?', 0)) {
                typedef  void (^blockParam)(void);
                blockParam block = (__bridge blockParam)(*pointer);
                return JOPackBlockValue(block);
            } else {
                id obj = JOTOID (*pointer);
                return JOGetObj(obj);
            }
        }
        case 'B': return @((BOOL)*pointer);
        case 'c': return @((char)*(pointer));
        case 'C': return @((unsigned char)*(pointer));
        case 's': return @((short)*(pointer));
        case 'S': return @((unsigned char)*(pointer));
        case 'i': return @((int)*(pointer));
        case 'I': return @((unsigned int)*(pointer));
        case 'l': return @((long)*(pointer));
        case 'L': return @((unsigned long)*(pointer));
        case 'q': return @((long long)*(pointer));
        case 'Q': return @((unsigned long long)*(pointer));
        case 'f': return @((float)*((float *)(pointer)));
        case 'd': return @((double)*((double *)(pointer)));
        case '^':
        case '*': return JOMakePointerObj(*(pointer));
        case ':': return JOMakeSelObj(*(pointer));
        default : return @((unsigned long long)*(pointer));
    }
    
    return nil;
}



//结构体全是同一种浮点数类型才会被放到浮点寄存器中传参
JOINLINE BOOL JOIsOnFloatRegister(JOTypeInfoArray *typeInfoArray, int offset) {
    if (typeInfoArray->count > 4 ||  typeInfoArray->count * 8 + offset > 64) return NO;
    
    char base = 'f';
    for (int i = 0; i < typeInfoArray->index; ++i) {
        const char type = typeInfoArray->typeArray[i].type;
        if (OS_EXPECT(!type, 0)) return NO;
        if (i == 0 && type == 'd') base = 'd';
        if (type != base) return NO;
    }
    return YES;
}
/*  从栈上解析所有的参数，这其实是块连续的空间，这里我为了解析简单，
    将寄存器首地址，浮点寄存器首地址和栈的首地址分别也一起传递，不然偏移量计算比较麻烦
 */
id JOGlobalParamsResolver(__autoreleasing id obj, SEL sel, void **intPointer, void **floatPointer, void **stackPointer) {
    if (!obj) return nil;
    
    int num = 0;
    int initParam = 0;
    BOOL isBlock = NO;
    char *blockType = NULL;
    Method method = NULL;
    
    if (OS_EXPECT([obj isKindOfClass:[NSClassFromString(@"NSBlock") class]], 0)) {
        isBlock = YES;
        
        JOBlock *block = (__bridge JOBlock *)obj;
        blockType = block->sign;
        
        num = (int)strlen(blockType) - 1;
        initParam = 1;
    } else {
        if (!sel) return nil;
        Class class = object_getClass(obj);
        method = class_getInstanceMethod(class, sel);
        num = method_getNumberOfArguments(method);
        initParam = 2;
    }
    
    //寄存器值，浮点寄存器值，原始栈的参数，都在栈上
    int r_offset = isBlock ? 8 : 16;
    int f_offset = 0;
    int s_offset = 0;
    BOOL onStack = NO;
    __autoreleasing NSMutableArray *array = [NSMutableArray array];
    [array addObject:obj];
    if (!isBlock) [array addObject:JOMakeSelObj(sel)];

    for (int i = initParam; i < num; ++i) {
        char name[128] = {0};
        isBlock ? (name[0] = blockType[i+1]) : method_getArgumentType(method, i, name, 128);
        char *type = name;
        *type == 'r' ? ++type : nil;
        
        void **p = intPointer;//默认是寄存器
        int *offset = &r_offset;
        
        if (OS_EXPECT(type[0] == 'd' || type[0] == 'f', 0)) {//取浮点寄存器
            p = floatPointer;
            offset = &f_offset;
        }
        if (OS_EXPECT(onStack, 0)) {//原始栈上的参数
            p = stackPointer;
            offset = &s_offset;
        }
        
        
        if (OS_EXPECT(type[0] == '{', 0)) {
            char *typeTmp = type;
            int offset_struct = 0;
            JOTypeInfoArray tarray = {0};
            JOAnalyzeStructType(&type, &offset_struct, &tarray);
            
            int offset_l = 0;
            JOTypeInfo typeInfo = tarray.typeArray[tarray.count-1];
            int totalMem = typeInfo.offset + typeInfo.length ;
            
            if (JOIsOnFloatRegister(&tarray, f_offset)) {//如果在浮点寄存器上则从浮点寄存器值所在的栈开始偏移读取
                p = floatPointer;
                offset = &f_offset;
            } else if (totalMem > 16 && r_offset < 64) {//如果结构体很大，并且寄存器有至少一个空位，那就是说结构体被放在了原始栈，则先取出寄存器存的指针，再取具体的结构体值
                JOPointerObj *o = JOGetParam(p, "^", offset);
                *offset += 8;
                p = (void **)o.ptr;
                offset = &offset_l;
            } else if (totalMem == 16 && r_offset >= 56) {
                p = stackPointer;
                offset = &s_offset;
            }
            //这里的结构体直接被存储为数组，需要js在使用的时候到对应的位置去取相应的数据
            NSMutableArray *structArray = [NSMutableArray array];
            for (int i = 0; i < tarray.index; ++i) {
                JOTypeInfo info = tarray.typeArray[i];
                *offset = JOCalcAlign(*offset,info.length);
                
                id ret = JOGetParam(p, &(info.type), offset);
                ret ? [structArray addObject:ret] : [structArray addObject:[NSNull null]];
                
                (*offset) += info.length;
            }
            //这里先处理几种常见的结构体，复杂的通用结构体解析比较麻烦，暂不实现
            JODoubleWord6 v = {0};
            for (int i = 0; i < structArray.count; ++i) {
                v.d[i] = [structArray[i] isKindOfClass:NSNumber.class] ? [structArray[i] doubleValue] : 0;
            }

            [array addObject:JOPackStructValue(typeTmp, v) ?: structArray];

        } else {
            int len = JOLenWithType(type[0]);
            *offset = JOCalcAlign(*offset, len);
            id ret = JOGetParam(p , type, offset);
            ret ? [array addObject:ret] : [array addObject:[NSNull null]];
            if (OS_EXPECT(onStack, 0)) {//在原始栈上，需要考虑内存对齐，否则直接跳过一个寄存器的大小8Byte
                *offset += len;
            } else {
                *offset += 8;
            }
        }
        if (OS_EXPECT(r_offset >= 64, 0)) {//寄存器用完，则剩下的参数在栈上
            onStack = YES;
        }
    }
//    JOLog(@"param:%@", array);
    return array;
}

void JOConstructReturnValue(__autoreleasing JSValue *ret, char type) {
    switch (type) {
        case 'v': { asm volatile("mov  x0, #0x0");
                    asm volatile("movi  d0, #0x0");
                    asm volatile("movi  d1, #0x0");
                    asm volatile("movi  d2, #0x0");
                    asm volatile("movi  d3, #0x0"); break;}
        case 'B': { BOOL r = [ret toBool];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'c': { char r = [[ret toObject] charValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'C': { Byte r = [[ret toObject] unsignedCharValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 's': { short r = [[ret toObject] shortValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'S':{ unsigned short r = [[ret toObject] unsignedShortValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; };
        case 'i': { int r = [[ret toObject] intValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'I': { unsigned int r = [[ret toObject] unsignedIntValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'l': { long r = [[ret toObject] longValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'L': { unsigned long r = [[ret toObject] unsignedLongValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'q': { long r = [[ret toObject] longLongValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'Q': { unsigned long long r = [[ret toObject] unsignedLongLongValue];
                    asm volatile("ldr  x0, %0": "=m"(r)); break; }
        case 'f': { float r = [[ret toObject] floatValue];
                    asm volatile("ldr  s0, %0": "=m"(r)); break; }
        case 'd': { double r = [[ret toObject] doubleValue];
                    asm volatile("ldr  d0, %0": "=m"(r)); break; }
        case '#':
        case '@': {
            __autoreleasing id obj = JOUnmakeWeakOrObj([ret toObject]).obj;
            asm volatile("ldr  x0, %0": "=m"(obj));
            break;
        }
        case '^':
        case '*':
        case ':': {
            void *r = JOUnmakePointerOrSelObj([ret toObject]).ptr;
            asm volatile("ldr  x0, %0": "=m"(r));
            break;
        }
        case '{': {
            //结构体比较坑，以后处理
        }
        default: break;
    }
}

#pragma mark - Call Js Function
/*  解析参数完成后，使用内联汇编调用本函数，本函数将会调用js的对应实现，同时将js的返回值转换成对应的OC数据类型
 */
void  JOCallJsFunction(__autoreleasing NSArray *params) {
    if (params.count < 2) return;
    
    pthread_mutex_lock(&_JOSwizzleLock);
    __autoreleasing JSValue *preSelf = [JOBridge jsContext][@"self"];
    __autoreleasing JSValue *precmd = [JOBridge jsContext][@"_cmd"];
    [JOBridge jsContext][@"self"] = JOGetObj(params.firstObject);
    [JOBridge jsContext][@"_cmd"] = (JOSelObj *)params[1];

    if (JOBridge.isDebug) {
        JOLog(@"CallJsFunction : %@",NSStringFromSelector(((JOSelObj *)params[1]).sel));
    }
    __autoreleasing JSValue *jsFunc = JOSearchJsMethod([params.firstObject class], NSStringFromSelector(((JOSelObj *)params[1]).sel));
    
    __autoreleasing JSValue *ret = [jsFunc callWithArguments:[params subarrayWithRange:(NSRange){2, params.count - 2}]];
    [JOBridge jsContext][@"self"] = preSelf;
    [JOBridge jsContext][@"_cmd"] = precmd;
    pthread_mutex_unlock(&_JOSwizzleLock);

    Class class = object_getClass(params.firstObject);
    Method method = class_getInstanceMethod(class, ((JOSelObj *)params[1]).sel);
    char type[128] = {0};
    method_getReturnType(method, type, 128);
    JOConstructReturnValue(ret, type[0]);//此句最好在方法的最末

}
#endif
