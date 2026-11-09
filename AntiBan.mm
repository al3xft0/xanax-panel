#import "AntiBan.h"
#import <substrate.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>

@implementation AntiBan {
    BOOL _running;
    dispatch_source_t _timer;
}

+ (instancetype)shared {
    static AntiBan *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [AntiBan new]; });
    return s;
}

- (void)start {
    if (_running) return;
    _running = YES;

    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_LIBRARY_PATH");
    unsetenv("DYLD_FORCE_FLAT_NAMESPACE");

    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                    dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 0),
                              5ull * NSEC_PER_SEC, 1ull * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_timer, ^{ [self scan]; });
    dispatch_resume(_timer);
}

- (void)stop {
    if (!_running) return;
    _running = NO;
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

- (BOOL)isSafe {
    return ![self debuggerAttached] && ![self suspiciousModules];
}

- (BOOL)debuggerAttached {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info = {};
    size_t sz = sizeof(info);
    if (sysctl(mib, 4, &info, &sz, NULL, 0) == 0)
        return (info.kp_proc.p_flag & P_TRACED) != 0;
    return NO;
}

- (BOOL)suspiciousModules {
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        NSString *s = [NSString stringWithUTF8String:name].lowercaseString;
        if ([s containsString:@"frida"] ||
            [s containsString:@"gadget"] ||
            [s containsString:@"cycript"] ||
            [s containsString:@"substrate"] ||
            [s containsString:@"libhooker"] ||
            [s containsString:@"ellekit"] ||
            [s containsString:@"dopamine"]) {
            return YES;
        }
    }
    return NO;
}

- (void)scan {
    if ([self debuggerAttached] || [self suspiciousModules]) {
        // soft kill — features go dark, panel stays
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FFSoftDisable" object:nil];
    }
}
@end