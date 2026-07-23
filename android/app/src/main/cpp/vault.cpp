// M7 — Part (c): premium token verifier.
// Token dari backend format: "<streakDays>:<hmacHex>" — di-hash lagi lokal
// dengan salt embedded (XOR-scrambled) supaya kalau attacker fake token
// tanpa tahu salt, verifier menolak.
//
// Ini bukan pengganti server-side validation — hanya lapisan tambahan supaya
// modifikasi APK yang paksa `premiumActive = true` di Dart code langsung
// gagal karena native ikut ditanya.

#include <string>
#include <cstdint>
#include <cstring>

namespace {

// Salt "cl4ud3-4-8-premium-2026" di-XOR 0x33 supaya tidak muncul di strings.
constexpr uint8_t SALT_ENC[] = {
    'c'^0x33,'l'^0x33,'4'^0x33,'u'^0x33,'d'^0x33,'3'^0x33,'-'^0x33,
    '4'^0x33,'-'^0x33,'8'^0x33,'-'^0x33,'p'^0x33,'r'^0x33,'e'^0x33,
    'm'^0x33,'i'^0x33,'u'^0x33,'m'^0x33,'-'^0x33,'2'^0x33,'0'^0x33,
    '2'^0x33,'6'^0x33
};

std::string salt() {
    std::string s;
    s.resize(sizeof(SALT_ENC));
    for (size_t i = 0; i < sizeof(SALT_ENC); ++i) s[i] = SALT_ENC[i] ^ 0x33;
    return s;
}

// FNV-1a 64-bit — cukup untuk anti-tamper lokal.
[[gnu::noinline]] uint64_t fnv1a(const std::string& s) {
    uint64_t h = 1469598103934665603ULL;
    for (char c : s) {
        h ^= static_cast<uint8_t>(c);
        h *= 1099511628211ULL;
    }
    return h;
}

std::string u64hex(uint64_t v) {
    static const char* H = "0123456789abcdef";
    std::string out;
    out.resize(16);
    for (int i = 15; i >= 0; --i) {
        out[i] = H[v & 0xF];
        v >>= 4;
    }
    return out;
}

} // namespace

__attribute__((visibility("default")))
std::string vault_expected_token(int streakDays) {
    std::string base = std::to_string(streakDays) + "|" + salt();
    return std::to_string(streakDays) + ":" + u64hex(fnv1a(base));
}

__attribute__((visibility("default")))
bool vault_verify_token(const std::string& token, int streakDays) {
    std::string expected = vault_expected_token(streakDays);
    if (expected.size() != token.size()) return false;
    uint8_t diff = 0;
    for (size_t i = 0; i < expected.size(); ++i) {
        diff |= static_cast<uint8_t>(expected[i] ^ token[i]);
    }
    return diff == 0;
}
