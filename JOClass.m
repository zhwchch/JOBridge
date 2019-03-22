//
//  JOClass.m
//  JOBridge
//
//  Created by Wei on 2018/9/12.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import "JOClass.h"
#import "JOTools.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "JOObject.h"
#import "JOSwizzle.h"
#import <os/lock.h>
#import <pthread.h>
#import "JOBridge.h"


typedef struct JOClassStruct {
    Class class;
    Class superClass;
    BOOL isNewClass;
    Protocol *protocols[32];
    int protocolCount;
} JOClassStruct;


NSMutableDictionary *_JOGlobalJsMethods = nil;
NSMutableDictionary *_JOGlobalJsAssociatedKeys = nil;

static void *_JOClassKeyLock;
static void * _JOClassMethodLock;


JOLOADER(110) void JOClassInit() {
    _JOGlobalJsMethods = [NSMutableDictionary dictionary];
    _JOGlobalJsAssociatedKeys = [NSMutableDictionary dictionary];
    JOTools.initLock((void **)&_JOClassKeyLock);
    JOTools.initLock((void **)&_JOClassMethodLock);
}


#pragma mark - Tools


JOINLINE void *JOAssociatedKey(NSString *keyName) {
    JOTools.lock(_JOClassKeyLock);
    id key = _JOGlobalJsAssociatedKeys[keyName];
    if (!key) {
        _JOGlobalJsAssociatedKeys[keyName] = keyName;
        key = keyName;
    }
    JOTools.unlock(_JOClassKeyLock);
    
    return JOTOPTR key;
}


JOINLINE JSValue *JOSearchJsMethod(Class class, NSString *selectorName) {
    JSValue *func;
    JOTools.lock(_JOClassKeyLock);
    while (!(func = _JOGlobalJsMethods[class][selectorName]) && (class = class_getSuperclass(class))) {
        NSCAssert(class, @"没有找到对应的方法\"%@\"", selectorName);
    }
    JOTools.unlock(_JOClassKeyLock);

    return func;
}

JOINLINE void JOAddJsMethod(Class class, NSString *selectorName, JSValue *jsMethod) {
    JOTools.lock(_JOClassKeyLock);
    
    if (!_JOGlobalJsMethods[class]) {
        _JOGlobalJsMethods[(id<NSCopying>)class] = [NSMutableDictionary dictionary];
    }
    _JOGlobalJsMethods[class][selectorName] = jsMethod;
    
    JOTools.unlock(_JOClassKeyLock);
}

JOINLINE Method JOGetMethodWithSelector(Class cls, SEL sel) {
    unsigned int count = 0;
    Method method = NULL;
    Method *list = class_copyMethodList(cls, &count);
    for (int i = 0; i < count; ++i) {
        Method m = list[i];
        SEL s = method_getName(m);
        if (sel_isEqual(s, sel)) {
            method = m;
        }
    }
    free(list);
    return method;
}

JOINLINE char *JOGetNameWithSetter(SEL sel) {
    const char *selName = sel_getName(sel);
    size_t len = strlen(selName);
    if (len < 3) return NULL;

    char *name = malloc(len-2);
    memcpy(name, selName+2, len-3);
    char *pos = name;
    
    *pos ++ = '_';
    *pos = *pos + 32;
    *(name + len - 3) = '\0';
    return name;
}

JOINLINE SEL JOGetSelectorWithString(NSString *name) {
    return NSSelectorFromString(JOTools.replace(name, @"_", @":"));
}
JOINLINE NSString *JOGetClassName(NSString *string) {
    return JOSubString(JOSubString(string, @":", YES), @"<", YES);;
}

JOINLINE NSString *JOGetSuperClassName(NSString *string) {
    if (JOTools.contains(string, @":")) {
        return nil;
    }
    return JOSubString(JOSubString(string, @":", @"<"), 1, NO);
}

JOINLINE NSArray *JOGetProtocolName(NSString *string) {
    if (JOTools.contains(string, @"<")) return nil;
    NSArray *classArray = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<,>"]];
    return [classArray subarrayWithRange:(NSRange){1, classArray.count - 1 - 1}];
}

JOINLINE NSUInteger getArgmentCount(JSValue *jsValue) {
    NSString *function = [jsValue toString];
    NSRange range = [function rangeOfString:@"^function \\([A-Za-z0-9 ,_]{0,512}\\)" options:NSRegularExpressionSearch];
    NSString *args;
    if (range.length > 0) {
        args = [function substringWithRange:range];
    }
    if (args.length > 0) {
        args = [args substringWithRange:(NSRange){10, args.length-1-10}];
    }
    
    return args.length > 0 ? [args componentsSeparatedByString:@","].count : 0;
}

#pragma mark - Property & Ivar

id JOGetter(id obj, SEL sel) {
    NSString *key = [NSString stringWithFormat:@"_%@",NSStringFromSelector(sel)];
    Ivar ivar = class_getInstanceVariable([obj class], [key UTF8String]);
    if (ivar) {
        return object_getIvar(obj, ivar);
    } else {
        return objc_getAssociatedObject(obj, JOAssociatedKey(key));
    }
}

/*  object_setIvar不会retain对象，而object_setIvarWithStrongDefault在iOS10之后才有效，
    所以需要手动调用retain，并在父对象dealloc的时候调用release
 */
void JOSetter(id obj, SEL sel, id newValue) {
    char *name = JOGetNameWithSetter(sel);
    Ivar ivar = class_getInstanceVariable([obj class], name);
    if (ivar) {
        id value = object_getIvar(obj, ivar);
        JOTools.release(value);
        object_setIvar(obj, ivar, newValue);
        JOTools.retain(newValue);
    } else {
        objc_setAssociatedObject(obj, JOAssociatedKey([NSString stringWithUTF8String:name]), newValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    free(name);
}

//目前只支持OC类型，基础类型暂时不支持
void JOAddPropertyAttribute(Class class, NSString *name, NSArray *att, BOOL isNewClass) {
    if (!isNewClass) goto JOAssociatedTag;//使用关联对象只需要添加方法，关联对象目前只支持retain
    
    objc_property_attribute_t nonatomic = {"N", ""};
    objc_property_attribute_t ownership = {"&", ""};
    objc_property_attribute_t type = {"T", @encode(id)};

    if ([att.lastObject isEqualToString:@"weak"]) {
        ownership = (objc_property_attribute_t){"W",""};
    } else if ([att.lastObject isEqualToString:@"copy"]) {
        ownership = (objc_property_attribute_t){"C",""};
    }
//    else if ([att.lastObject isEqualToString:@"assign"]) {
//        type = (objc_property_attribute_t){"T", [[NSString stringWithFormat:@"@\"%@\"",att.firstObject] UTF8String]};
//    }
    
    objc_property_attribute_t attribute[] = { ownership, nonatomic, type};
    BOOL success = class_addProperty(class, [name UTF8String], attribute, 3);
    if (success) {
        //这里似乎要手动调用class_addIvar才能将变量描述进去，仅用class_addProperty似乎不奏效。
        class_addIvar(class, [[NSString stringWithFormat:@"_%@",name] UTF8String], sizeof(id), log2(sizeof(id)), @encode(id));
JOAssociatedTag:
        class_addMethod(class, NSSelectorFromString(name), (IMP)JOGetter, "@@:");
        NSString *head = [[name substringToIndex:1] uppercaseString];
        NSString *set = [NSString stringWithFormat:@"set%@%@:", head, [name substringFromIndex:1]];
        class_addMethod(class, NSSelectorFromString(set), (IMP)JOSetter, "v@:@");
    }
}

//有些情况下必须直接访问变量，比如js重写getter和setter
id JOGetIvar(id obj, SEL sel, NSString *name) {
    Ivar ivar = class_getInstanceVariable([obj class], [name UTF8String]);
    if (ivar) {
        return object_getIvar(obj, ivar);
    }
    return nil;
}

void JOSetIvar(id obj, SEL sel, NSString *name, id newValue) {
    Ivar ivar = class_getInstanceVariable([obj class], [name UTF8String]);
    if (ivar) {
        id value = object_getIvar(obj, ivar);
        JOTools.release(value);
        object_setIvar(obj, ivar, newValue);
        JOTools.retain(newValue);
    }
}

//对于基础数据类型，如果直接object_setIvar，编译器会自动插入retain的代码，就会crash，所以需要用汇编来调用
void JOGetIvarI(__autoreleasing id obj, SEL sel, __autoreleasing NSString *name) {
    Ivar ivar = class_getInstanceVariable([obj class], [name UTF8String]);
    if (ivar) {
        asm volatile("ldr  x7, %0": "=m"(ivar));
        asm volatile("ldr  x0, %0": "=m"(obj));
        asm volatile("mov  x1, x7");
        asm volatile("bl  _object_getIvar");
    } else {
        asm volatile("mov  x0, #0x0");
        asm volatile("mov  x1, #0x0");
        asm volatile("mov  x8, #0x0");
        asm volatile("movi  d0, #0x0");
        asm volatile("movi  d1, #0x0");
        asm volatile("movi  d2, #0x0");
        asm volatile("movi  d3, #0x0");
    }
}
void JOSetIvarI(__autoreleasing id obj, SEL sel, __autoreleasing NSString *name, NSInteger newValue) {
    Ivar ivar = class_getInstanceVariable([obj class], [name UTF8String]);
    if (ivar) {
        asm volatile("ldr  x6, %0": "=m"(ivar));
        asm volatile("ldr  x7, %0": "=m"(newValue));
        asm volatile("ldr  x0, %0": "=m"(obj));
        asm volatile("mov  x1, x6");
        asm volatile("mov  x2, x7");
        asm volatile("bl  _object_setIvar");
    }
}

//对JOSetter中retain的对象一次调用release
void JORelease(__unsafe_unretained id obj, SEL sel) {
    unsigned int count;
    Ivar *v = class_copyIvarList([obj class], &count);
    for (int i = 0; i < count; ++i) {
        const char *name = ivar_getName(v[i]);
        Ivar ivar = class_getInstanceVariable([obj class],name);
        
        __unsafe_unretained id value = object_getIvar(obj, ivar);
        object_setIvar(obj, ivar, nil);
        JOTools.release(value);
    }
    free(v);
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//#pragma clang diagnostic ignored "-Wundeclared-selector"
//    if ([obj respondsToSelector:@selector(JODealloc)]) {
//        [obj performSelector:@selector(JODealloc)];
//    }
//    
//#pragma clang diagnostic pop
    //调用父类dealloc实现，重写dealloc后，编译器会默认插入父类dealloc的调用，但这里修改其实现后，必须手动调用
    IMP imp = class_getMethodImplementation([[obj class] superclass], sel);
    imp ? ((void(*)(id, SEL))imp)(obj, sel) : nil;
}





#pragma mark - Class Parser

static void JOParseClass(JOClassStruct *joClass, NSString *className) {
    NSString *aClassName = JOTools.trim(JOGetClassName(className));
    NSString *superClassName = JOTools.trim(JOGetSuperClassName(className));
    NSArray *protocolsName = JOGetProtocolName(className);
    
    joClass->class = objc_getClass(aClassName.UTF8String);
    if (!joClass->class) {
        joClass->isNewClass = YES;
        joClass->superClass = objc_getClass(superClassName.UTF8String);
        if (!joClass->superClass) {
            joClass->class = NULL;
            return;
        }
        joClass->class = objc_allocateClassPair(joClass->superClass, aClassName.UTF8String, 2);
    }
    
    int count = 0;
    for (NSString *obj in protocolsName) {
        Protocol *pro = objc_getProtocol(JOTools.trim(obj).UTF8String);
        class_addProtocol(joClass->class, pro);
        joClass->protocols[count++] = pro;
    }
    joClass->protocolCount = count;
}

static void JOParseMethods(JOClassStruct *joClass, JSValue *jsMethods, BOOL isMeta) {
    NSDictionary *methods = [jsMethods toDictionary];
    for (NSString *method in methods) {
        JSValue *jsMethod = [jsMethods valueForProperty:method];
        SEL sel = JOGetSelectorWithString(method);
        NSArray *jsArray = [jsMethod toObject];
        if ([jsArray isKindOfClass:[NSArray class]] && [(id)jsArray count] > 1) {
            jsMethod = jsMethod[1];
        }
        if (JOBridge.isDebug) {
            JOLog(@"addJSMethod: %@",NSStringFromSelector(sel));
        }
        //这里使用class_copyMethodList，其只会获取当前类方法，不会获取父类方法，而class_getInstanceMethod等会获取父类方法
        Method ocMethod = isMeta ? JOGetMethodWithSelector(object_getClass(joClass->class), sel)
                                 : JOGetMethodWithSelector(joClass->class, sel);
        if (ocMethod) {
            method_setImplementation(ocMethod, (IMP)JOGlobalSwizzle);
            JOAddJsMethod(joClass->class, NSStringFromSelector(sel), jsMethod);
            continue;
        }
        Method ocSuperMethod = isMeta ? class_getClassMethod([joClass->class superclass], sel)
                                      : class_getInstanceMethod([joClass->class superclass], sel);
        if (ocSuperMethod) {
            const char *type = method_getTypeEncoding(ocSuperMethod);
            class_addMethod(joClass->class, sel, (IMP)JOGlobalSwizzle, type);
            JOAddJsMethod(joClass->class, NSStringFromSelector(sel), jsMethod);
            continue;
        }
        
        char *type = NULL;
        for (int i = 0; i < joClass->protocolCount; ++i) {
            Protocol *p = joClass->protocols[i];
            type = protocol_getMethodDescription(p, sel, YES, !isMeta).types;
            if (!type) type = protocol_getMethodDescription(p, sel, NO, !isMeta).types;
            if (type) break;
        }
        
        //如果协议中也没有此方法签名，表明是由js新创建的方法，则获取js提供的签名
        if (type) {
            class_addMethod(isMeta ? object_getClass(joClass->class) : joClass->class, sel, (IMP)JOGlobalSwizzle, type);
        } else {
            if ([jsArray isKindOfClass:[NSArray class]]
                && jsArray.count > 1
                && [jsArray.firstObject isKindOfClass:[NSString class]]) {
                const char *type = [jsArray.firstObject UTF8String];
                class_addMethod(isMeta ? object_getClass(joClass->class) : joClass->class, sel, (IMP)JOGlobalSwizzle, type);
            } else {
                continue;
            }
        }
        
        JOAddJsMethod(joClass->class, NSStringFromSelector(sel), jsMethod);
    }
}

static void JOParseProperties(JOClassStruct *joClass, JSValue *jsValue) {
    NSDictionary *propertyList = [jsValue toDictionary];
    for (NSString *obj in propertyList.allKeys) {//这里全部使用关联对象也可以，这不过先实现了class_addProperty
        JOAddPropertyAttribute(joClass->class, obj, propertyList[obj], joClass->isNewClass);
    }
    
    if (joClass->isNewClass) objc_registerClassPair(joClass->class);
}

static void JOAddIvarGetterAndSetter(JOClassStruct *joClass) {
    class_addMethod(joClass->class, NSSelectorFromString(@"JOGetIvar"), (IMP)JOGetIvar, "@@:@");
    class_addMethod(joClass->class, NSSelectorFromString(@"JOSetIvar"), (IMP)JOSetIvar, "v@:@@");
    class_addMethod(joClass->class, NSSelectorFromString(@"JOGetIvarI"), (IMP)JOGetIvarI, "q@:@");
    class_addMethod(joClass->class, NSSelectorFromString(@"JOSetIvarI"), (IMP)JOSetIvarI, "v@:@q");
}

static void JOAddDealloc(JOClassStruct *joClass) {
    SEL sel = NSSelectorFromString(@"dealloc");
    Method ocMethod = JOGetMethodWithSelector(joClass->class, sel);
    if (joClass->isNewClass && !ocMethod) {
        class_addMethod(joClass->class, sel, (IMP)JORelease, "v@:");
    }
}

void JOClassParser(JSValue *className, JSValue *properties, JSValue *classMethods, JSValue *metaClassMethods) {
    NSString *aClass = [className toString];
    JOClassStruct joClass = {0};
    
    JOParseClass(&joClass, aClass);
    if (!joClass.class) return;
    JOParseProperties(&joClass, properties);
    JOParseMethods(&joClass, classMethods, NO);
    JOParseMethods(&joClass, classMethods, YES);
    JOAddIvarGetterAndSetter(&joClass);
    JOAddDealloc(&joClass);
}
#endif
