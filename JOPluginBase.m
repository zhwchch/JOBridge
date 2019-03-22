//
//  JOPluginBase.m
//  JOBridge
//
//  Created by Wei on 2019/1/21.
//  Copyright © 2019 Wei. All rights reserved.
//

#if __arm64__

#import "JOPluginBase.h"
#import "JOBridge.h"

@implementation JOPluginBase

+ (void)initPlugin {
    
}

+ (NSMutableDictionary *)pluginStore {
    return nil;
}

+ (void)registerPlugin {
    [JOBridge registerPlugin:[self class]];
}
+ (void)registerObject:(id)obj name:(NSString *)name needTransform:(BOOL)needTransform {
    [JOBridge addObject:obj forKey:name needTransform:needTransform];
}

@end

#endif
