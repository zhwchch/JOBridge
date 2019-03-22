# JOBridge
JSPatch被苹果爸爸封了以后hotfix怎么办？业务需求需要尽快上线怎么办？可以尝试使用JOBridge。其使用了和JSPatch不一样的实现方案，全部由OC实现，比JSPatch功能更强，性能也更好，语法上也基本保持一致（之后我会给出一些示例），当然最关键的是苹果爸爸还不知道！

# 原理方案
请移步本人博客
JOBridge之一任意方法的Swizzle（可用代替JSPatch）  https://www.jianshu.com/p/905e06eeda7b
JOBridge之二JS注册类和访问所有Native方法（可用代替JSPatch） https://www.jianshu.com/p/f457528fedeb
JOBridge之三C函数OC化和语法增加以及优化（可用代替JSPatch）  https://www.jianshu.com/p/c1161f61ed96

# 使用方法
OC只需要
```
    [JOBridge bridge];//初始化
    [JOBridge evaluateScript:script];//执行js
```
