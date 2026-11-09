#pragma once
#include <cstdint>
#include <mach/mach.h>
#include <dlfcn.h>
#include <string>

struct Vector3 {
    float x, y, z;
    Vector3() : x(0), y(0), z(0) {}
    Vector3(float X, float Y, float Z) : x(X), y(Y), z(Z) {}
    float Distance(const Vector3& o) const {
        float dx = x - o.x, dy = y - o.y, dz = z - o.z;
        return sqrtf(dx*dx + dy*dy + dz*dz);
    }
};

struct Vector2 {
    float x, y;
    Vector2() : x(0), y(0) {}
    Vector2(float X, float Y) : x(X), y(Y) {}
};

struct Matrix4x4 {
    float m[16];
};

class Memory {
public:
    static uintptr_t GetModuleBase(const char* name);
    static bool Read(uintptr_t addr, void* buf, size_t len);
    static bool Write(uintptr_t addr, const void* buf, size_t len);

    template<typename T>
    static T Read(uintptr_t addr) {
        T v{};
        Read(addr, &v, sizeof(T));
        return v;
    }

    template<typename T>
    static bool Write(uintptr_t addr, T val) {
        return Write(addr, &val, sizeof(T));
    }

    static uintptr_t ReadPtr(uintptr_t addr) {
        return Read<uintptr_t>(addr);
    }

    static Vector3 ReadVec3(uintptr_t addr) {
        return Read<Vector3>(addr);
    }

    static bool WorldToScreen(const Vector3& world, Vector2& screen, const Matrix4x4& vm, float width, float height);
};

// simple string helper for Il2Cpp strings (length-prefixed)
std::string ReadIl2CppString(uintptr_t strPtr);