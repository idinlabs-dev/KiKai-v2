#include <android/log.h>
#include <sys/system_properties.h>
#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <string>

namespace {
constexpr int kDebugger = 1;
constexpr int kInstrumentation = 2;
constexpr int kRoot = 4;
constexpr int kEmulator = 8;

bool file_contains(const char* path, const char* const* needles, size_t needle_count) {
    FILE* file = std::fopen(path, "r");
    if (!file) return false;
    char line[1024];
    bool found = false;
    while (!found && std::fgets(line, sizeof(line), file)) {
        for (size_t i = 0; i < needle_count; ++i) {
            const char* needle = needles[i];
            if (needle && *needle && std::strstr(line, needle)) {
                found = true;
                break;
            }
        }
    }
    std::fclose(file);
    return found;
}

bool debugger_attached() {
    FILE* file = std::fopen("/proc/self/status", "r");
    if (!file) return true;
    char line[256];
    int tracer = 0;
    while (std::fgets(line, sizeof(line), file)) {
        if (std::sscanf(line, "TracerPid: %d", &tracer) == 1) break;
    }
    std::fclose(file);
    return tracer != 0;
}

bool instrumentation_found() {
    const char* map_needles[] = {
        "frida", "gum-js-loop", "gmain", "linjector",
        "xposed", "substrate", "riru", "zygisk"};
    const char* port_needles[] = {"69A2", "69A3", "6A62", "5D8A"};
    return file_contains("/proc/self/maps", map_needles, 8) ||
           file_contains("/proc/self/status", map_needles, 8) ||
           file_contains("/proc/net/tcp", port_needles, 4);
}

bool root_found() {
    constexpr const char* paths[] = {
        "/system/bin/su", "/system/xbin/su", "/sbin/su",
        "/system/app/Superuser.apk", "/data/adb/magisk",
        "/data/adb/ksu", "/data/adb/ap", "/cache/su"};
    for (const char* path : paths) {
        if (access(path, F_OK) == 0) return true;
    }
    char tags[PROP_VALUE_MAX] = {};
    __system_property_get("ro.build.tags", tags);
    return std::strstr(tags, "test-keys") != nullptr;
}

bool emulator_found() {
    char fingerprint[PROP_VALUE_MAX] = {};
    char model[PROP_VALUE_MAX] = {};
    char hardware[PROP_VALUE_MAX] = {};
    __system_property_get("ro.build.fingerprint", fingerprint);
    __system_property_get("ro.product.model", model);
    __system_property_get("ro.hardware", hardware);
    return std::strstr(fingerprint, "generic") || std::strstr(fingerprint, "unknown") ||
           std::strstr(model, "sdk_gphone") || std::strstr(model, "Emulator") ||
           std::strstr(hardware, "goldfish") || std::strstr(hardware, "ranchu");
}
} // namespace

__attribute__((visibility("default")))
int sentinel_probe() {
    int flags = 0;
    if (debugger_attached()) flags |= kDebugger;
    if (instrumentation_found()) flags |= kInstrumentation;
    if (root_found()) flags |= kRoot;
    if (emulator_found()) flags |= kEmulator;
    return flags;
}