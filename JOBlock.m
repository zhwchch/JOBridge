//
//  JOBlock.m
//  JOBridge
//
//  Created by Wei on 2018/11/13.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import "JOBlock.h"
#import <objc/runtime.h>
#import "JOObject.h"
#import "JOTools.h"
#import <os/lock.h>
#import <pthread.h>

static NSMutableDictionary *_JOBlockSigns = nil;
static void * _JOBlockLock;


JOLOADER(112) void JOBlockInit() {
    _JOBlockSigns = [NSMutableDictionary dictionary];
    JOTools.initLock((void **)&_JOBlockLock);
}

void JODisposeHelper(JOBlock *src) {
    JOTools.release(src->jsFunction);
    free(src->descriptor);
}
/* 拷贝一个签名到堆上并返回，同时缓存 */
JOINLINE char *JOCopySgin(NSString *sign) {
    JOTools.lock(_JOBlockLock);

    JOPointerObj *obj = _JOBlockSigns[sign];
    void *blockSgin = NULL;
    if (obj) {
        blockSgin = JOUnmakePointerOrSelObj(obj).ptr;;
    } else {
        const char *type = [sign UTF8String];
        size_t len = strlen(type) + 1;
        blockSgin = malloc(len);
        memcpy(blockSgin, type, len);
        _JOBlockSigns[sign] = JOMakePointerObj(blockSgin);
    }
    
    JOTools.unlock(_JOBlockLock);
    
    return blockSgin;
}
/*
 关注JOBridge中处理JS传过来的block（js function）参数，其都被一个无参数无返回值的block处理，这是一个原型block，其签名只有一个，
 但该block会调用各种不同的js function，也就意味着要处理不同的参数和返回值。如果串行调用，每次根据传入js function的签名修改即可，
 但如果存在异步操作，就会出问题，所以签名必须和js function对应，而实际上我这里只处理参数，所以只需要关注签名是否一致，不需要关注
 函数名。
 为了确保在执行过程中JOSwizzle的JOGlobalParamsResolver取到正确的签名，需要将block拷贝一份，调用copy或者_Block_copy都不行，
 其检查flags时跳过了拷贝。所以这里只能构造相同的结构体来手动拷贝，_JOBlock与原型block对应，拷贝block，descriptor和sign。最后将
 修改descriptor和sign。
 */
JOINLINE JOBlock *JOCopyBlock(id block, const char *blockSgin) {
    
    //_Block_copy;
    
    JOBlock *blockPtr = JOTOPTR block;
    JOBlockDescriptor *blockDescriptor = malloc(sizeof(JOBlockDescriptor));
    JOBlock *blockCopy = malloc(sizeof(JOBlock));
    
    memcpy((void*)blockCopy, (void*)blockPtr, sizeof(JOBlock));
    memcpy(blockDescriptor, blockPtr->descriptor, sizeof(JOBlockDescriptor));
    //blockDescriptor->copy = (void *)_JOCopyHelper;
    blockDescriptor->copy(blockCopy, blockPtr);
    blockDescriptor->dispose = (void *)JODisposeHelper;
    blockCopy->retainCount = 0x0;
    blockCopy->descriptor = blockDescriptor;
    blockCopy->descriptor->signature = blockSgin;
    
    return blockCopy;
}
#endif
