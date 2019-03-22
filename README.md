# JOBridge
JSPatch被苹果爸爸封了以后hotfix怎么办？业务需求需要尽快上线怎么办？可以尝试使用JOBridge。其使用了和JSPatch不一样的实现方案，全部由OC实现，比JSPatch功能更强，性能也更好，语法上也基本保持一致（之后我会给出一些示例），当然最关键的是苹果爸爸还不知道！

# 原理方案
请移步本人博客
JOBridge之一任意方法的Swizzle（可用代替JSPatch）  https://www.jianshu.com/p/905e06eeda7b
JOBridge之二JS注册类和访问所有Native方法（可用代替JSPatch） https://www.jianshu.com/p/f457528fedeb
JOBridge之三C函数OC化和语法增加以及优化（可用代替JSPatch）  https://www.jianshu.com/p/c1161f61ed96

# 使用方法
OC端：
1、执行js
```Objective-C
    [JOBridge bridge];//初始化
    [JOBridge evaluateScript:script];//执行js
```
2、扩展C方法和变量
```Objective-C

#if __arm64__

#import "JOCPlugin.h"
#import "JOObject.h"
#import <JavaScriptCore/JavaScriptCore.h>

void test(id obj) {
    NSLog(@"%@", obj);
}

static NSMutableDictionary *JOTest;

@implementation JOCPlugin
+ (void)load {
    [self registerPlugin];
}

+ (void)initPlugin {
    JOMapCFunction(test, JOSigns(void, id));
    [self registerObject:JOMakeObj([self class]) name:@"JC" needTransform:YES];
}

@end

@interface JOCPluginTest : JOCFunction
@end


@implementation JOCPluginTest
+ (void)load {
    JOTest = [NSMutableDictionary dictionary];
    [self registerPlugin];
}

+ (void)initPlugin {
    
    JOMapCFunction(test, JOSigns(void, id));
    [self registerObject:JOMakeObj([self class]) name:@"JCTest" needTransform:YES];
}

+ (NSMutableDictionary *)pluginStore {
    return JOTest;
}
@end


@interface JOCPluginTest1 : JOPluginBase
@end


static NSMutableDictionary *JOTest1;

@implementation JOCPluginTest1
+ (void)load {
    JOTest1 = [NSMutableDictionary dictionary];
    [self registerPlugin];
}

+ (void)initPlugin {
    [self pluginStore][@"RGB"] = ^(JSValue *jsvalue) {
        uint32_t hex = [jsvalue toUInt32] ;
        return JOMakeObj([UIColor colorWithRed:(((hex & 0xFF0000) >> 16))/255.0 green:(((hex & 0xFF00) >> 8))/255.0 blue:((hex & 0xFF))/255.0 alpha:1.0]);
    };
    
    [self registerObject:[self pluginStore] name:@"JGTest" needTransform:NO];

}

+ (NSMutableDictionary *)pluginStore {
    return JOTest1;
}
@end
#endif

```

JS端：
