#import "MenuView.h"

@implementation MenuView {
    UILabel *_title;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithWhite:0.07 alpha:0.94];
        self.layer.cornerRadius = 16;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
        self.clipsToBounds = YES;

        _title = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, 240, 26)];
        _title.text = @"FF PANEL  ·  olliE";
        _title.textColor = UIColor.whiteColor;
        _title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [self addSubview:_title];

        CGFloat y = 52;
        [self addSwitch:@"ESP Master"   key:@"esp"   y:&y];
        [self addSwitch:@"Box ESP"      key:@"box"   y:&y];
        [self addSwitch:@"Snaplines"    key:@"line"  y:&y];
        [self addSwitch:@"Names"        key:@"name"  y:&y];
        [self addSwitch:@"Aimbot"       key:@"aim"   y:&y];
        [self addSwitch:@"No Recoil"    key:@"recoil" y:&y];
        [self addSwitch:@"No Spread"    key:@"spread" y:&y];
        [self addSwitch:@"Speed Boost"  key:@"speed"  y:&y];

        self.espOn = self.boxOn = self.lineOn = self.nameOn = YES;
        self.aimOn = self.noRecoilOn = self.noSpreadOn = self.speedOn = NO;
        self.softDisable = NO;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(softDisable:)
                                                     name:@"FFSoftDisable"
                                                   object:nil];
    }
    return self;
}

- (void)addSwitch:(NSString *)title key:(NSString *)key y:(CGFloat *)y {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, *y, 150, 28)];
    l.text = title;
    l.textColor = UIColor.whiteColor;
    l.font = [UIFont systemFontOfSize:13.5];
    [self addSubview:l];

    UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectMake(200, *y - 2, 51, 31)];
    s.onTintColor = [UIColor systemPinkColor];
    s.tag = key.hash;
    [s addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:s];
    *y += 42;
}

- (void)toggled:(UISwitch *)s {
    if (self.softDisable) {
        s.on = NO;
        return;
    }
    NSUInteger t = s.tag;
    if (t == @"esp".hash)   self.espOn = s.on;
    if (t == @"box".hash)   self.boxOn = s.on;
    if (t == @"line".hash)  self.lineOn = s.on;
    if (t == @"name".hash)  self.nameOn = s.on;
    if (t == @"aim".hash)   self.aimOn = s.on;
    if (t == @"recoil".hash) self.noRecoilOn = s.on;
    if (t == @"spread".hash) self.noSpreadOn = s.on;
    if (t == @"speed".hash)  self.speedOn = s.on;
}

- (void)softDisable:(NSNotification *)n {
    self.softDisable = YES;
    self.espOn = self.boxOn = self.lineOn = self.nameOn = NO;
    self.aimOn = self.noRecoilOn = self.noSpreadOn = self.speedOn = NO;
}
@end