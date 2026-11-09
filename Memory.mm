#import "Memory.h"
#import <mach-o/dyld.h>
#import <string.h>
#import <math.h>

uintptr_t Memory::GetModuleBase(const char* name) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* image = _dyld_get_image_name(i);
        if (image && strstr(image, name)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

bool Memory::Read(uintptr_t addr, void* buf, size_t len) {
    if (!addr || !buf || !len) return false;
    vm_size_t out = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(), (vm_address_t)addr, len, (vm_address_t)buf, &out);
    return kr == KERN_SUCCESS && out == len;
}

bool Memory::Write(uintptr_t addr, const void* buf, size_t len) {
    if (!addr || !buf || !len) return false;
    kern_return_t kr = vm_write(mach_task_self(), (vm_address_t)addr, (vm_offset_t)buf, (mach_msg_type_number_t)len);
    return kr == KERN_SUCCESS;
}

bool Memory::WorldToScreen(const Vector3& world, Vector2& screen, const Matrix4x4& vm, float width, float height) {
    float w = vm.m[3] * world.x + vm.m[7] * world.y + vm.m[11] * world.z + vm.m[15];
    if (w < 0.01f) return false;

    float x = vm.m[0] * world.x + vm.m[4] * world.y + vm.m[8]  * world.z + vm.m[12];
    float y = vm.m[1] * world.x + vm.m[5] * world.y + vm.m[9]  * world.z + vm.m[13];

    screen.x = (width  / 2.0f) * (1.0f + x / w);
    screen.y = (height / 2.0f) * (1.0f - y / w);
    return true;
}

std::string ReadIl2CppString(uintptr_t strPtr) {
    if (!strPtr) return "";
    // Il2CppString: +0x10 length (int32), +0x14 chars
    int32_t len = Memory::Read<int32_t>(strPtr + 0x10);
    if (len <= 0 || len > 64) return "";
    std::string out;
    out.reserve(len);
    for (int i = 0; i < len; i++) {
        char16_t c = Memory::Read<char16_t>(strPtr + 0x14 + i * 2);
        if (c < 128) out += (char)c;
    }
    return out;
}