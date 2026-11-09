#import <UIKit/UIKit.h>
#import "MenuView.h"

@interface FFPanel : NSObject
+ (instancetype)shared;
- (void)show;
- (void)hide;
- (void)toggle;
- (MenuView *)menu;
@end