//
//  JOBridge.m
//  JOBridge
//
//  Created by Wei on 2018/9/12.
//  Copyright © 2018年 Wei. All rights reserved.
//
#import "JOBridge.h"

#if __arm64__

#import <objc/runtime.h>
#import "JOTools.h"
#import "JOClass.h"
#import "JOSwizzle.h"
#import "JOObject.h"
#import <objc/message.h>
#import "JOCFunction.h"
#import "JOBlock.h"
#import "JOInvocation.h"
#import <pthread.h>
#import <os/base.h>

#define JO_UIKit_Classes @[@"UIImage",@"UIColor",@"UIView",@"UITableView",@"UILabel",@"UIButton",\
@"UIImageView",@"UIApplication",@"UITableViewCell",@"UIAlertView",@"UINavigationController",\
@"UIViewController",@"UIFont",@"UIScreen",@"UIScrollView",@"UINavigationItem",@"UINavigationBar",\
@"UIWebView",@"UIWindow",@"UITextView",@"UITextField",@"UITapGestureRecognizer",@"UITabBarController",\
@"UITabBar",@"UISwitch",@"UISlider",@"UISearchBar",@"UIProgressView",@"UICollectionView",\
@"UICollectionViewCell",@"UIBarButtonItem",@"UIAppearance",@"UIAlertController"]

#define JO_Foundation_Classes @[@"NSTimer",@"NSMutableArray",@"NSArray",@"NSDictionary",@"NSMutableDictionary",\
@"NSString",@"NSUserDefaults",@"NSURL",@"NSURLRequest",@"NSData",@"NSDate",@"NSCharacterSet",@"NSMutableString",\
@"NSDateFormatter",@"NSError",@"NSException",@"NSFileManager",@"NSJSONSerialization",@"NSLock",@"NSNotification",\
@"NSRegularExpression",@"NSSet",@"NSThread",@"NSURLResponse",@"NSValue",@"NSAttributedString",@"NSURLSession",\
@"NSPredicate",@"NSTask",@"NSLocale",@"NSInvocation",@"NSMethodSignature",@"NSMutableAttributedString",@"NSBundle"]

static char *JOGetSelector(const char *selName, BOOL *isSuper, BOOL *isVariableParam, JSValue *sign, char **variableSign);
static void JOParamsResolver(void *params[], NSMethodSignature *sign, NSInvocation *invoke, int initIndex);
static id JOPackJsFunction(NSString *signString, JSValue *jsFunction);
static id JOGetReturnValue(NSMethodSignature *sign, NSInvocation *invoke, id obj, SEL sel);

id JOPackBlockValue(void (^returnBlock)(void));
id JOPackStructValue(const char *type, JODoubleWord6 v);

static void JOManualParamsResolverAndCall(__unsafe_unretained id obj, SEL sel, char *variableSign , void *params[], int option);
static void JOGetManualCall(IMP imp, NSUInteger stackCount, NSUInteger stackOffset, void *stackPtr, void **paramArrayPtr, void **paramFloatArrayPtr);
static id JOGetManualReturnValue(void *returnPtr, char type);


typedef NSValue *(^JOStructPacker)(JODoubleWord6 v);
typedef void (^JOStructUnpacker)(JODoubleWord6 *v, NSValue *value);

static JSContext *_JOJsContext;
static NSMutableArray *_JOPlugins;
static NSDictionary *_JOStructPackers;
static NSDictionary *_JOStructUnpackers;
static pthread_mutex_t _JOPluginsLock;
static pthread_mutex_t _JOBridgeLock;
static void *_JOParamBlockIMP;
static BOOL JOIsDebug;


#pragma mark - JOBridge Define

@interface JOBridge()
//@property (atomic, strong, class) JSContext *jsContext;
@end


@implementation JOBridge
+ (JSContext *)jsContext {
    return _JOJsContext;
}
+ (void)setJsContext:(JSContext *)jsContext {
    _JOJsContext = jsContext;
}
+ (BOOL)isDebug {
    return JOIsDebug;
}
+ (void)setIsDebug:(BOOL)isDebug {
    JOIsDebug = isDebug;
}


+ (void)bridge {
    if (_JOJsContext) return;
    
    pthread_mutexattr_t *attribute = malloc(sizeof(pthread_mutexattr_t));
    pthread_mutexattr_settype(attribute, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&_JOBridgeLock, attribute);
    free(attribute);
    
    pthread_mutex_init(&_JOPluginsLock, NULL);

    _JOJsContext = [JSContext new];
    
    [self register];
    
    NSArray *pluginCopy = [_JOPlugins copy];
    for (id obj in pluginCopy) {
        if ([obj respondsToSelector:@selector(initPlugin)]) {
            [obj initPlugin];
        }
    }
}

+ (void)registerPlugin:(id)obj {
    if (!_JOPlugins) {
        _JOPlugins = [NSMutableArray array];
    }
    
    pthread_mutex_lock(&_JOPluginsLock);
    [_JOPlugins addObject:obj];
    pthread_mutex_unlock(&_JOPluginsLock);
    
    if (_JOJsContext) {
        if ([obj respondsToSelector:@selector(initPlugin)]) {
            [obj initPlugin];
        }
    }
}


+ (void)addObject:(id)obj forKey:(NSString *)key needTransform:(BOOL)tans {
    pthread_mutex_lock(&_JOPluginsLock);
    if (key && obj) {
        _JOJsContext[key] = obj;
        if (!tans) {
            _JOTransformKey = [_JOTransformKey stringByAppendingFormat:@"|%@", key];
        }
    }
    pthread_mutex_unlock(&_JOPluginsLock);
}

+ (id)objectForKey:(NSString *)key {
    return key ? _JOJsContext[key] : nil;
}

+ (void)register {
    
    NSArray *classArray = [JO_UIKit_Classes arrayByAddingObjectsFromArray:JO_Foundation_Classes];
    for (NSString *classString in classArray) {
        Class class = NSClassFromString(classString);
        JOObj *obj = JOMakeObj(class);
        self.jsContext[classString] = obj;
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"interface"] = ^(JSValue *className, JSValue *properties, JSValue *classMethods, JSValue *metaClassMethods) {
        JOClassParser(className, properties, classMethods, metaClassMethods);
    };
    dict[@"log"] = ^(JSValue *jsValue) {
        JOLog(@"JS_LOG:%@",[jsValue toObject]);
    };
    dict[@"class"] = ^id (JSValue *jsValue) {
        NSString *classString = [jsValue toString];
        Class class = NSClassFromString(classString);
        if (class) {
            JOObj *obj = JOMakeObj(class);
            [JSContext currentContext][classString] = obj;
            return obj;
        }
        return [NSNull null];
    };
    dict[@"storeObject"] = ^(JSValue *orgin, JSValue *target) {
        id orignObj = [orgin toObject];
        if (JOUnmakeWeakOrObj(orignObj).obj == orignObj) {
            return;
        }
        [orignObj setObj:JOUnmakeWeakOrObj([target toObject]).obj];
    };
    
    dict[@"selector"] = ^id (JSValue *jsValue) {
        return JOMakeSelObj(NSSelectorFromString([jsValue toString]));
    };
    dict[@"array"] = ^id (JSValue *jsValue) {
        NSArray *array = [jsValue toArray];
        NSMutableArray *arr = [NSMutableArray array];
        for (JSValue *obj in array) {
            if ([obj isKindOfClass:[JSValue class]]) {
                [arr addObject:[obj toObject]];
            } else {
                [arr addObject:JOUnmakeWeakOrObj(obj).obj];
            }
        }
        return JOGetObj([arr copy]);
    };
    dict[@"new"] = ^id (JSValue *jsValue) {
        return JOGetObj([NSClassFromString([jsValue toString]) new]);
    };
    dict[@"retain"] = ^(JSValue *jsValue) {
        id obj = JOUnmakeWeakOrObj([jsValue toObject]).obj;
        if ([obj isKindOfClass:[NSObject class]]) {
            JOTools.retain(obj);
        }
    };
    dict[@"release"] = ^(JSValue *jsValue) {
        id obj = JOUnmakeWeakOrObj([jsValue toObject]).obj;
        if ([obj isKindOfClass:[NSObject class]]) {
            JOTools.release(obj);
        }
    };
    dict[@"structToObject"] = ^id (JSValue *jsValue) {
        id v = jsValue;
        if ([jsValue isKindOfClass:[jsValue class]]) {
            v = [jsValue toObject];
        }
        if ([v isKindOfClass:[NSValue class]]) {
            if (!strcmp(@encode(CGRect), [v objCType])) {
                return [JSValue valueWithRect:[v CGRectValue] inContext:[JSContext currentContext]];
            } else if (!strcmp(@encode(CGPoint), [v objCType])) {
                return [JSValue valueWithPoint:[v CGPointValue] inContext:[JSContext currentContext]];
            } else if (!strcmp(@encode(CGSize), [v objCType])) {
                return [JSValue valueWithSize:[v CGSizeValue] inContext:[JSContext currentContext]];
            } else if (!strcmp(@encode(NSRange), [v objCType])) {
                return [JSValue valueWithRange:[v rangeValue] inContext:[JSContext currentContext]];
            } else if (!strcmp(@encode(CGAffineTransform), [v objCType])) {
                CGAffineTransform t = [v CGAffineTransformValue];
                return @{@"a": @(t.a),
                         @"b": @(t.b),
                         @"c": @(t.c),
                         @"d": @(t.d),
                         @"tx": @(t.tx),
                         @"ty": @(t.ty)};
                
            } else if (!strcmp(@encode(UIEdgeInsets), [v objCType])) {
                UIEdgeInsets e = [v UIEdgeInsetsValue];
                return @{@"top": @(e.top),
                         @"left": @(e.left),
                         @"bottom": @(e.bottom),
                         @"right": @(e.right)};
                
            } else if (!strcmp(@encode(UIOffset), [v objCType])) {
                UIOffset o = [v UIOffsetValue];
                return @{@"horizontal": @(o.horizontal),
                         @"vertical": @(o.vertical)};
                
            }
        }
        return nil;
    };
    dict[@"catch"] = ^(JSValue *message, JSValue *stack) {
        NSAssert(NO, @"JS EXCEPTION: \nmsg: %@, \nstack: \n %@", [message toObject], [stack toObject]);
    };
    dict[@"getString"] = ^id (JSValue *jsValue) {
        id obj = [jsValue toObject];
        if (JOTools.isNull(obj)) return [NSNull null];
        
        return [obj obj];
    };
    dict[@"num"] = ^id (JSValue *jsValue) {
        id obj = [jsValue toObject];
        if (JOTools.isNull(jsValue)) return [NSNull null];
        return @([obj integerValue]);
    };
    
    dict[@"getPointerValue"] = ^id (JSValue *value) {
        NSInteger *val = JOUnmakePointerOrSelObj([value toObject]).ptr;
        return val ? @(*val) : [NSNull null];
    };
    dict[@"setPointerValue"] = ^(JSValue *ptr, JSValue *value) {
        NSInteger *val = JOUnmakePointerOrSelObj([ptr toObject]).ptr;
        if (val) {
            *val = [[value toObject] longLongValue];
        }
    };
    dict[@"getPointerDoubleValue"] = ^id (JSValue *value) {
        double *val = JOUnmakePointerOrSelObj([value toObject]).ptr;
        return val ? @(*val) : [NSNull null];
    };
    dict[@"setPointerDoubleValue"] = ^(JSValue *ptr, JSValue *value) {
        double *val = JOUnmakePointerOrSelObj([ptr toObject]).ptr;
        id obj = [value toObject];
        if (val && !JOTools.isNull(obj)) {
            *val = [obj doubleValue];
        }
    };
    
    dict[@"malloc"] = ^id (JSValue *value) {
        NSUInteger size = [value toUInt32];
        if (size > 0) {
            void *p = malloc(size);
            if (p) {
                return JOMakePointerObj(p);
            }
        }
        return [NSNull null];
    };
    dict[@"free"] = ^(JSValue *value) {
        id obj = [value toObject];
        void *val = JOUnmakePointerOrSelObj(obj).ptr;
        if (val) {
            [obj setPtr:NULL];
            free(val);
        }
    };
    dict[@"getAddress"] = ^id (JSValue *value) {
        void *p = JOUnmakePointerOrSelObj([value toObject]).ptr;
        return p ? JOMakePointerObj(p) : [NSNull null];
    };
    
    self.jsContext[@"JOC"] = dict;
    
    self.jsContext.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        JOLog(@"JS_Exception:%@",exception);
    };
    
    
    
    
    self.jsContext[@"__weak"] = ^id (JSValue *jsvalue) {
        return JOMakeWeakObj(JOUnmakeWeakOrObj([jsvalue toObject]).obj);
    };
    
    self.jsContext[@"__strong"] = ^(JSValue *jsvalue) {
        return JOGetObj(JOUnmakeWeakOrObj([jsvalue toObject]).obj);
    };
    
    self.jsContext[@"__bridge_id"] = ^id (JSValue *ptr) {
        void *p = JOUnmakePointerOrSelObj([ptr toObject]).ptr;
        return p ? JOGetObj(JOTOID p) : [NSNull null];
    };
    self.jsContext[@"__bridge_pointer"] = ^id (JSValue *ptr) {
        id o = [ptr toObject];
        id obj = JOUnmakeWeakOrObj(o).obj;
        if (obj != o) {
            return JOMakePointerObj(JOTOPTR obj);
        }
        return [NSNull null];
    };
    
    /*  给js的根类添加一个_oc_方法（或者说一个属性吧），其返回了一个block，block第一个参数是selector名称，同时在上下文获取currentThis，
     从中取出obj，余下的参数则在后面，最多支持十个（当然也可以通过预处理js将参数打包成数组就可以支持任意长度了）。js调用会被预处理，
     举个例子tableView.setDelegate_(self)，会被转成tableView._oc_('setDelegate_',self)。当然也可以使用其他的语法。
     在调用原生方法的时候我偷了一下懒，使用了NSInvocation。也可以像获取任意参数一样，强制写入参数到寄存器栈来调用objc_msgSend
     （当然也可以直接调用其实现，但可能没有objc_msgSend的缓存效果），就是有点麻烦，后续有时间再改。
     */
    [self.jsContext[@"Object"][@"prototype"] defineProperty:@"_oc_" descriptor:@{JSPropertyDescriptorValueKey:^id (JSValue *selName, __unsafe_unretained JSValue *p0, __unsafe_unretained JSValue *p1, __unsafe_unretained JSValue *p2,  __unsafe_unretained JSValue *p3, __unsafe_unretained JSValue *p4, __unsafe_unretained JSValue *p5, __unsafe_unretained JSValue *p6, __unsafe_unretained JSValue *p7, __unsafe_unretained JSValue *p8, __unsafe_unretained JSValue *p9, __unsafe_unretained JSValue *p10, __unsafe_unretained JSValue *p11, __unsafe_unretained JSValue *p12) {
        
        BOOL isSuper = NO;
        BOOL isVariableParam = NO;
        char *variableSign = NULL;
        
        const char *selNameChar = [selName toString].UTF8String;
        char *selNameCopy = JOGetSelector(selNameChar, &isSuper, &isVariableParam, p0, &variableSign);
        if (OS_EXPECT(!selNameCopy || (isVariableParam && !variableSign), 0)) return [NSNull null];

        SEL sel = NSSelectorFromString([NSString stringWithUTF8String:selNameCopy]);
        free(selNameCopy);
        
        id obj = nil;
        JSValue *jsThis = [JSContext currentThis];
        if (OS_EXPECT([jsThis isInstanceOf:[JSContext currentContext][@"String"]], 0)) {//JSValue的isString无效
            obj = [jsThis toString];
        } else {
            obj = [jsThis toObject];
            __unsafe_unretained id targetObj = JOUnmakeWeakOrObj(obj).obj;
            NSAssert(obj, @"调用者容器不能为空");
            if (OS_EXPECT(!targetObj || targetObj == obj, 0)) {
                return [NSNull null];
            }
            obj = targetObj;
        }
        if (JOBridge.isDebug) {
            JOLog(@"CallNativeFunction : %@", NSStringFromSelector(sel));
        }
        
        //栈参的存储顺序和并非按照p0-p12顺序，所以不能复用栈来作为数组，需要单独创建一个数组。使用c数组，减少retain，releas操作
        void *params[] = {JOTOPTR p0, JOTOPTR p1, JOTOPTR p2, JOTOPTR p3,
            JOTOPTR p4, JOTOPTR p5, JOTOPTR p6, JOTOPTR p7, JOTOPTR p8,
            JOTOPTR p9, JOTOPTR p10, JOTOPTR p11, JOTOPTR p12};//创建c数组，提高性能

        /*  非常fuck可变参数方法调用，可变参数调用中，匿名参数是存储在栈上的，非匿名参数存在寄存器上。
            NSInvocation开放的接口无法指定参数的存放位置，因此没法复用下面的NSInvocation调用体系，
            因此不得不手动解析参数，再写一套参数解析和返回值解析代码，虽然大同小异，但想想就fuck。
            OC不支持可变参数方法的，需要使用C来处理，也就是这类方法的签名不完整，我这里使用JS显式签名，
            让OC可以处理剩下的参数并将其放入栈上
            option=1父类方法调用，option=0正常调用，其他可变参数调用
         */
        if (OS_EXPECT(isVariableParam, 0)) {
            typedef void *(*ManualMethod)(id, SEL, const char *, void **, int);
            ManualMethod manualMethod = (ManualMethod)JOManualParamsResolverAndCall;
            return JOGetManualReturnValue(manualMethod(obj, sel, variableSign, params, 2), variableSign[0]);
        }
        if (OS_EXPECT(isSuper, 0)) {
            typedef void *(*ManualMethod)(id, SEL, const char *, void **, int);
            ManualMethod manualMethod = (ManualMethod)JOManualParamsResolverAndCall;
            char retType[64] = {0};
            return JOGetManualReturnValue(manualMethod(obj, sel, retType, params, 1), retType[0]);
        }
        if ([NSStringFromSelector(sel) isEqualToString:@"ltvOpenAccountStatus"]) {
            
        }
        NSInvocation *invoke = JOGetInvocation(obj, sel);
        NSMethodSignature *sign = [invoke methodSignature];
        NSAssert(sign, ([NSString stringWithFormat:@"'%@' 没有 '%@' 方法", NSStringFromClass([obj class]), NSStringFromSelector(sel)]));
        
        [invoke setTarget:obj];
        [invoke setSelector:sel];

        JOParamsResolver(params, sign, invoke, 2);


//        static NSMutableArray *level = nil;
//        if (!level) { level =[NSMutableArray array];}
//
//        static double time = 0;
//        double begin = CFAbsoluteTimeGetCurrent();
//        NSString *sel1 = NSStringFromSelector(sel);
//        [level addObject:sel1];
        
        [invoke invoke];
        
//        double end = CFAbsoluteTimeGetCurrent();
//        if (level.firstObject == sel1) {
//            time += end - begin;
//            NSLog(@"all time : %f", time);
//        }
//        [level removeLastObject];


        const char *type = [sign methodReturnType];
        *type == 'r' ? ++type : nil;

        if (OS_EXPECT(!strcmp(type, "@?"), 0)) {
            __autoreleasing void (^returnBlock)();
            [invoke getReturnValue:&returnBlock];
            /*  此处需要特别注意，js中想要获取了一个原生block，但原生returnBlock不会直接传给js，
                这里会再创建一个block传给js，并在该block中调用returnBlock。
             */
            return JOPackBlockValue(returnBlock);
        }
        return JOGetReturnValue(sign, invoke, obj, sel);
    }, JSPropertyDescriptorConfigurableKey:@(NO), JSPropertyDescriptorEnumerableKey:@(NO)}];
}

static NSString *_JOTransformKey = @"|JOC";
static NSString *_JOMatchString = @"(?<!\\\\%@)\\.\\s*(\\w+)\\s*\\(";
static NSString *_JOReplaceString = @"._oc_(\"$1\",";//这里直接将selector作为第一个参数，减少一次调用

//这坨代码从JSPatch中copy的，正则表达式做了一些修改，以支持我定义的语法
+ (void)evaluateScript:(NSString *)script {
    
    [self bridge];
    if (!script) return;
    
    NSString *matchStr = [NSString stringWithFormat:_JOMatchString, _JOTransformKey];
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:matchStr options:0 error:nil];
    NSString *formatedScript = [NSString stringWithFormat:@"try{%@}catch(e){JOC.catch(e.message, e.stack)}", [regular stringByReplacingMatchesInString:script options:0 range:NSMakeRange(0, script.length) withTemplate:_JOReplaceString]];
//    JOLog(@"%@",formatedScript);
    [self.jsContext evaluateScript:formatedScript];
}
@end

#pragma mark -

static char *JOGetSelector(const char *selName, BOOL *isSuper, BOOL *isVariableParam, JSValue *sign, char **variableSign) {
    
    const char *tmp = selName;
    if (OS_EXPECT(!strncmp(selName, "JOSUPER_", 8), 0)) {
        tmp = selName + 8;
        *isSuper = YES;
    }
    
    if (OS_EXPECT(!strncmp(selName, "JOVAR_", 6), 0)) {
        tmp = selName + 6;
        *variableSign = (char *)[sign toString].UTF8String;
        if (strlen(*variableSign) < 2)  return NULL;
        *isVariableParam = YES;
    }
    
    size_t len = strlen(tmp);
    if (len < 0 ) return NULL;
    
    char *copy = malloc(len + 1);
    for (int i = 0, j = 0; i < len + 1; ++i, ++j) {
        if (tmp[i] == '_') {
            if (i < len && tmp[i+1] == '_') {
                copy[j] = tmp[i];
                ++i;
            } else {
                copy[j] = ':';
            }
        } else {
            copy[j] = tmp[i];
        }
    }
    return copy;
}

id JOPackBlockValue(void (^block)(void)) {
    /*  JOParamsResolver中定义的特殊block的签名在捕获的参数中，原始签名无效，其他block则加载原始签名。
        根据其实现函数的入口地址判断是否为该特殊block，如果是特殊block也就不用再包一层block了，直接将
        特殊block捕获的js function返回给js调用。
        note:本函数只能作为给js提供block的时候使用。
     */
    JOBlock *blockPtr =  (__bridge JOBlock *)block;
    if (_JOParamBlockIMP == blockPtr->BlockFunctionPtr) {
        return blockPtr->jsFunction;
    }
    
    return ^id (__unsafe_unretained JSValue *p0, __unsafe_unretained JSValue *p1, __unsafe_unretained JSValue *p2, __unsafe_unretained JSValue *p3, __unsafe_unretained JSValue *p4, __unsafe_unretained JSValue *p5, __unsafe_unretained JSValue *p6, __unsafe_unretained JSValue *p7) {
        __autoreleasing id obj = block;
        char *blockType = NULL;
        char **pType = &blockType;
        asm volatile("ldr    x0, %0" : "=m"(obj));
        asm volatile("ldr    x8, [x0, 0x18]");
        asm volatile("add    x1, x8, 0x10");
        asm volatile("add    x2, x8, 0x20");
        asm volatile("ldr    w3, [x0, 0x8]");
        asm volatile("tst    w3, #0x2000000");
        asm volatile("csel   x2, x1, x2, eq");
        asm volatile("ldr    x0, %0": "=m"(pType));
        asm volatile("ldr    x2, [x2]");
        asm volatile("str    x2, [x0]" );
        
        /*  取出block签名，手动解析起来比较麻烦，这里利用NSMethodSignature解析后，利用NSInvocationa来调用，
            可以复用JOParamsResolver，JOGetReturnValue俩函数
         */
        NSMethodSignature *sign = [NSMethodSignature signatureWithObjCTypes:blockType];
        NSInvocation *invoke = [NSInvocation invocationWithMethodSignature:sign];
        void *params[] = {JOTOPTR p0, JOTOPTR p1, JOTOPTR p2, JOTOPTR p3,
            JOTOPTR p4, JOTOPTR p5, JOTOPTR p6, JOTOPTR p7};
        [invoke setTarget:obj];
        JOParamsResolver(params, sign, invoke, 1);
        
        [invoke invoke];
        
        return JOGetReturnValue(sign, invoke, nil, NULL);
    };
}

id JOPackStructValue(const char *type, JODoubleWord6 v) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _JOStructPackers = @{@"{CGRect={CGPoint=dd}{CGSize=dd}}" : ^(JODoubleWord6 v){ return @(v.boxRect);},
                             @"{CGPoint=dd}": ^(JODoubleWord6 v){ return @(v.boxPoint);},
                             @"{CGSize=dd}": ^(JODoubleWord6 v){ return @(v.boxSize);},
                             @"{_NSRange=QQ}": ^(JODoubleWord6 v){ return @(v.boxRange);},
                             @"{CGAffineTransform=dddddd}": ^(JODoubleWord6 v){ return @(v.boxAffineTransform);},
                             @"{UIEdgeInsets=dddd}": ^(JODoubleWord6 v){ return @(v.boxEdgeInsets);},
                             @"{UIOffset=dd}": ^(JODoubleWord6 v){ return @(v.boxOffset);},
                             };
    });

    __unsafe_unretained JOStructPacker packer = _JOStructPackers[[NSString stringWithUTF8String:type]];
    if (packer) {
        return packer(v);
    }
    return nil;
}

static void JOUnpackStructValue(const char *type, JODoubleWord6 *p, __unsafe_unretained NSValue *value) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _JOStructUnpackers = @{@"{CGRect={CGPoint=dd}{CGSize=dd}}" : ^(JODoubleWord6 *p, NSValue *value){ return p->rect = [value CGRectValue];},
                             @"{CGPoint=dd}": ^(JODoubleWord6 *p, NSValue *value){ return p->point = [value CGPointValue];},
                             @"{CGSize=dd}": ^(JODoubleWord6 *p, NSValue *value){ return p->size = [value CGSizeValue];},
                             @"{_NSRange=QQ}": ^(JODoubleWord6 *p, NSValue *value){ return p->range = [value rangeValue];},
                             @"{CGAffineTransform=dddddd}": ^(JODoubleWord6 *p, NSValue *value){ return p->affineTransform = [value CGAffineTransformValue];},
                             @"{UIEdgeInsets=dddd}": ^(JODoubleWord6 *p, NSValue *value){ return p->edgeInsets = [value UIEdgeInsetsValue];},
                             @"{UIOffset=dd}": ^(JODoubleWord6 *p, NSValue *value){ return p->offset = [value UIOffsetValue];},
                             };
    });
    __unsafe_unretained JOStructUnpacker unpacker = _JOStructUnpackers[[NSString stringWithUTF8String:type]];
    if (unpacker && value) {
        unpacker(p, value);
    }
}

//该函数可能有返回值
static void JOManualParamsResolverAndCall(__unsafe_unretained id obj, SEL sel, char *paramsSign , void *params[], int option) {
    BOOL regularCall = option == 0 || option == 1;
    BOOL superCall = option == 1;

    __unsafe_unretained Class class = object_getClass(obj);
    if (superCall) {
        class = [obj superclass];//不要使用class_getSuperclass，其可能会返回KVO的Class
    }
    /*  class_getMethodImplementation会调用lookUpImpOrNil->lookUpImpOrForward->cache_getImp，
        cache_getImp由汇编实现，其也会走objc_msgSend缓存
     */
    void *imp = class_getMethodImplementation(class, sel);
    __autoreleasing NSMethodSignature *orignSign = [obj methodSignatureForSelector:sel];
    
    NSUInteger orignCount = [orignSign numberOfArguments];
    NSUInteger count = 0;
    if (regularCall) {
        count = orignCount;
        NSInteger frameLength = orignSign.frameLength;
        if (frameLength > 0xe0) {
            if ((frameLength - 0xe0)%8) {
                orignCount = count - (frameLength - 0xe0)/8 - 1;
            } else {
                orignCount = count - (frameLength - 0xe0)/8;
            }
        }
        memcpy(paramsSign, [orignSign methodReturnType], 64);
    } else {
        orignCount = orignCount > 8 ? 8 : orignCount;
        count = strlen(paramsSign) - 1;
    }
    
    void *paramArray[12] = {0};
    void *paramFloatArray[12] = {0};
    paramArray[0] = JOTOPTR obj;
    paramArray[1] = sel;
    
    for (int i = 2, j = 0; i < count; ++i) {
        const char *types = regularCall ? [orignSign getArgumentTypeAtIndex:i] : NULL;
        char type = regularCall ? types[0] : paramsSign[i + 1];
        __unsafe_unretained id param = JOTOID params[regularCall ? i-2 : i-1];
        switch(type) {
            case 'B':
            case 'c':
            case 'C':
            case 's':
            case 'S':
            case 'i':
            case 'I':
            case 'l':
            case 'q': { long long v = [[param toNumber] longLongValue];
                paramArray[i] = (void *)(NSUInteger)v; break;}
            case 'L':
            case 'Q': { unsigned long long v = [[param toNumber] unsignedLongLongValue];
                paramArray[i] = (void *)(NSUInteger)v; break;}
            case 'f': {
                float v = [[param toNumber] floatValue];
                if (regularCall) {
                    float *p = (float *)(paramFloatArray + j++); *p = v;
                } else {
                    float *p = (float *)(paramArray + i); *p = v;
                }
                break;
            }
            case 'd': {
                double v = [param toDouble];
                if (regularCall) {
                    double *p = (double *)(paramFloatArray + j++); *p = v;
                } else {
                    double *p = (double *)(paramArray + i); *p = v;
                }
                break;
            }
            case '^':
            case '*':
            case ':':
            case '#':
            case '@': {
                paramArray[i] = JOUnmakeAnyObj([param toObject]).ptr;
                break;
            }
            case '{': {
                JODoubleWord6 *vp = (JODoubleWord6 *)(paramFloatArray + j);;
                JOUnpackStructValue(types, vp, [param toObject]);
                break;
            }
        }
    }
    
    /* 这里的解决办法是通过建立伪栈来解决栈参数传递 */
    NSUInteger stackCount = count - orignCount;
    //这里要16Byte对齐，原因是很多被调用函数都会使用stp来压栈x29,x30，如果sp不是16Byte对齐，就会凉凉
    NSUInteger stackOffset = (stackCount % 2 ? stackCount + 1 : stackCount);
    void *stackPtr = paramArray + orignCount;
    void **paramArrayPtr = (void **)&paramArray;
    void **paramFloatArrayPtr = (void **)&paramFloatArray;
    
    JOGetManualCall(imp, stackCount, stackOffset, stackPtr, paramArrayPtr, paramFloatArrayPtr);
}

void JOManualPlaceholder() JOPTNONE {
}

static void JOGetManualCall(IMP imp, NSUInteger stackCount, NSUInteger stackOffset, void *stackPtr, void **paramArrayPtr, void **paramFloatArrayPtr) JOPTNONE {
    /*  fuck，本函数必须调用一个函数，否者Xcode不会插入stp   x29, x30, [sp, #-0x10]!之类的汇编来暂存fp，lr寄存器到栈上。
        我这里构造了一个空函数，同时禁止编译器优化，才可以完成想要的功能。
        当然这不是唯一办法，比如构造桩函数，直接用汇编完成也是可以的
     */
    JOManualPlaceholder();

    asm volatile("ldr    x17, %0" : "=m"(imp));
    //初始化
    asm volatile("ldr    x10, %0" : "=m"(stackCount));
    asm volatile("ldr    x11, %0" : "=m"(stackOffset));
    asm volatile("lsl    x11, x11, #0x3");//x11 * 8
    asm volatile("ldr    x12, %0" : "=m"(stackPtr));
    //循环拷贝参数到伪栈上
    asm volatile("sub    x15, sp, x11");
    asm volatile("LZW_20181202:");
    asm volatile("cbz    x10, LZW_20181203");
    asm volatile("ldr    x0, [x12]");
    asm volatile("str    x0, [x15]");
    asm volatile("add    x15, x15, #0x8");
    asm volatile("add    x12, x12, #0x8");
    asm volatile("sub    x10, x10, #0x1");
    asm volatile("cbnz   x10, LZW_20181202");
    asm volatile("LZW_20181203:");
    //加载寄存器参数，这里懒得计算寄存器参数个数，直接9+8个寄存器都加载
    asm volatile("ldr    x12, %0" : "=m"(paramArrayPtr));
    asm volatile("ldr    x13, %0" : "=m"(paramFloatArrayPtr));
    asm volatile("ldr    x0, [x12]");
    asm volatile("ldr    x1, [x12, 0x8]");
    asm volatile("ldr    x2, [x12, 0x10]");
    asm volatile("ldr    x3, [x12, 0x18]");
    asm volatile("ldr    x4, [x12, 0x20]");
    asm volatile("ldr    x5, [x12, 0x28]");
    asm volatile("ldr    x6, [x12, 0x30]");
    asm volatile("ldr    x7, [x12, 0x38]");
    asm volatile("ldr    x8, [x12, 0x40]");
    asm volatile("ldr    d0, [x13]");
    asm volatile("ldr    d1, [x13, 0x8]");
    asm volatile("ldr    d2, [x13, 0x10]");
    asm volatile("ldr    d3, [x13, 0x18]");
    asm volatile("ldr    d4, [x13, 0x20]");
    asm volatile("ldr    d5, [x13, 0x28]");
    asm volatile("ldr    d6, [x13, 0x30]");
    asm volatile("ldr    d7, [x13, 0x38]");
    
    
    asm volatile("sub    sp, sp, x11");
    asm volatile("blr    x17");
    //如果增删了局部变量，0x30可能会变，这个大小可以到函数汇编代码入口中找，其等于fp(x29)-sp
    asm volatile("sub    sp, x29, #0x30");
}


static id JOGetManualReturnValue(void *returnPtr, char type) {
    int bits = 0;
    switch (type) {
        case 'v': return [NSNull null];
        case 'B':
        case 'c':
        case 'C': bits += 8;
        case 's':
        case 'S': bits += 16;
        case 'i':
        case 'I': bits += 32;
        case 'l':
        case 'q': { NSInteger value = (NSInteger)returnPtr; value = (value << bits) >> bits; return @(value);}
        case 'L':
        case 'Q': { NSUInteger value = (NSUInteger)returnPtr; return @(value);}
        case 'f': { float *p = (float *)&returnPtr; return @(*p);}
        case 'd': { double *p = (double *)&returnPtr; return @(*p);}
        case '#':
        case '@': {
            id retrunValue = JOTOID returnPtr;
            if (!retrunValue) return [NSNull null];
            return JOGetObj(retrunValue);
        }
        case '^':
        case '*': { return JOMakePointerObj(returnPtr) ?: [NSNull null]; }
        case ':': { return JOMakeSelObj(returnPtr) ?: [NSNull null]; }
        case '{': {
            //MARK:暂时不处理
        }
        default : break;
    }
    return [NSNull null];
}

static void JOParamsResolver(void *params[], NSMethodSignature *sign, NSInvocation *invoke, int initIndex) {
    NSUInteger num = [sign numberOfArguments];
    for (int i = initIndex; i < num; ++i) {
        const char* type = [sign getArgumentTypeAtIndex:i];
        *type == 'r' ? ++type : nil;

        __unsafe_unretained id param = JOTOID (params[i-initIndex]);
        switch (type[0]) {
            case 'B':
            case 'c':
            case 'C':
            case 's':
            case 'S':
            case 'i':
            case 'I':
            case 'l':
            case 'q': { long long v = [[param toNumber] longLongValue];
                [invoke setArgument:&v atIndex:i]; break;}
            case 'L': 
            case 'Q': { unsigned long long v = [[param toNumber] unsignedLongLongValue];
                [invoke setArgument:&v atIndex:i]; break;}
            case 'f': { float v = [[param toNumber] floatValue];
                [invoke setArgument:&v atIndex:i]; break;}
            case 'd': { double v = [param toDouble];
                [invoke setArgument:&v atIndex:i]; break;}
            case '#':
            case '@': {
                __autoreleasing id v = [param toObject];
                if (strlen(type) > 1 && type[1] == '?'
                    && [v isKindOfClass:[NSArray class]]
                    && [v count] == 2
                    && [v[0] isKindOfClass:[NSString class]]
                    && [param[1] isInstanceOf:[JSContext currentContext][@"Function"]]
                    ) {
                    
                    v = JOPackJsFunction(v[0], param[1]);
                }
                void *p = JOUnmakeAnyObj(v).ptr;
                [invoke setArgument:&p atIndex:i];
                break;
            }
            case '{': {
                JODoubleWord6 v;
                JOUnpackStructValue(type, &v, [param toObject]);
                [invoke setArgument:&v atIndex:i];
                break;
            }
            case '^':
            case '*':
            case ':': {
                void *p = JOUnmakeAnyObj([param toObject]).ptr;
                [invoke setArgument:&p atIndex:i];
                break;
            }
        }
    }
}

static id JOPackJsFunction(NSString *signString, JSValue *jsFunction) {
    //签名字符串不能放在栈上，否则很可能被覆盖掉
    char *blockSgin = JOCopySgin(signString);
    /*  原生方法需要的参数是block，js传过来的参数是function，这时需要构造一个block（无参数无返回），强制修改这个block的签名。然后在block回调的时候才能根据签名解析出参数（Method或者说selector的签名在定义的时候，就由编译器搞定了，protocol也会生成签名，但如果仅仅是在类中声明而不实现是没有签名的，而block的签名则是在定义的时候才有，仅声明也没有，js没有类型信息，所以这里需要在js传funtion的时候手动签名）。JOGlobalParamsResolver只能根据第一个参数也就是block
        本身，如果不拷贝，则每次都是相同的block，无法获取正确的签名，如果强制每次修改签名，那么在异步执行的情况下，签名会冲突，
        所以需要拷贝整个block，并重新签名。
     */
    __autoreleasing id v = ^() {
        JOGlobalBlockGetParams();
        //从x0中获取已经解析出的参数列表，是个NSArray，其中第一个参数是Block本身是隐藏参数
        asm volatile("mov x1, x0");
        uintptr_t *array = NULL;
        void **arrayptr = (void **)&array;
        asm volatile("ldr x0, %0": "=m"(arrayptr));
        asm volatile("str x1, [x0]");
        __autoreleasing NSArray *arr = (__bridge NSArray *)(void *)(*arrayptr);
        __autoreleasing JSValue *ret = [jsFunction callWithArguments:[arr subarrayWithRange:(NSRange){1, arr.count - 1}]];
        char returnType = blockSgin[0];
        //构建返回值和方法的返回值构建是一样的注意使用__autoreleasing变量以防止x0被破坏
        JOConstructReturnValue(ret, returnType);//此句最好在方法的最末
    };
    
    if (!_JOParamBlockIMP) {
        JOBlock *block = (__bridge JOBlock *)v;
        _JOParamBlockIMP = block->BlockFunctionPtr;
    }
    
    return v;
}

static id JOGetReturnValue(NSMethodSignature *sign, NSInvocation *invoke, id obj, SEL sel) {
    const char *type = [sign methodReturnType];
    *type == 'r' ? ++type : nil;

    BOOL isStore = YES;
    if (!obj || !sel) isStore = NO;

    int bits = 0;
    switch (type[0]) {
        case 'v': return [NSNull null];
        case 'B':
        case 'c':
        case 'C': bits += 8;
        case 's':
        case 'S': bits += 16;
        case 'i':
        case 'I': bits += 32;
        case 'l':
        case 'q': {
            NSInteger value; [invoke getReturnValue:&value];
            value = (value << bits) >> bits;
            JOStoreInvocation(obj, sel, invoke, isStore); return @(value);}
        case 'L':
        case 'Q': {unsigned long long value; [invoke getReturnValue:&value];
            JOStoreInvocation(obj, sel, invoke, isStore); return @(value);}
        case 'f': {float value; [invoke getReturnValue:&value];
            JOStoreInvocation(obj, sel, invoke, isStore);return @(value);}
        case 'd': {double value; [invoke getReturnValue:&value];
            JOStoreInvocation(obj, sel, invoke, isStore); return @(value);}
        case '#': {
            id retrunValue = nil;
            [invoke getReturnValue:&retrunValue];
            JOStoreInvocation(obj, sel, invoke, isStore);
            return JOGetObj(retrunValue) ?: [NSNull null] ;
        }
        case '@': {
            __unsafe_unretained id retrunValue = nil;
            [invoke getReturnValue:&retrunValue];
            JOStoreInvocation(obj, sel, invoke, isStore);
            
            if (!retrunValue) {
                return [NSNull null];
            } else if ([retrunValue isKindOfClass:[NSNumber class]]
                       || [retrunValue isKindOfClass:[NSString class]]) {
                return retrunValue;
            }
            
            JOObj *ret = JOGetObj(retrunValue);
            //按照调用频次排列（个人认为的，仅作为参考）
            if (sel == @selector(alloc) || sel == @selector(new)
                || sel == @selector(copy) || sel == @selector(mutableCopy)
                || (!strncmp(sel_getName(sel), "init", 4) && invoke.target != retrunValue)
                || sel == @selector(allocWithZone:) || sel == @selector(copyWithZone:)
                || sel == @selector(mutableCopyWithZone:)) {
                JOTools.release(retrunValue);
            }
            
            return ret;
        }
            
        case '^':
        case '*': {
            void *retrunValue = NULL;
            [invoke getReturnValue:&retrunValue];
            JOStoreInvocation(obj, sel, invoke, isStore);
            return JOMakePointerObj(retrunValue) ?: [NSNull null] ;
        }
        case ':': {
            void *retrunValue = NULL;
            [invoke getReturnValue:&retrunValue];
            JOStoreInvocation(obj, sel, invoke, isStore);
            return JOMakeSelObj(retrunValue) ?: [NSNull null];
        }
        case '{': {
            JODoubleWord6 v;
            [invoke getReturnValue:&v];
            JOStoreInvocation(obj, sel, invoke, isStore);
            return JOPackStructValue(type, v);
            //MARK:更完善的结构体解析以后再想办法
        }
        default : break;
    }
    JOStoreInvocation(obj, sel, invoke, isStore);
    return [NSNull null];
}
#else
@implementation JOBridge
+ (JSContext *)jsContext { return nil;}
+ (void)setJsContext:(JSContext *)jsContext {}
+ (BOOL)isDebug { return NO;}
+ (void)setIsDebug:(BOOL)isDebug {}
+ (void)bridge {}
+ (void)evaluateScript:(NSString *)script {}
+ (void)registerPlugin:(id)obj {}
+ (void)addObject:(id)obj forKey:(NSString *)key needTransform:(BOOL)trans {}
+ (id)objectForKey:(NSString *)key { return nil;}
@end
#endif
