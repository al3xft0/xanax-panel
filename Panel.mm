#import "Panel.h"

@implementation FFPanel {
    MenuView *_menu;
    UIWindow *_win;
}

+ (instancetype)shared {
    static FFPanel *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [FFPanel new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        CGRect b = UIScreen.mainScreen.bounds;
        _win = [[UIWindow alloc] initWithFrame:b];
        _win.windowLevel = UIWindowLevelAlert + 120;
        _win.hidden = YES;
        _win.backgroundColor = UIColor.clearColor;
        _win.rootViewController = [UIViewController new];

        _menu = [[MenuView alloc] initWithFrame:CGRectMake(18, 110, 270, 400)];
        [_win.rootViewController.view addSubview:_menu];

        // volume-down long press gesture can be added later
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggle)];
        tap.numberOfTouchesRequired = 3;
        [_win.rootViewController.view addGestureRecognizer:tap];
    }
    return self;
}

- (void)show {
    _win.hidden = NO;
    [_win makeKeyAndVisible];
}

- (void)hide {
    _win.hidden = YES;
}

- (void)toggle {
    if (_win.hidden) [self show]; else [self hide];
}

- (MenuView *)menu {
    return _menu;
}
@end