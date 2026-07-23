// M7 — Part (a): tamper / signature comparator.
// Semua string di-XOR encode supaya `strings libaegis.so` gak bocor.
//
// ============================================================
// PRODUCTION MODE (re-enabled di M18.3)
// Signature verification AKTIF.
//
// Setelah M17 (release keystore permanen di GitHub Secrets) +
// M18 hotfix keystore, SHA-256 signing cert kini stabil antar build
// dan sudah di-inject sebagai secret `EXPECTED_SIG_SHA256`.
// Gradle forward ke CMake sebagai `-DEXPECTED_SIG_SHA256=...`,
// dan aegis_verify_sig membandingkan runtime cert dengan macro ini.
//
// Fallback aman: kalau macro `EXPECTED_SIG_SHA256` kosong (dev / build
// lokal tanpa secret), fungsi tetap return true → developer tidak
// terblokir saat `flutter run`.
//
// Cara kembali ke dev-bypass tanpa hapus signing check:
//   compile dengan `-DDEVELOPMENT_BUILD=1` via CMake args.
// ============================================================
#ifndef DEVELOPMENT_BUILD
#define DEVELOPMENT_BUILD 0
#endif

#include <jni.h>
#include <string>
#include <cstring>
#include <cstdint>

namespace {

// XOR key rotasi 4-byte, hasil di-decode saat runtime.
constexpr uint8_t K[4] = { 0x5A, 0xC3, 0x91, 0x7E };

std::string xor_decode(const uint8_t* data, size_t len) {
    std::string out;
    out.resize(len);
    for (size_t i = 0; i < len; ++i) out[i] = static_cast<char>(data[i] ^ K[i & 3]);
    return out;
}

// Opaque predicate: selalu true, tapi compiler tidak tahu.
// Buat bikin control flow noisy → dekompiler sulit baca.
[[gnu::noinline]] bool opaque_true(volatile int x) {
    return ((x * x) >= 0);
}

// Case-insensitive hex compare, konstan-waktu (biar tidak bocor timing).
[[gnu::noinline]] bool ct_hex_eq(const std::string& a, const std::string& b) {
    if (a.size() != b.size()) return false;
    uint8_t diff = 0;
    for (size_t i = 0; i < a.size(); ++i) {
        char ca = a[i]; char cb = b[i];
        if (ca >= 'a' && ca <= 'z') ca = ca - 32;
        if (cb >= 'a' && cb <= 'z') cb = cb - 32;
        diff |= static_cast<uint8_t>(ca ^ cb);
    }
    return diff == 0;
}

} // namespace

__attribute__((visibility("default")))
bool aegis_verify_sig(const char* expected, const char* runtime) {
#if DEVELOPMENT_BUILD
    // DEVELOPMENT MODE — bypass signature check.
    // Struktur guard (memek/aegis/cipher/vault + native bridge +
    // redirect flow di TamperGuard) tetap utuh, tinggal flip
    // DEVELOPMENT_BUILD → 0 untuk aktifkan lagi di release.
    (void)expected;
    (void)runtime;
    return true;
#else
    if (!expected || !*expected) return true; // dev mode
    if (!runtime || !*runtime) return false;

    volatile int noise = 7;
    if (!opaque_true(noise)) return false;

    std::string e(expected), r(runtime);
    return ct_hex_eq(e, r);
#endif
}

__attribute__((visibility("default")))
const char* aegis_tag() {
    // "aegis-v1" XOR-encoded
    static const uint8_t enc[] = { 'a'^K[0], 'e'^K[1], 'g'^K[2], 'i'^K[3],
                                   's'^K[0], '-'^K[1], 'v'^K[2], '1'^K[3] };
    static std::string cached = xor_decode(enc, sizeof(enc));
    return cached.c_str();
}
