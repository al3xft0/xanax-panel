#import "Panel.h"

@implementation FFPanel {
    MenuView *_menu;
    UIButton *_floatBtn;
    BOOL _menuVisible;
    BOOL _built;
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
        _built = NO;
    }
    return self;
}

- (void)buildUIIfNeeded {
    if (_built) return;
    _built = YES;

    CGRect screen = UIScreen.mainScreen.bounds;

    _floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _floatBtn.frame = CGRectMake(screen.size.width - 70, screen.size.height * 0.40, 56, 56);
    _floatBtn.backgroundColor = [UIColor colorWithRed:1 green:0.15 blue:0.40 alpha:1.0];
    _floatBtn.layer.cornerRadius = 28;
    _floatBtn.layer.borderWidth = 2.5;
    _floatBtn.layer.borderColor = UIColor.whiteColor.CGColor;
    _floatBtn.layer.shadowColor = UIColor.blackColor.CGColor;
    _floatBtn.layer.shadowOpacity = 0.6;
    _floatBtn.layer.shadowRadius = 8;
    [_floatBtn setTitle:@"FF" forState:UIControlStateNormal];
    _floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [_floatBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [_floatBtn addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBtn:)];
    [_floatBtn addGestureRecognizer:pan];

    _menu = [[MenuView alloc] initWithFrame:CGRectMake(12, 80, 300, 440)];
    _menu.hidden = YES;

    NSLog(@"[FFPanel] UI built — button + menu ready");
}

- (void)attachToOverlayWindow:(UIWindow *)win {
    if (!win) return;
    [self buildUIIfNeeded];

    UIView *root = win.rootViewController.view;
    if (!root) return;

    if (_floatBtn.superview != root) {
        [_floatBtn removeFromSuperview];
        [_menu removeFromSuperview];
        [root addSubview:_floatBtn];
        [root addSubview:_menu];
    }
    [root bringSubviewToFront:_menu];
    [root bringSubviewToFront:_floatBtn];
    NSLog(@"[FFPanel] attached to overlay window");
}

- (void)show {
    // no-op if overlay not ready; Tweak drives attach
}

- (void)hide {
    _menu.hidden = YES;
    _menuVisible = NO;
}

- (void)toggle {
    NSLog(@"[FFPanel] toggle tapped, wasVisible=%d", _menuVisible);
    _menuVisible = !_menuVisible;
    _menu.hidden = !_menuVisible;
    if (_menu.superview) {
        [_menu.superview bringSubviewToFront:_menu];
        [_menu.superview bringSubviewToFront:_floatBtn];
    }
}

- (void)dragBtn:(UIPanGestureRecognizer *)g {
    UIView *parent = _floatBtn.superview;
    if (!parent) return;
    CGPoint t = [g translationInView:parent];
    CGPoint c = _floatBtn.center;
    c.x += t.x; c.y += t.y;
    CGFloat r = 28;
    CGRect b = parent.bounds;
    c.x = MAX(r, MIN(b.size.width - r, c.x));
    c.y = MAX(r + 40, MIN(b.size.height - r - 40, c.y));
    _floatBtn.center = c;
    [g setTranslation:CGPointZero inView:parent];
}

- (MenuView *)menu {
    [self buildUIIfNeeded];
    return _menu;
}
@end
