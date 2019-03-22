//
//  JOBlock.h
//  JOBridge
//
//  Created by Wei on 2018/11/13.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "JODefs.h"

typedef struct JOBlockDescriptor {
    void *reserved;
    unsigned long int size;
    void (*copy)(void *dst, const void *src);
    void *dispose;
    const char *signature;//目前可能使用size，copy，signatrue字段，其他占位即可
    void *layout;
} JOBlockDescriptor;

typedef struct JOBlock {
    Class isa;
    short int retainCount;
    short int flag;
    int token;
    void *BlockFunctionPtr;
    JOBlockDescriptor *descriptor;//目前可能使用retainCount，descriptor，其他占位即可
    
    //捕获的参数
    __unsafe_unretained JSValue *jsFunction;
    char *sign;
} JOBlock;


JOEXTERN JOINLINE char *JOCopySgin(NSString *sgin);
JOEXTERN JOINLINE JOBlock *JOCopyBlock(id block, const char *blockSgin);

#endif
