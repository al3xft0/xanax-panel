#pragma once
#import <Foundation/Foundation.h>

@interface AntiBan : NSObject
+ (instancetype)shared;
- (void)start;
- (void)stop;
- (BOOL)isSafe;
@end