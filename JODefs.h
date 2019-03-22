//
//  JODefs.h
//  JOBridge
//
//  Created by Wei on 2019/1/28.
//  Copyright © 2019年 Wei. All rights reserved.
//

#ifndef JODefs_h
#define JODefs_h

#if !defined(JOEXTERN)
#if defined(__cplusplus)
#define JOEXTERN extern "C"
#else
#define JOEXTERN extern
# endif
#endif

#if !defined(JOVERLOAD)
#if __has_extension(attribute_overloadable)
#define JOVERLOAD __attribute__((overloadable))
#else
#define JOVERLOAD
#endif
#endif

#if !defined(JOBOXABLE)
#if __has_attribute(objc_boxable)
#define JOBOXABLE __attribute__((objc_boxable))
#else
#define JOBOXABLE
#endif
#endif

#if !defined(JOLOADER)
#if __has_attribute(constructor)
#define JOLOADER(p) __attribute__((constructor(p)))
#else
#define JOLOADER(p)
#endif
#endif


#if !defined(JOPTNONE)
#if __has_attribute(optnone)
#define JOPTNONE __attribute__((optnone))
#else
#define JOPTNONE
#endif
#endif

#if !defined(JONOSUBCLASS)
#if __has_attribute(objc_subclassing_restricted)
#define JONOSUBCLASS __attribute__((objc_subclassing_restricted))
#else
#define JONOSUBCLASS
#endif
#endif



#if !defined(JOINLINE)
#define JOINLINE __attribute__((__always_inline__))
#endif

#if !defined(JOSTATICINLINE)
#define JOSTATICINLINE static inline
#endif


#ifndef JOLog
#define JOLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#endif

#ifndef JOTOPTR
#define JOTOPTR (__bridge void *)
#endif

#ifndef JOTOID
#define JOTOID (__bridge id)
#endif



#endif /* JODefs_h */
