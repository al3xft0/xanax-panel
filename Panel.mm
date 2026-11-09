#import "Panel.h"

@implementation FFPanel {
    MenuView *_menu;
    UIButton *_floatBtn;
    UIView *_host;
    BOOL _menuVisible;
    BOOL _attached;
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
        _attached = NO;
    }
    return self;
}

- (UIWindow *)findKeyWindow {
    // LiveContainer / modern iOS: walk all windows
    UIWindow *best = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) return w;
            if (!best || w.windowLevel > best.windowLevel) best = w;
        }
    }
    // fallback
    if (!best) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        best = UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
    }
    if (!best) {
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (w.isKeyWindow) return w;
            best = w;
        }
    }
    return best;
}

- (void)buildUIIfNeeded {
    if (_floatBtn) return;

    CGRect screen = UIScreen.mainScreen.bounds;

    _floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _floatBtn.frame = CGRectMake(screen.size.width - 64, screen.size.height * 0.38, 54, 54);
    _floatBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.18 blue:0.42 alpha:0.95];
    _floatBtn.layer.cornerRadius = 27;
    _floatBtn.layer.borderWidth = 2.0;
    _floatBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.4].CGColor;
    _floatBtn.layer.shadowColor = UIColor.blackColor.CGColor;
    _floatBtn.layer.shadowOpacity = 0.45;
    _floatBtn.layer.shadowRadius = 6;
    _floatBtn.layer.shadowOffset = CGSizeMake(0, 2);
    [_floatBtn setTitle:@"FF" forState:UIControlStateNormal];
    _floatBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [_floatBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [_floatBtn addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBtn:)];
    [_floatBtn addGestureRecognizer:pan];

    _menu = [[MenuView alloc] initWithFrame:CGRectMake(14, 90, 290, 430)];
    _menu.hidden = YES;
}

- (void)attachToGame {
    [self buildUIIfNeeded];

    UIWindow *key = [self findKeyWindow];
    if (!key) {
        NSLog(@"[FFPanel] no keyWindow yet");
        return;
    }

    UIView *root = key.rootViewController.view ?: key;
    if (!root) return;

    // re-parent if window changed (LiveContainer sometimes swaps)
    if (_floatBtn.superview != root) {
        [_floatBtn removeFromSuperview];
        [_menu removeFromSuperview];
        [root addSubview:_floatBtn];
        [root addSubview:_menu];
        [root bringSubviewToFront:_floatBtn];
        [root bringSubviewToFront:_menu];
        _attached = YES;
        NSLog(@"[FFPanel] attached to %@", key);
    } else {
        [root bringSubviewToFront:_floatBtn];
        [root bringSubviewToFront:_menu];
    }
}

- (void)show {
    // called repeatedly from ctor + timer until it sticks
    dispatch_async(dispatch_get_main_queue(), ^{
        [self attachToGame];
    });
}

- (void)hide {
    _menu.hidden = YES;
    _menuVisible = NO;
}

- (void)toggle {
    [self attachToGame]; // ensure still on top
    _menuVisible = !_menuVisible;
    _menu.hidden = !_menuVisible;
    if (_menuVisible && _menu.superview) {
        [_menu.superview bringSubviewToFront:_menu];
        [_menu.superview bringSubviewToFront:_floatBtn];
    }
}

- (void)dragBtn:(UIPanGestureRecognizer *)g {
    UIView *parent = _floatBtn.superview;
    if (!parent) return;
    CGPoint t = [g translationInView:parent];
    CGPoint c = _floatBtn.center;
    c.x += t.x;
    c.y += t.y;
    CGFloat r = 27;
    CGRect b = parent.bounds;
    c.x = MAX(r, MIN(b.size.width - r, c.x));
    c.y = MAX(r + 50, MIN(b.size.height - r - 50, c.y));
    _floatBtn.center = c;
    [g setTranslation:CGPointZero inView:parent];
}

- (MenuView *)menu {
    return _menu;
}
@end
