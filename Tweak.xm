#import <UIKit/UIKit.h>
#import <substrate.h>
#import <mach-o/dyld.h>
#import "Offsets.h"
#import "Memory.h"
#import "AntiBan.h"
#import "Panel.h"

static uintptr_t g_il2cpp = 0;
static uintptr_t g_unity  = 0;
static MenuView *g_menu = nil;

// ---------------------------------------------------------------
//  Runtime base resolve
// ---------------------------------------------------------------
static void ResolveBases() {
    g_il2cpp = Memory::GetModuleBase("UnityFramework") ?: Memory::GetModuleBase("il2cpp");
    g_unity  = Memory::GetModuleBase("UnityPlayer")   ?: g_il2cpp;
    if (!g_il2cpp) g_il2cpp = Memory::GetModuleBase("freefireth");
}

// ---------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------
static uintptr_t GetLocalPlayer() {
    if (!g_il2cpp) return 0;
    uintptr_t init = Memory::ReadPtr(g_il2cpp + Off::InitBase);
    if (!init) return 0;
    uintptr_t klass = Memory::ReadPtr(init + Off::StaticClass);
    if (!klass) return 0;
    uintptr_t match = Memory::ReadPtr(klass + Off::CurrentMatch);
    if (!match) return 0;
    return Memory::ReadPtr(match + Off::LocalPlayer);
}

static uintptr_t GetEntityList(int *countOut) {
    if (!g_il2cpp) return 0;
    uintptr_t init = Memory::ReadPtr(g_il2cpp + Off::InitBase);
    if (!init) return 0;
    uintptr_t klass = Memory::ReadPtr(init + Off::StaticClass);
    if (!klass) return 0;
    uintptr_t match = Memory::ReadPtr(klass + Off::CurrentMatch);
    if (!match) return 0;

    // DictionaryEntities or LocalEntities depending on season
    uintptr_t dict = Memory::ReadPtr(match + Off::DictionaryEntities);
    if (!dict) dict = Memory::ReadPtr(match + Off::Match_LocalEntities);
    if (!dict) return 0;

    // typical Il2Cpp dictionary / list layout (entries + count)
    // count often at +0x18 or +0x10 — adjust if needed
    int count = Memory::Read<int>(dict + 0x18);
    if (count <= 0 || count > 120) count = Memory::Read<int>(dict + 0x10);
    if (countOut) *countOut = count;
    return dict;
}

static Vector3 GetPlayerPos(uintptr_t player) {
    if (!player) return {};
    uintptr_t physx = Memory::ReadPtr(player + Off::Player_PhysXData);
    if (!physx) return {};
    // Transform chain: PhysX → TransformNode → Transform → world pos
    // many seasons keep world pos near PhysX + 0x60 or via TransformNode
    uintptr_t node = Memory::ReadPtr(physx + Off::TransformNode_Transform);
    if (node) {
        uintptr_t transform = Memory::ReadPtr(node + 0x8);
        if (transform) {
            uintptr_t data = Memory::ReadPtr(transform + 0x8);
            if (data) return Memory::ReadVec3(data + 0x60);
        }
    }
    // fallback direct
    return Memory::ReadVec3(physx + 0x60);
}

static Vector3 GetBonePos(uintptr_t player, uintptr_t boneOff) {
    if (!player) return {};
    uintptr_t bone = Memory::ReadPtr(player + boneOff);
    if (!bone) return GetPlayerPos(player);
    // bone → transform → world
    uintptr_t transform = Memory::ReadPtr(bone + 0x8);
    if (!transform) return GetPlayerPos(player);
    uintptr_t data = Memory::ReadPtr(transform + 0x8);
    if (!data) return GetPlayerPos(player);
    return Memory::ReadVec3(data + 0x60);
}

static bool IsEnemy(uintptr_t player, uintptr_t local) {
    if (!player || !local || player == local) return false;
    if (Memory::Read<bool>(player + Off::Player_IsDead)) return false;
    if (Memory::Read<bool>(player + Off::Player_IsBot)) return false; // optional: keep bots if wanted
    // team check — simple: different TeamModeID or service group
    int teamA = Memory::Read<int>(player + Off::TeamModeID);
    int teamB = Memory::Read<int>(local  + Off::TeamModeID);
    return teamA != teamB;
}

// ---------------------------------------------------------------
//  Feature loops
// ---------------------------------------------------------------
static void ApplyNoRecoil(uintptr_t local) {
    if (!g_menu.noRecoilOn || !local) return;
    uintptr_t weapon = Memory::ReadPtr(local + Off::Weapon);
    if (!weapon) return;
    uintptr_t profile = Memory::ReadPtr(weapon + Off::Weapon_GunFeelProfile);
    if (!profile) return;

    Memory::Write<bool>(profile + Off::WGP_EnableRecoil, false);
    Memory::Write<bool>(profile + Off::WGP_EnableVisualRecoil, false);
    Memory::Write<bool>(profile + Off::WGP_EnableGunFeel, false);
    Memory::Write<float>(profile + Off::WGP_HipRecoilPitchScale, 0.f);
    Memory::Write<float>(profile + Off::WGP_HipRecoilYawScale, 0.f);
    Memory::Write<float>(profile + Off::WGP_AdsRecoilPitchScale, 0.f);
    Memory::Write<float>(profile + Off::WGP_AdsRecoilYawScale, 0.f);
}

static void ApplyNoSpread(uintptr_t local) {
    if (!g_menu.noSpreadOn || !local) return;
    uintptr_t weapon = Memory::ReadPtr(local + Off::Weapon);
    if (!weapon) return;
    uintptr_t profile = Memory::ReadPtr(weapon + Off::Weapon_GunFeelProfile);
    if (!profile) return;

    Memory::Write<bool>(profile + Off::WGP_EnableSpread, false);
    Memory::Write<float>(profile + Off::WGP_HipSpreadLimit, 0.f);
    Memory::Write<float>(profile + Off::WGP_AdsSpreadLimit, 0.f);
    Memory::Write<float>(profile + Off::WGP_HipSpreadStart, 0.f);
    Memory::Write<float>(profile + Off::WGP_AdsSpreadStart, 0.f);
    Memory::Write<float>(profile + Off::WGP_HipSpreadStepPerShot, 0.f);
    Memory::Write<float>(profile + Off::WGP_AdsSpreadStepPerShot, 0.f);
}

static void ApplySpeed(uintptr_t local) {
    if (!g_menu.speedOn || !local) return;
    uintptr_t attrs = Memory::ReadPtr(local + Off::LocalPlayerAttributes);
    if (!attrs) return;
    Memory::Write<float>(attrs + Off::RunSpeedUpScale, 1.35f);
    Memory::Write<float>(attrs + Off::ForceSetRunAndDashSpeed, 1.25f);
}

static void AimbotTick(uintptr_t local, const Matrix4x4& vm, float sw, float sh) {
    if (!g_menu.aimOn || !local) return;

    int count = 0;
    uintptr_t list = GetEntityList(&count);
    if (!list || count <= 0) return;

    float bestDist = 9999.f;
    Vector3 bestHead{};
    bool found = false;

    // naive iteration — real dictionary needs entry array walk
    // for many seasons entries live at list + 0x18 (array) then stride
    uintptr_t entries = Memory::ReadPtr(list + 0x18);
    if (!entries) entries = Memory::ReadPtr(list + 0x10);

    for (int i = 0; i < count && i < 80; i++) {
        uintptr_t player = Memory::ReadPtr(entries + 0x20 + i * 0x10); // typical
        if (!player) player = Memory::ReadPtr(entries + i * 0x8);
        if (!IsEnemy(player, local)) continue;

        Vector3 head = GetBonePos(player, Off::Bones_Head);
        Vector2 screen;
        if (!Memory::WorldToScreen(head, screen, vm, sw, sh)) continue;

        float cx = sw * 0.5f, cy = sh * 0.5f;
        float d = hypotf(screen.x - cx, screen.y - cy);
        if (d < bestDist && d < 180.f) { // FOV
            bestDist = d;
            bestHead = head;
            found = true;
        }
    }

    if (!found) return;

    // silent aim path — overwrite bullet ray direction / start
    // sAim2 → HitObjectInfo → sAim3 (RayDir) / sAim4 (StartPos)
    uintptr_t aimInfo = Memory::ReadPtr(local + Off::sAim2);
    if (aimInfo) {
        Vector3 origin = GetPlayerPos(local);
        Vector3 dir = {
            bestHead.x - origin.x,
            bestHead.y - origin.y,
            bestHead.z - origin.z
        };
        float len = sqrtf(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z);
        if (len > 0.01f) {
            dir.x /= len; dir.y /= len; dir.z /= len;
            Memory::Write<Vector3>(aimInfo + Off::sAim3, dir);
            Memory::Write<Vector3>(aimInfo + Off::sAim4, origin);
        }
    }
}

// ---------------------------------------------------------------
//  Overlay draw (simple UIView based)
// ---------------------------------------------------------------
@interface FFOverlay : UIView
@end
@implementation FFOverlay
- (void)drawRect:(CGRect)rect {
    if (!g_menu || g_menu.softDisable || !g_menu.espOn) return;

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    float sw = self.bounds.size.width;
    float sh = self.bounds.size.height;

    uintptr_t local = GetLocalPlayer();
    if (!local) return;

    // view matrix
    uintptr_t cam = Memory::ReadPtr(local + Off::FollowCamera);
    if (!cam) return;
    uintptr_t mainCam = Memory::ReadPtr(cam + Off::Camera);
    if (!mainCam) return;
    Matrix4x4 vm = Memory::Read<Matrix4x4>(mainCam + Off::ViewMatrix);

    int count = 0;
    uintptr_t list = GetEntityList(&count);
    if (!list || count <= 0) return;

    uintptr_t entries = Memory::ReadPtr(list + 0x18);
    if (!entries) entries = Memory::ReadPtr(list + 0x10);

    for (int i = 0; i < count && i < 80; i++) {
        uintptr_t player = Memory::ReadPtr(entries + 0x20 + i * 0x10);
        if (!player) player = Memory::ReadPtr(entries + i * 0x8);
        if (!IsEnemy(player, local)) continue;

        Vector3 head = GetBonePos(player, Off::Bones_Head);
        Vector3 root = GetBonePos(player, Off::Bones_Root);
        Vector2 hs, rs;
        if (!Memory::WorldToScreen(head, hs, vm, sw, sh)) continue;
        if (!Memory::WorldToScreen(root, rs, vm, sw, sh)) continue;

        float h = fabsf(rs.y - hs.y);
        float w = h * 0.45f;
        CGRect box = CGRectMake(hs.x - w*0.5f, hs.y, w, h);

        if (g_menu.boxOn) {
            CGContextSetStrokeColorWithColor(ctx, [UIColor systemPinkColor].CGColor);
            CGContextSetLineWidth(ctx, 1.4);
            CGContextStrokeRect(ctx, box);
        }
        if (g_menu.lineOn) {
            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1 alpha:0.55].CGColor);
            CGContextMoveToPoint(ctx, sw*0.5f, sh);
            CGContextAddLineToPoint(ctx, hs.x, hs.y);
            CGContextStrokePath(ctx);
        }
        if (g_menu.nameOn) {
            uintptr_t namePtr = Memory::ReadPtr(player + Off::Player_Name);
            std::string name = ReadIl2CppString(namePtr);
            if (!name.empty()) {
                NSString *ns = [NSString stringWithUTF8String:name.c_str()];
                [ns drawAtPoint:CGPointMake(box.origin.x, box.origin.y - 14)
                 withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:10],
                                  NSForegroundColorAttributeName:UIColor.whiteColor}];
            }
        }
    }
}
@end

static FFOverlay *g_overlay = nil;

static void StartOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *key = nil;
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (w.isKeyWindow) { key = w; break; }
        }
        if (!key) key = UIApplication.sharedApplication.keyWindow;
        if (!key) return;

        g_overlay = [[FFOverlay alloc] initWithFrame:key.bounds];
        g_overlay.userInteractionEnabled = NO;
        g_overlay.backgroundColor = UIColor.clearColor;
        g_overlay.opaque = NO;
        [key addSubview:g_overlay];

        // redraw timer
        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:g_overlay selector:@selector(setNeedsDisplay)];
        [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}

// ---------------------------------------------------------------
//  Feature tick (every ~80 ms)
// ---------------------------------------------------------------
static void FeatureTick() {
    if (!g_menu || g_menu.softDisable) return;
    if (![[AntiBan shared] isSafe]) return;

    uintptr_t local = GetLocalPlayer();
    if (!local) return;

    ApplyNoRecoil(local);
    ApplyNoSpread(local);
    ApplySpeed(local);

    float sw = UIScreen.mainScreen.bounds.size.width;
    float sh = UIScreen.mainScreen.bounds.size.height;
    uintptr_t cam = Memory::ReadPtr(local + Off::FollowCamera);
    if (cam) {
        uintptr_t mainCam = Memory::ReadPtr(cam + Off::Camera);
        if (mainCam) {
            Matrix4x4 vm = Memory::Read<Matrix4x4>(mainCam + Off::ViewMatrix);
            AimbotTick(local, vm, sw, sh);
        }
    }
}

// ---------------------------------------------------------------
//  Hooks
// ---------------------------------------------------------------
%hook UIApplication
- (void)sendEvent:(UIEvent *)event {
    %orig;
}
%end

%ctor {
    ResolveBases();
    [[AntiBan shared] start];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[AntiBan shared] isSafe]) {
            [[FFPanel shared] show];
            g_menu = [[FFPanel shared] menu];
            StartOverlay();
        }
    });

    // feature loop
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                                     dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), 80ull * NSEC_PER_MSEC, 10ull * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(timer, ^{ FeatureTick(); });
    dispatch_resume(timer);
}