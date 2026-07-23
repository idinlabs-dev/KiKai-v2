// M7 — memek.so : entry point utama.
// Semua export JNI ke Java class `com.claudememek.app.NativeBridge`.
//
// Load order: vault → cipher → aegis → memek (di Kotlin).
// Symbol dari sibling .so di-link static via CMake target_link_libraries.

#include <jni.h>
#include <string>
#include <cstring>

// Forward decl dari sibling libs
bool aegis_verify_sig(const char* expected, const char* runtime);
std::string cipher_encrypt(const std::string& plain);
std::string cipher_decrypt(const std::string& hex);
bool vault_verify_token(const std::string& token, int streakDays);
std::string keychain_get_keys();
int keychain_get_dataset_key();
int sentinel_probe();

namespace {

// Ambil #define EXPECTED_SIG_SHA256 dari gradle CMake args.
#ifndef EXPECTED_SIG_SHA256
#define EXPECTED_SIG_SHA256 ""
#endif

std::string jstr(JNIEnv* env, jstring s) {
    if (!s) return "";
    const char* c = env->GetStringUTFChars(s, nullptr);
    std::string out(c ? c : "");
    if (c) env->ReleaseStringUTFChars(s, c);
    return out;
}

jstring to_j(JNIEnv* env, const std::string& s) {
    return env->NewStringUTF(s.c_str());
}

} // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_com_claudememek_app_NativeBridge_integrityCheck(
        JNIEnv* env, jclass, jobject /*ctx*/, jstring runtimeSig) {
    const char* expected = EXPECTED_SIG_SHA256;
    std::string runtime = jstr(env, runtimeSig);
    bool ok = aegis_verify_sig(expected, runtime.c_str());
    return ok ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_claudememek_app_NativeBridge_verifyPremium(
        JNIEnv* env, jclass, jstring token, jint streakDays) {
    std::string t = jstr(env, token);
    return vault_verify_token(t, static_cast<int>(streakDays)) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_claudememek_app_NativeBridge_encryptField(
        JNIEnv* env, jclass, jstring plain) {
    return to_j(env, cipher_encrypt(jstr(env, plain)));
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_claudememek_app_NativeBridge_decryptField(
        JNIEnv* env, jclass, jstring hex) {
    return to_j(env, cipher_decrypt(jstr(env, hex)));
}

// M22 — getApiKeys : return CSV daftar AI API key hasil deobfuscation
// keychain.so. Kosong → caller (ApiKeyService) fallback ke --dart-define.
extern "C" JNIEXPORT jstring JNICALL
Java_com_claudememek_app_NativeBridge_getApiKeys(
        JNIEnv* env, jclass) {
    return to_j(env, keychain_get_keys());
}



// M32 — expose dataset XOR key (dari keychain.so) via JNI.
extern "C" JNIEXPORT jint JNICALL
Java_com_claudememek_app_NativeBridge_getDatasetKey(
        JNIEnv* /*env*/, jclass) {
    return (jint) keychain_get_dataset_key();
}

// M33 — runtime detector bitmask: debugger=1, instrumentation=2, root=4,
// emulator=8. Dart policy decides which bits are fatal.
extern "C" JNIEXPORT jint JNICALL
Java_com_claudememek_app_NativeBridge_sentinelProbe(
        JNIEnv* /*env*/, jclass) {
    return static_cast<jint>(sentinel_probe());
}

// JNI_OnLoad — verifikasi versi + registrasi tag.
extern "C" JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM* vm, void* /*reserved*/) {
    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }
    return JNI_VERSION_1_6;
}
