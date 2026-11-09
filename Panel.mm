#import "Panel.h"

@implementation FFPanel {
    MenuView *_menu;
    UIWindow *_win;
    UIButton *_floatBtn;
    BOOL _menuVisible;
}

+ (instancetype)shared {
    static FFPanel *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [FFPanel new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _menuVisible = NO;
        CGRect screen = UIScreen.mainScreen.bounds;

        _win = [[UIWindow alloc] initWithFrame:screen];
        _win.windowLevel = UIWindowLevelStatusBar + 200;
        _win.backgroundColor = UIColor.clearColor;
        _win.userInteractionEnabled = YES;
        _win.rootViewController = [UIViewController new];
        _win.rootViewController.view.backgroundColor = UIColor.clearColor;

        // floating open button — always visible
        _floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _floatBtn.frame = CGRectMake(screen.size.width - 64, screen.size.height * 0.35, 52, 52);
        _floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.45 alpha:0.92];
        _floatBtn.layer.cornerRadius = 26;
        _floatBtn.layer.borderWidth = 1.5;
        _floatBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
        [_floatBtn setTitle:@"FF" forState:UIControlStateNormal];
        _floatBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        [_floatBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [_floatBtn addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBtn:)];
        [_floatBtn addGestureRecognizer:pan];
        [_win.rootViewController.view addSubview:_floatBtn];

        _menu = [[MenuView alloc] initWithFrame:CGRectMake(16, 100, 280, 420)];
        _menu.hidden = YES;
        [_win.rootViewController.view addSubview:_menu];
    }
    return self;
}

- (void)show {
    _win.hidden = NO;
    [_win makeKeyAndVisible];
}

- (void)hide {
    _menu.hidden = YES;
    _menuVisible = NO;
}

- (void)toggle {
    _menuVisible = !_menuVisible;
    _menu.hidden = !_menuVisible;
    if (_menuVisible) {
        _win.hidden = NO;
        [_win makeKeyAndVisible];
    }
}

- (void)dragBtn:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:_win];
    CGPoint c = _floatBtn.center;
    c.x += t.x;
    c.y += t.y;
    CGFloat r = 26;
    CGRect b = _win.bounds;
    c.x = MAX(r, MIN(b.size.width - r, c.x));
    c.y = MAX(r + 40, MIN(b.size.height - r - 40, c.y));
    _floatBtn.center = c;
    [g setTranslation:CGPointZero inView:_win];
}

- (MenuView *)menu {
    return _menu;
}
@end
