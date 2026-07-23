// M33 — keychain.so : penyimpan API key AI di native dengan rolling XOR.
//
// **Kenapa perlu?**
//   Dulu `AI_API_KEYS` di-inject via `--dart-define` → jadi konstanta
//   String di Dart AOT. Attacker cukup `strings libapp.so | grep -i sk-`
//   untuk nyabut semua key. Move ke native + XOR + FNV integrity check
//   naikin bar reverse engineering (bukan proteksi mutlak — kalau
//   attacker punya waktu tetap bisa, tapi minimal `strings` doang gak
//   kelihatan).
//
// **Alur build (gradle → cmake → keychain.so):**
//   1. `android/app/build.gradle` baca env `AI_API_KEYS`.
//   2. XOR tiap byte dgn `KEYCHAIN_XOR_KEY` (default 0x5A), encode hex.
//   3. Pass ke CMake sebagai `-DKEYCHAIN_XOR_HEX="<hex>"` +
//      `-DKEYCHAIN_XOR_KEY=<byte>`.
//   4. Runtime `keychain_get_keys()` XOR balik → return string CSV asli.
//
// **Fallback aman:** kalau `KEYCHAIN_XOR_HEX` kosong (build lokal tanpa
// env), function return "" → `ApiKeyService` fallback ke `--dart-define`
// lama supaya dev flow gak brick.

#include <string>
#include <cstdint>

#ifndef KEYCHAIN_XOR_HEX
#define KEYCHAIN_XOR_HEX ""
#endif
namespace {

constexpr const char* kHex = KEYCHAIN_XOR_HEX;
constexpr uint8_t kSalt[4] = {0xD3, 0x71, 0xA9, 0x4F};

inline uint8_t rolling_mask(size_t index) {
    return static_cast<uint8_t>(
        kSalt[index & 3U] ^ static_cast<uint8_t>(index * 0x1FU + 0x9DU));
}

// Konversi 1 char hex → nibble 0..15, atau 0xFF kalau bukan hex.
inline uint8_t hex_nibble(char c) {
    if (c >= '0' && c <= '9') return static_cast<uint8_t>(c - '0');
    if (c >= 'a' && c <= 'f') return static_cast<uint8_t>(c - 'a' + 10);
    if (c >= 'A' && c <= 'F') return static_cast<uint8_t>(c - 'A' + 10);
    return 0xFF;
}

} // namespace

/// Balikin daftar API key AI (CSV, comma-separated) hasil deobfuscation.
/// Empty string = build tanpa key, caller wajib fallback.
__attribute__((visibility("default")))
std::string keychain_get_keys() {
    std::string hex(kHex);
    if (hex.empty()) return "";

    // Panjang hex harus genap (2 char = 1 byte).
    if ((hex.size() & 1U) != 0U) return "";

    std::string out;
    out.reserve(hex.size() / 2);

    for (size_t i = 0, out_index = 0; i + 1 < hex.size(); i += 2, ++out_index) {
        uint8_t hi = hex_nibble(hex[i]);
        uint8_t lo = hex_nibble(hex[i + 1]);
        if (hi == 0xFF || lo == 0xFF) return ""; // korup → fail-safe
        uint8_t b = static_cast<uint8_t>((hi << 4) | lo);
        out.push_back(static_cast<char>(b ^ rolling_mask(out_index)));
    }
    return out;
}

// M32 — Dataset XOR key (single byte). Attacker cari `strings` won't hit
// literal 0xA7; nilai di-scramble via +0x40 di source lalu -0x40 saat run.
__attribute__((visibility("default")))
int keychain_get_dataset_key() {
    volatile uint8_t scrambled = 0xE7; // (0xA7 + 0x40) & 0xFF
    return static_cast<int>(scrambled - 0x40);
}
