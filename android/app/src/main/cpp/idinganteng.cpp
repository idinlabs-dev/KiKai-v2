#include <jni.h>
#include <cstddef>
#include <cstdint>

extern const unsigned char idinganteng_blob_start[];
extern const unsigned char idinganteng_blob_end[];

namespace {
// Deliberately useless decoy strings and symbols. None of these participate
// in application security or business logic.
constexpr const char* kSampah[] = {
    "ngapain dibaca goblok, ini cuma sampah",
    "cape cape buka ghidra dapet beginian doang",
    "bypass_premium_palsu_jangan_seneng_dulu",
    "decrypt_api_key_bohongan_anjing",
    "root_check_palsu_buat_orang_kepo",
};

volatile std::uintptr_t kNoise = 0x1D1A6A7EU;
}

extern "C" JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM* vm, void* /*reserved*/) {
    JNIEnv* env = nullptr;
    if (!vm || vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }
    const auto blob_size = static_cast<std::size_t>(idinganteng_blob_end - idinganteng_blob_start);
    kNoise ^= blob_size;
    kNoise ^= static_cast<unsigned char>(kSampah[kNoise % 5][0]);
    return JNI_VERSION_1_6;
}

extern "C" __attribute__((visibility("default"), noinline))
int idinganteng_bypass_root_check() {
    return static_cast<int>((kNoise ^ 0xBAD00BADU) & 1U);
}

extern "C" __attribute__((visibility("default"), noinline))
const char* idinganteng_decrypt_api_key() {
    return kSampah[(kNoise >> 3U) % 5U];
}