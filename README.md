# JOBridge
JSPatch被苹果爸爸封了以后hotfix怎么办？业务需求需要尽快上线怎么办？可以尝试使用JOBridge。其使用了和JSPatch不一样的实现方案，全部由OC实现，比JSPatch功能更强，性能也更好，语法上也基本保持一致（之后我会给出一些示例），当然最关键的是苹果爸爸还不知道！



# 原理方案
请移步本人博客
JOBridge之一任意方法的Swizzle（可用代替JSPatch）  https://www.jianshu.com/p/905e06eeda7b
JOBridge之二JS注册类和访问所有Native方法（可用代替JSPatch） https://www.jianshu.com/p/f457528fedeb
JOBridge之三C函数OC化和语法增加以及优化（可用代替JSPatch）  https://www.jianshu.com/p/c1161f61ed96



# 使用方法
开始之前，先说明一下通用调用桥。
#### *JOBridge通用调用桥：

在js的Object.prototype中添加了一个`_oc_`的方法，其负责转换处理js传递过来的参数，然后调用OC的对应的方法，最后将返回值回传给js。这种方式被我称为JOBridge通用调用桥。通过该桥，JOBridge将OC几乎所有的方法开放给了js，C方法也可以通过其开放给js（需要预先挖坑，C函数入口地址需要硬编译）。



### OC端：

##### 1、执行js
```Objective-C
[JOBridge bridge];//初始化
[JOBridge evaluateScript:script];//执行js
```
##### 2、扩展C方法
OC方法一般是扩展的，C方法使用之前需要挖坑。通过C方法OC化，已经使挖坑变得比较简单了。

第一种不替换存储字典，放在全局默认C方法容器对象下，调用registerObject:name:needTransform:并向js中注册对象JC，js中用JC.test()访问。其中needTransform表示是否使用通用调用桥处理参数和调用，如果需要的话，之前需要调用JOMapCFunction注册OC的方法并给以签名。
```Objective-C
#if __arm64__

@interface JOCPlugin : JOCFunction
@end
void test(id obj) { NSLog(@"%@", obj); }


static NSMutableDictionary *JOTest;

@implementation JOCPlugin
+ (void)load {
    [self registerPlugin];
}

+ (void)initPlugin {//重写本方法，JOBridge初始化时会调用本方法注册
    JOMapCFunction(test, JOSigns(void, id));
    [self registerObject:JOMakeObj([self class]) name:@"JC" needTransform:YES];
}
@end
#endif
```
第二种替换存储字典（需要重写pluginStore方法），其放在JCTest下，在js中用JCTest.test()访问。needTransform同理。

```Objective-C
#if __arm64__
@interface JOCPluginTest : JOCFunction
@end

void test(id obj) { NSLog(@"%@", obj); }

static NSMutableDictionary *JOTest;

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
#endif
```

##### 3、扩展全局常量

放在JCTest1下（需要重写pluginStore方法），在js中用JCTest1.RGB()， JCTest1.RED_VALUE 访问。其也可以提供方法调用，不使用通用调用桥处理参数，但需要自己解析参数组装参数，可以比较灵活的实现。

```Objective-C
#if __arm64__
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
    [self pluginStore][@"RED_VALUE"] = @(0xFF0000);
    [self registerObject:[self pluginStore] name:@"JGTest1" needTransform:NO];

}

+ (NSMutableDictionary *)pluginStore {
    return JOTest1;
}
@end
#endif

```



### JS端：

JS的语法我尽量让其类似于JSPatch，减少学习成本，但是还是有很许多不一样的地方，而且内容比较多，一点一点说明。

####JOC对象

主功能对象JOC，其包含最常见和通用功能，其不走JOBridge的通用调用桥。

1、`interface`：最重要的方法，其用于注册类，替换方法等，所有功能都依赖其实现。语法JOC.interface("类名:父类名<协议名>", 属性字典, 对象方法字典, 类方法字典);实例如下

```javascript
;JOC.interface('UserView : UIView', {
    watchView:['id','strong'],
 },
 {
     initWithFrame_:function(frame) {
				//创建对象返回
     },
},
null);
```

协议最多32个，也可以省略。属性字典，前者属性名字，后面是属性关键字，暂不支持非OC对象，所以全部使用

`['id','strong']`就行了。方法字典，key就是方法名字，下划线`_`会替换成`:`，`__`替换成`_`。js调用本方法语法为`userView.initWithFrame_(frame)`;

2、`class`：通过该方法访问已有的类Class。例如：`JOC.class("UIView").new()`。可以创建一个UIView对象。Foundation和UIKit常用的类都已经作为常量开放给js，直接使用类名即可访问，例如：UIView.new();

具体参见：

```objective-c
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
```



3、`storeObject`：将新对象存储对象容器中。这个需要举例具体说明。

```js
initWithFrame_:function(frame) {
    var inited = self.JOSUPER_initWithFrame_(frame);
    if (inited) {
        JOC.storeObject(self, inited);
        return self;
    }
    return null;
 },
```

通过调用父类的`JOSUPER_initWithFrame_`创建得到了一个新的对象inited，但是因为是在js语言中，其无法直接赋值给self，所以需要通过storeObject来间接赋值给self。js中拿到的OC对象或数据都是经过包装的，比如这里的self和inited都是由JOObj对象，其内部引用着self。storeObject就是将JOObj中的引用对象改为inited所引用的对象。

4、`retain/release`：手动计数器管理，不用多说

5、`new`：快捷对象创建，实例：`JOC.new("UIView")`，可以用来代替`JOC.class("UIView").new()`或者`JOC.class("UIView").alloc().init()`。

6、`structToObject`：有些情况下需要访问结构体内部的数据，需要将其转成js能识别的对象。比如：CGRect转成`{'x':0,'y':0,'width':375,'height':44}`。目前支持几种常见的结构体：CGRect，CGPoint，CGSize，NSRange，CGAffineTransform，UIEdgeInsets，UIOffset。如果js不访问结构体内部数据，则不需要调用该方法，直接当普通参数传递即可。

7、`getPointerValue/setPointerValue`：获取指针对象JOPointerObj中包装的指针值，同理赋值也一样。实例：

```javascript
array.enumerateObjectsUsingBlock_(['@@@Q*',function(obj, idx, stop) 
{
     JOC.log('obj: ' + JOC.getString(obj) + ' idx: ' + idx + ' stop: ' + stop);
     JOC.setPointerValue(stop, true);
}]);
```

调用NSArray的枚举，在回调中把stop设置为true。

8、`getPointerDoubleValue/setPointerDoubleValue`：和上面的同理，数据类型为浮点数。

9、`malloc/free`：分配/释放内存。实例：

```javascript
var ptr = JOC.malloc(8);
JOC.setPointerDoubleValue(ptr, 123.56);
JOC.log('double value: ' + JOC.getPointerDoubleValue(ptr));
JOC.free(ptr);
```

这里分配了一个8Byte的内存空间，调用setPointerDoubleValue设置值，然后输出，最后调用free。其主要用途是用来解决指针参数传递子函数，子函数修改数据的问题。但限于autoreleasepool的问题 ，对于OC对象无法支撑，目前只支持基础类型。

例如：

```javascript
var changePtr = function(ptr) {
  	JOC.setPointerValue(ptr, 100);
};
function() {
    var ptr = JOC.malloc(8);
	  changePtr(p);
  	JOC.free(ptr);
}();
```

10、`array`：创建OC数组。`[JOC.array(['Bill', 'UserInfo']`

11、`selector`：获取selector，参数selector名字字符串。

12、`log`：日志输出



#### 全局方法

`__weak/__strong/__bridge_id/__bridge_pointer`：这些方法也就不用多说了。



#### 新增对象方法：

有签名的情况下替换方法，只需要在 JOC.interface("类名:父类名<协议名>", 属性字典, 对象方法字典, 类方法字典); 中的 对象方法字典 添加对应的key->function就行了，如果想新写一个方法怎么办呢？添加一个key->array[sign string, function]，实例如下：

```javascript
FitIphone5_:['d@:d', function(value) {
        return JOG.SCREEN_WIDTH > 320 ? value : value - 10;
}],
```

这里新增了一个名为`FitIphone5:`方法，然后js通过对应对象`obj.FitIphone5_(width)`来调用。可以看到这里和替换不同的是，`FitIphone5_`对应的是一个数组，第一个元素是签名字符串，第二个元素对应的函数。至于为什么搞成数组，呃…是因为懒，最初随手定义的，后来就懒得改了。



#### JS调用OC方法规则：

如果使用JOBridge通用调用桥，selector和参数需要遵循一些约定。

##### 参数规则：

1、第一个参数固定的是selectorName。这个参数不用手动传递，由脚本根据规则生成，沿用了JSPatch的办法。例如：

`tableView.setDelegate_(self)`，会被转成`tableView._oc_('setDelegate_',self)`

> 注意末尾"_"不能省略。

2、第二个参数不同的情况不太一样，有可能作为特殊参数，目前只有一种特殊情况，就是调用有匿名参数函数时进行签名，其他情况下当普通参数即可。举个例子：

```javascript
var aString = NSString.JOVAR_stringWithFormat_('@@:@@@i@Bd','this is %@  %@ %d %@ %d %.2f', 'a', 'test', 90, self, true ,329.78398);
```


'@@:@@@i@Bd'为签名，JOBridge通用调用桥会根据该签名去解析参数，'this is %@  %@ %d %@ %d %.2f' 为格式化字符串，后面则是剩余参数。

> 手动签名请用简单方式，不要带参数长度，或者复杂的符号，因为这里用的是最简单的签名识别方法。OC对象全部用@，其他的基础类型对应就行。

3、余下的参数位都是普通参数，依次传递即可。

4、注意：为了让JOBridge运行的更快，对于Number/NSNumber，String/NSString我都沿用原数据，其可以被js和OC直接共享使用，没有转成JOObj封装对象，所以必要时需要注意其带来的副作用，比如：不能使用`__bridge_pointer`转指针。

5、block参数：

如果需要传递block参数，也和类新增方法语法类似，例如：

```javascript
self.anLable().mas__makeConstraints_(
    ['v@@', function(make) {
        make.left().equalTo()(self.anIcon().mas__right()).valueOffset()(5);
        make.top().equalTo()(self.accountLable().mas__bottom()).valueOffset()(self.FitIphone5_(17));
        make.width().equalTo()(150);
        make.height().equalTo()(20);
    }]
);
```

如果只是创建局部的调用，由js自己使用，不需要传递给JOBridge，那就创建一个function直接使用即可。

6、返回block调用：

`make.left().equalTo()(self.anIcon().mas__right()).valueOffset()(5);`

在上面的语句中，equalTo()和valueOffset()都返回的是block，再次调用即可。容易出错，需要多加小心。



#### selector规则：

1、js所有对OC对象属性，方法的使用都是通过方法调用来完成的(除了字典数据)。

2、若走JOBridge通用调用桥，OC方法中所有的`：`变成`_`，`__`变成`_`。例如：

`nav.navigationBar().setBackgroundImage_forBarMetrics_(image, JOG.UIBarMetricsDefault);`

3、所有的赋值操作需要调用对应的setter方法、`JOSetIvar`、`JOSetIvaI`或其他有赋值功能的方法完成。等号赋值只对js变量有效。

4、调用父类方法请在前面添加前缀`JOSUPER_`。

5、调用变成参数（匿名参数）方法添加前缀`JOVAR_`。

6、特殊方法`JOGetIvar`，`JOSetIvar`，在某些情况下，我们需要访问类的成员变量，而又不想通过getter，setter的方式，那么就需要使用这俩方法了。实例如下：

```javascript
tableView:function() {
    if (!self.JOGetIvar('_tableView')) {
        var rect = JC.CGRectMake(0, 64, JOG.SCREEN_WIDTH, JOG.SCREEN_HEIGHT - 64);
        var tableView = UITableView.alloc().initWithFrame_style_(rect, 
                                                               JOG.UITableViewStyleGrouped);
        self.view().addSubview_(tableView);
        tableView.setDelegate_(self);
        tableView.setBounces_(false);
        tableView.setDataSource_(self);
        tableView.setSectionFooterHeight_(4);
        tableView.setSectionHeaderHeight_(4);
        tableView.setBackgroundColor_(JOG.RGB(0xF5F5F9));
        tableView.setTableHeaderView_(
                            UIView.alloc().initWithFrame_(JC.CGRectMake(0,0,375,0.01)));
        tableView.setSeparatorStyle_(JOG.UITableViewCellSeparatorStyleNone);
        self.JOSetIvar('_tableView', tableView);
    }
    return self.JOGetIvar('_tableView');
},
```

以上是通过懒加载的方式创建tableView，其通过`self.JOGetIvar('_tableView')`来获取成员对象是否已经有值，没有则创建，完成后调用`self.JOSetIvar('_tableView', tableView);`赋值。

`'_tableView'`，成员变量name，如果没有手动修改名字，默认都是`'_'`+name。



6、特殊方法`JOGetIvarI`，`JOSetIvaI`，这两者和上面两者类似，不同之处在于其负责操作基础数据类型。



#### C函数调用

##### JC对象 (C方法在js中关联的全局对象)

看过JOBridge实现原理就知道，C函数会被转成OC方法来调用，然后走JOBridge通用调用桥。默认添加在了全局对象JC名下，目前选取了GCD，Foundation，UIKit，CGRect，CGPath，CGColor，CGContext，CGAffineTransform，CGImage，CGBitmapContext，Math大部分常用函数，CoreFundation方法太多就只添加了几个。如果有需要，可以参照上面的扩展C方法，自行添加。

举些例子

```javascript
//ImageContext
JC.UIGraphicsBeginImageContextWithOptions(JC.CGSizeMake(r.width, r.height), false, UIScreen.mainScreen().scale());
//这是一个包裹指针的JOPointerObj对象，js不用处理，直接传给C/OC即可
var context = JC.UIGraphicsGetCurrentContext();
JC.CGContextSetStrokeColorWithColor(context, UIColor.redColor().CGColor());
JC.CGContextSetLineWidth(context, 2);

//CGD
var aself = __weak(self);
JC.dispatch__async(JC.dispatch__get__main__queue(),['v@',function()
{
    JOC.log('dispatch_async is work ' + aself);
}]);
//CGRect
JC.CGRectMake(0, 0, JOG.SCREEN_WIDTH, 45)；
//Math
JC.pow(10, -5 * JC.sinh(numTime * JOG.M_PI_2))
```

#####JOG对象 (OC全局常量在js中的关联对象)

Foundation和UIKit下的绝大多数全局常量都被包含在内，顺带加上了GCD，方便使用。

```javascript
JOG.M_PI_2;
//Foundation
JOG.NSFontAttributeName;
JOG.NSForegroundColorAttributeName;
JOG.NSCalendarUnitSecond;
JOG.NSUTF8StringEncoding;
//UIKit
JOG.UIStatusBarStyleDefault;
JOG.UITableViewCellAccessoryDisclosureIndicator;
JOG.UIApplicationStateBackground;
JOG.UIControlStateNormal;
//GCD
JOG.DISPATCH_SOURCE_TYPE_TIMER;
JOG.DISPATCH_QUEUE_SERIAL
```



另外JOG下还可以添加不走"JOBridge通用调用桥"的方法。

```javascript
JOG.RGB(0xFF0000);
```

对应实现见下方，其需要手动处理参数然后调用对应UIColor创建方法，最后调用JOGetObj包装成JOObj对象返回。

```objective-c
pluginStore[@"RGB"] = ^(JSValue *jsvalue) {
    uint32_t hex = [jsvalue toUInt32] ;
    return JOGetObj([UIColor colorWithRed:(((hex & 0xFF0000) >> 16))/255.0 green:(((hex & 0xFF00) >> 8))/255.0 blue:((hex & 0xFF))/255.0 alpha:1.0]);
};
```

#### null处理

对于可能为空的数据，调用方法之前，一定要检查null，否则会js报错。



### 实例一：

简单的UITableView使用

```javascript
;JOC.interface('JDViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>',
{
   data:['NSMutableArray','strong'],
   tableView:['UITableView','strong'],
}, {
   viewDidLoad:function() {
       var arr = JOC.class('NSMutableArray').alloc().init();
       
       arr.addObject_('这是第1个cell');
       arr.addObject_('这是第2个cell');
       arr.addObject_('这是第3个cell');
       self.setData_(arr);
       
       self.setTitle_('JDViewController');
       self.view().setBackgroundColor_(JOC.class('UIColor').whiteColor());
       
       
       var rect = JC.CGRectMake(0, 60, 375, 500);
       var r = JOC.structToObject(rect);
       JOC.log(r.x + ' ' + r.y + '  ' + r.width + ' ' + r.height);
       
       var tableView = JOC.class('UITableView').alloc()
       .initWithFrame_style_(rect,JOG.UITableViewStyleGrouped);
       tableView.setDelegate_(self);
       tableView.setDataSource_(self);
       self.view().addSubview_(tableView);
       self.setTableView_(tableView);
   },
               
   viewDidAppear_:function(animated) {
      
   },
               
   numberOfSectionsInTableView_: function(tableView) {
       return 1;
   },
               
   tableView_numberOfRowsInSection_: function(tableView, section) {
       return self.data().count();
   },
               
   tableView_cellForRowAtIndexPath_: function(tableView, indexPath) {
       JOC.log('tableVIew: '+ tableView);
       
       var cell = tableView.dequeueReusableCellWithIdentifier_('cell')
       if (!cell) {
           cell = JOC.class('UITableViewCell').alloc()
           .initWithStyle_reuseIdentifier_(JOG.UITableViewCellStyleValue1, 'cell')
       }
               
       cell.textLabel().setText_(self.data().objectAtIndex_(indexPath.row()));
       return cell;
   },
               
   tableView_heightForRowAtIndexPath_: function(tableView, indexPath) {
       return 88;
   },
               
   tableView_didSelectRowAtIndexPath_: function(tableView, indexPath) {
       var alertView = JOC.class('UIAlertView').alloc()
       .initWithTitle_message_delegate_cancelButtonTitle_otherButtonTitles_
       ('Alert',
        'cell has been clicked',
        self,
        'OK',
        null);
        
       alertView.show();
   },
});

```



### 实例二

使用CoreGraphics画一只简单的时钟。

```javascript
;JOC.interface('WatchView : UIView', {
    timer:['id','strong'],
    time:['id','strong'],
    back:['id','strong'],
 },
 {
    init : function() {
        var inited = self.JOSUPER_init();
        if (inited) {
            JOC.storeObject(self, inited);
            self.setTime_(NSMutableDictionary.dictionary());

            var timer = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(1, self, JOC.selector('timeTick'), null, true);
            timer.fire();
            self.JOSetIvar('_timer', timer);
        }
        return self;
    },
    invalidate: ['v@:', function() {
        self.timer().invalidate();
    }],
    timeTick : ['v@:', function() {
        var calendar = JOC.class('NSCalendar').currentCalendar();
        var unitFlags = JOG.NSCalendarUnitYear | JOG.NSCalendarUnitMonth | JOG.NSCalendarUnitDay | JOG.NSCalendarUnitHour | JOG.NSCalendarUnitMinute | JOG.NSCalendarUnitSecond;
                        
        var comps = calendar.components_fromDate_(unitFlags, NSDate.date());
        var hour = comps.hour();

        self.time().setValue_forKey_(parseInt(hour/12) ? hour - 12 : hour, 'hour');
        self.time().setValue_forKey_(comps.minute(), 'min');
        self.time().setValue_forKey_(comps.second(), 'sec');

        self.setNeedsDisplay();
     }],
    drawRect_ : function(rect) {
        self.setBackgroundColor_(UIColor.blackColor());
        var back = self.back();
        var r = JOC.structToObject(rect);
        var centerX = r.width/2.0;
        var centerY = r.height/2.0;

        if (!back) {
            JC.UIGraphicsBeginImageContextWithOptions(JC.CGSizeMake(r.width, r.height), false, UIScreen.mainScreen().scale());
            var context = JC.UIGraphicsGetCurrentContext();
            JC.CGContextSetStrokeColorWithColor(context, UIColor.redColor().CGColor());
            JC.CGContextSetLineWidth(context, 2);
            JC.CGContextMoveToPoint(context, centerX, centerY - 0.5);
            JC.CGContextAddLineToPoint(context, centerX, centerY + 0.5)
            JC.CGContextSetLineCap(context, 1);
            JC.CGContextStrokePath(context);
            self.drawWithContext_angle_rotateCenterX_Y_(context, JOG.M_PI_2, centerX, centerY);
            back = JC.UIGraphicsGetImageFromCurrentImageContext();
            self.setBack_(back);
            JC.UIGraphicsEndImageContext();
        }
        back = self.back();
        if (back) {
            back.drawInRect_(JC.CGRectMake(0,0,r.width, r.height));
        }
        var context = JC.UIGraphicsGetCurrentContext();
        self.drawIndicatorWithContext_angle_rotateCenterX_Y_(context, JOG.M_PI_2, centerX, centerY);
    }, 
    drawIndicatorWithContext_angle_rotateCenterX_Y_ : ['v@:*ddd',function(context, angle, x, y) {
        var time = self.JOGetIvar('_time');
        var sec = time.objectForKey_('sec');
        var min = time.objectForKey_('min');
        var hour = time.objectForKey_('hour');
        JC.CGContextSaveGState(context);
        self.rotateWithContext_angle_fromCenterX_Y_(context, angle, x, y);

        
        JC.CGContextSaveGState(context);
        JC.CGContextSetStrokeColorWithColor(context, UIColor.whiteColor().CGColor());
        self.rotateWithContext_angle_fromCenterX_Y_(context, 2 * JOG.M_PI * sec / 60, x, y);
        JC.CGContextSetLineWidth(context, 0.5);
        JC.CGContextMoveToPoint(context, x / 3.0, y);
        JC.CGContextAddLineToPoint(context, x, y - 1);
        JC.CGContextAddLineToPoint(context, x + x / 8.0, y);
        JC.CGContextAddLineToPoint(context, x, y + 1);
        JC.CGContextAddLineToPoint(context, x / 3.0, y);
        JC.CGContextStrokePath(context);
        JC.CGContextRestoreGState(context);


        JC.CGContextSaveGState(context);
        JC.CGContextSetStrokeColorWithColor(context, UIColor.whiteColor().CGColor());
        self.rotateWithContext_angle_fromCenterX_Y_(context, 2 * JOG.M_PI * min / 60 + 2 * JOG.M_PI * sec / 60.0 / 60.0, x, y);
        JC.CGContextSetLineWidth(context, 0.5);
        JC.CGContextMoveToPoint(context, x / 2.0, y);
        JC.CGContextAddLineToPoint(context, x, y - 3);
        JC.CGContextAddLineToPoint(context, x + x / 10.0, y);
        JC.CGContextAddLineToPoint(context, x, y + 3);
        JC.CGContextAddLineToPoint(context, x / 2.0, y);
        JC.CGContextStrokePath(context);
        JC.CGContextRestoreGState(context);

        JC.CGContextSaveGState(context);
        JC.CGContextSetStrokeColorWithColor(context, UIColor.whiteColor().CGColor());
        self.rotateWithContext_angle_fromCenterX_Y_(context, 2 * JOG.M_PI * hour / 12 + 2 * JOG.M_PI * min / 60.0 / 12.0, x, y);
        JC.CGContextSetLineWidth(context, 0.5);
        JC.CGContextMoveToPoint(context, x / 1.5, y);
        JC.CGContextAddLineToPoint(context, x, y - 5);
        JC.CGContextAddLineToPoint(context, x + x / 15.0, y);
        JC.CGContextAddLineToPoint(context, x, y + 5);
        JC.CGContextAddLineToPoint(context, x / 1.5, y);
        JC.CGContextStrokePath(context);
        JC.CGContextRestoreGState(context);

        JC.CGContextRestoreGState(context);

    }],

    drawWithContext_angle_rotateCenterX_Y_ : ['v@:*ddd',function(context, angle, centerX, centerY) {
        JC.CGContextSaveGState(context);
        self.rotateWithContext_angle_fromCenterX_Y_(context, angle, centerX, centerY);
        JC.CGContextSetStrokeColorWithColor(context, UIColor.whiteColor().CGColor());
        var font = UIFont.fontWithName_size_('Helvetica', centerX/6);
        var stringAttrs = NSDictionary.dictionaryWithObjects_forKeys_(JOC.array([font, UIColor.whiteColor()]) , JOC.array([JOG.NSFontAttributeName, JOG.NSForegroundColorAttributeName]));

        for (var i = 0; i < 60; ++i) {
            var width = 0;
            var x = 0;
            var len = 0;
            var attrStr = null;
            if (i % 15 == 0) {
                width = centerX/30;
                x = 0;
                len = centerX/10;
                var str = NSString.JOVAR_stringWithFormat_('@@:@q','%d', (parseInt(i/5) != 0 ? parseInt(i/5) : 12));
                attrStr = NSAttributedString.alloc().initWithString_attributes_(str, stringAttrs);
            } else if (i % 5 == 0) {
                width = centerX/50;
                x = centerX/30;
                len = centerX/10;
                attrStr = NSAttributedString.alloc().initWithString_attributes_(NSString.JOVAR_stringWithFormat_('@@:@q','%d', parseInt(i/5)), stringAttrs);
            } else {
                width = centerX/100;
                x = centerX/20;
                len = centerX/10;
            }
            JC.CGContextSetLineWidth(context, width);
            JC.CGContextMoveToPoint(context, x, centerY);
            JC.CGContextAddLineToPoint(context, len, centerY);
            JC.CGContextStrokePath(context);

            if (attrStr) {
                attrStr.drawAtPoint_(JC.CGPointMake(centerX/5, centerY - centerX/15));
            }
            self.rotateWithContext_angle_fromCenterX_Y_(context, 2 * JOG.M_PI / 60.0 , centerX, centerY);
        }
        JC.CGContextRestoreGState(context);
    }],
  
    rotateWithContext_angle_fromCenterX_Y_ : ['v@:*ddd',function(context, angle, x, y) {
        JC.CGContextTranslateCTM(context, x, y);
        JC.CGContextRotateCTM(context, angle);
        JC.CGContextTranslateCTM(context, -x, -y);
    }]
 });
```

