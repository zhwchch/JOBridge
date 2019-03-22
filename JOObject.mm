//
//  JOObject.m
//  JOBridge
//
//  Created by Wei on 2018/9/21.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import "JOObject.h"
#import "JOTools.h"
#import <os/lock.h>
#import <pthread.h>
#import <unordered_map>


#pragma mark - HashMap Define

struct JOObjectPointerEqual {
    JOINLINE bool operator()(__unsafe_unretained id p1, __unsafe_unretained id p2) const {
        return p1 == p2;
    }
};

struct JOObjectPointerHash {
     JOINLINE uintptr_t operator()(__unsafe_unretained id obj) const {

        uintptr_t k = (uintptr_t)JOTOPTR obj;
        uintptr_t a = 0x4368726973746F70ULL;
        uintptr_t b = 0x686572204B616E65ULL;
        uintptr_t c = 1;
        a += k;
        
        a -= b; a -= c; a ^= (c >> 43);
        b -= c; b -= a; b ^= (a << 9);
        c -= a; c -= b; c ^= (b >> 8);
        a -= b; a -= c; a ^= (c >> 38);
        b -= c; b -= a; b ^= (a << 23);
        c -= a; c -= b; c ^= (b >> 5);
        a -= b; a -= c; a ^= (c >> 35);
        b -= c; b -= a; b ^= (a << 49);
        c -= a; c -= b; c ^= (b >> 11);
        a -= b; a -= c; a ^= (c >> 12);
        b -= c; b -= a; b ^= (a << 18);
        c -= a; c -= b; c ^= (b >> 22);

        return c;
    }
};

class JOObjectHashMap : public std::unordered_map<__unsafe_unretained id, __unsafe_unretained id, JOObjectPointerHash, JOObjectPointerEqual> {
};



#pragma mark - Static Variable Define

static void *JONullClass;
static void *JOBaseObjClass;
static void *JOObjClass;
static void *JOWeakObjClass;
static void *JOPointerObjClass;
static void *JOSelObjClass;

static JOObjectHashMap *_JOObjectInuseHashMap;
static __unsafe_unretained id *_JOObjectReuseArray;
static size_t _JOObjectReuseArrayOffset = 0;
static NSInteger _JOObjectReuseMax = 10240;//一个JOObj也就16Byte(isa和obj指针)，10240个也才160KB，也就是10个内存页大小


static dispatch_source_t JOObjectTimer;
static void * _JOObjectLock;


#define JO_RC_Right_Shift   45
#define JO_ISA_NonpointerBit   0x1
#define JO_OBJC_TAG_MASK (1ULL<<63)
#define JO_OBJC_POINTER_MASK (0x0000000FFFFFFFF8) // MACH_VM_MAX_ADDRESS 0x1000000000




//typedef struct _JOISA {
//    uintptr_t nonpointer        : 1;
//    uintptr_t has_assoc         : 1;
//    uintptr_t has_cxx_dtor      : 1;
//    uintptr_t shiftcls          : 33; // MACH_VM_MAX_ADDRESS 0x1000000000
//    uintptr_t magic             : 6;
//    uintptr_t weakly_referenced : 1;
//    uintptr_t deallocating      : 1;
//    uintptr_t has_sidetable_rc  : 1;
//    uintptr_t extra_rc          : 19;
//#       define RC_ONE   (1ULL<<45)
//#       define RC_HALF  (1ULL<<18)
//} _JOISA;

#pragma mark - Tools

//这里只获取的开始和末尾bit，也就不用定义isa的解析结构体了
JOINLINE uintptr_t JOGetRetainCount(__unsafe_unretained id obj) {
    if (!obj) return NSUIntegerMax;
    void *isa_p = JOTOPTR obj;
//    _JOISA isa = *(_JOISA *)isa_p;
//    if (isa.nonpointer) {
//        return isa.extra_rc;
//    } else {
//        return NSUIntegerMax;
//    }
    uintptr_t isa = (uintptr_t)*((uintptr_t *)isa_p);
    if (OS_EXPECT((isa & JO_ISA_NonpointerBit) == JO_ISA_NonpointerBit, 1)) {
        return isa >> JO_RC_Right_Shift;
    } else {
        return NSUIntegerMax;
    }
}


JOINLINE id JOGetLastObject(__unsafe_unretained id *array) {
    if (_JOObjectReuseArrayOffset <= 0) return nil;
    return array[_JOObjectReuseArrayOffset--];
}


JOINLINE void JOReuseTimeTick(){
    
    JOTools.lock(_JOObjectLock);
    
    double begin = CFAbsoluteTimeGetCurrent();

    for (JOObjectHashMap::iterator i = _JOObjectInuseHashMap->begin(); i != _JOObjectInuseHashMap->end();) {
        __unsafe_unretained JOObj * obj = i->second;
        if (JOGetRetainCount(obj) == 0) {
            obj.obj = nil;
            if (_JOObjectReuseArrayOffset < _JOObjectReuseMax) {
                _JOObjectReuseArray[_JOObjectReuseArrayOffset++] = obj;
            } else {
                JOTools.release(obj);
            }
            _JOObjectInuseHashMap->erase(i++);
        } else {
            ++i;
        }
    }
    NSLog(@"_JOObjectInuseHashMap:%lu    %lu    %f", _JOObjectInuseHashMap->size(),_JOObjectReuseArrayOffset, CFAbsoluteTimeGetCurrent()-begin);
    
    JOTools.unlock(_JOObjectLock);
}

JOLOADER(114) void JOObjectInit() {

    _JOObjectInuseHashMap = new JOObjectHashMap();
    _JOObjectReuseArray = (__unsafe_unretained id *)::malloc(_JOObjectReuseMax * 8);
    
    JONullClass = JOTOPTR NSNull.class;
    JOBaseObjClass = JOTOPTR JOBaseObj.class;
    JOObjClass = JOTOPTR JOObj.class;
    JOWeakObjClass = JOTOPTR JOWeakObj.class;
    JOPointerObjClass = JOTOPTR JOPointerObj.class;
    JOSelObjClass = JOTOPTR JOSelObj.class;

    JOTools.initLock((void **)&_JOObjectLock);
    
    dispatch_queue_t quene = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, DISPATCH_QUEUE_SERIAL);
    JOObjectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, quene);
    dispatch_source_set_timer(JOObjectTimer, DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC, 30ull * NSEC_PER_SEC);
    dispatch_source_set_event_handler(JOObjectTimer, ^{
        JOReuseTimeTick();
    });
    dispatch_resume(JOObjectTimer);
}


#pragma mark - Maker

JOINLINE JOPointerObj* JOMakePointerObj(void *p) {
    if (OS_EXPECT(!p, 0)) return nil;
    JOPointerObj *o = [[JOPointerObj alloc] init];
    o.ptr = p;
    return o;
}

JOINLINE JOWeakObj* JOMakeWeakObj(__unsafe_unretained id obj) {
    if (OS_EXPECT(!obj, 0)) return nil;
    JOWeakObj *o = [[JOWeakObj alloc] init];
    o.obj = obj;
    return o;
}

JOINLINE JOSelObj* JOMakeSelObj(SEL sel) {
    if (OS_EXPECT(!sel, 0)) return nil;
    JOSelObj *o = [[JOSelObj alloc] init];
    o.sel = sel;
    return o;
}

JOINLINE JOObj* JOMakeObj(__unsafe_unretained id obj) {
    if (OS_EXPECT(!obj, 0)) return nil;
    JOObj *o = [[JOObj alloc] init];
    o.obj = obj;
//    JOLog(@"%@",o);
//    JOTools.pc(obj, @"MakeObj");
    return o;
}

JOINLINE JOObj *JOGetObj(__unsafe_unretained id obj) {
    if (OS_EXPECT(!obj, 0)) return nil;

    JOTools.lock(_JOObjectLock);
    __unsafe_unretained JOObj *joObj = JOGetLastObject(_JOObjectReuseArray);
    if (joObj) {
        joObj.obj = obj;
    } else {
        JOObj* tmp = JOMakeObj(obj);
        JOTools.retain(tmp);
       joObj = tmp;
    }
    _JOObjectInuseHashMap->insert(JOObjectHashMap::value_type(joObj, joObj));

    JOTools.unlock(_JOObjectLock);

    return joObj;
}






#pragma mark - Unmaker
JOINLINE JODoubleWord JOUnmakeObj(__unsafe_unretained id obj) {
    if (!obj) return {0};

    void **p = (void **)JOTOPTR obj;
    if ((NSUInteger)p & JO_OBJC_TAG_MASK) {
        return (JODoubleWord){p};
    }
    uint64_t isa = *(uint64_t *)p;
    isa = isa & JO_OBJC_POINTER_MASK;
    if (OS_EXPECT(*(void **)isa == JOObjClass, 1)) {
        return (JODoubleWord){*(p + 1)};
    }
    return (JODoubleWord){p};
}


JOINLINE JODoubleWord JOUnmakeAnyObj(__unsafe_unretained id obj) {
    if (!obj) return {0};

    void **p = (void **)JOTOPTR obj;
    if ((NSUInteger)p & JO_OBJC_TAG_MASK) {
        return (JODoubleWord){p};
    }
    uint64_t isa = *(uint64_t *)p;
    isa = isa & JO_OBJC_POINTER_MASK;
    void *superClass = *((void **)isa + 1);
    
    if (OS_EXPECT(superClass == JOBaseObjClass, 1)) {
        return (JODoubleWord){*(p + 1)};
    } else if ((void *)isa == JONullClass) {
        return (JODoubleWord){NULL};
    }
    return (JODoubleWord){p};
}

JOINLINE JODoubleWord JOUnmakeWeakOrObj(__unsafe_unretained id obj) {
    if (!obj) return {0};
    
    void **p = (void **)JOTOPTR obj;
    if ((NSUInteger)p & JO_OBJC_TAG_MASK) {
        return (JODoubleWord){p};
    }
    uint64_t isa = *(uint64_t *)p;
    isa = isa & JO_OBJC_POINTER_MASK;
    if ((void *)isa == JOObjClass
        || (void *)isa == JOWeakObjClass) {
        return (JODoubleWord){*(p + 1)};
    }
    return (JODoubleWord){p};
}
JOINLINE JODoubleWord JOUnmakePointerOrSelObj(__unsafe_unretained id obj) {
    if (!obj) return {0};

    void **p = (void **)JOTOPTR obj;
    if ((NSUInteger)p & JO_OBJC_TAG_MASK) {
        return (JODoubleWord){NULL};
    }
    uint64_t isa = *(uint64_t *)p;
    isa = isa & JO_OBJC_POINTER_MASK;
    if ((void *)isa == JOPointerObjClass) {
        return (JODoubleWord){*(p + 1)};
    }
    return (JODoubleWord){NULL};
}

#pragma mark - Class Define

@implementation JOBaseObj
@end;

@implementation JOPointerObj
- (NSString *)description {
    return [NSString stringWithFormat:@"<JOPointerObj:%p:%p>", self, self.ptr];
}
- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<JOPointerObj:%p:%p>", self, self.ptr];
}
@end;

@implementation JOWeakObj
- (NSString *)description {
    return [NSString stringWithFormat:@"<JOWeakObj:%p:%@>", self, self.obj];
}
- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<JOWeakObj:%p:%@>", self, self.obj];
}
@end;

@implementation JOSelObj
- (NSString *)description {
    return [NSString stringWithFormat:@"<JOSelObj:%p:%@>", self, NSStringFromSelector(self.sel)];
}
- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<JOSelObj:%p:%@>", self, NSStringFromSelector(self.sel)];
}
@end;

@implementation JOObj
- (NSString *)description {
    return [NSString stringWithFormat:@"<JOObj:%p:%@>", self, self.obj];
}
- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<JOObj:%p:%@>", self, self.obj];
}
- (void)dealloc {
//    JOLog(@"dealloc %@", _obj);
}
@end;
#endif

