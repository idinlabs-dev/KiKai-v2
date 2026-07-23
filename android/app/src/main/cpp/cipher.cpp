// M7 — Part (b): opaque predicate + XOR/rot cipher untuk field sensitif
// (mis. email token cache). Bukan crypto grade — cukup untuk menyulitkan
// static reverse engineering.

#include <string>
#include <cstdint>
#include <cstring>

namespace {

constexpr uint8_t ROT = 0x2B;
constexpr uint8_t POLY[8] = { 0x9F, 0x11, 0x77, 0xC4, 0x03, 0xAB, 0x5E, 0xE2 };

[[gnu::noinline]] uint8_t mix(uint8_t b, size_t i) {
    uint8_t p = POLY[i & 7];
    uint8_t r = static_cast<uint8_t>((b + ROT) ^ p);
    // opaque: (x^x)==0 selalu
    volatile uint8_t z = static_cast<uint8_t>(i);
    z ^= z;
    return static_cast<uint8_t>(r ^ z);
}

[[gnu::noinline]] uint8_t unmix(uint8_t b, size_t i) {
    uint8_t p = POLY[i & 7];
    return static_cast<uint8_t>((b ^ p) - ROT);
}

const char* HEX = "0123456789ABCDEF";

std::string to_hex(const std::string& raw) {
    std::string out;
    out.resize(raw.size() * 2);
    for (size_t i = 0; i < raw.size(); ++i) {
        uint8_t b = static_cast<uint8_t>(raw[i]);
        out[i * 2]     = HEX[(b >> 4) & 0x0F];
        out[i * 2 + 1] = HEX[b & 0x0F];
    }
    return out;
}

int hexval(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

std::string from_hex(const std::string& hex) {
    if (hex.size() % 2) return "";
    std::string out;
    out.resize(hex.size() / 2);
    for (size_t i = 0; i < out.size(); ++i) {
        int hi = hexval(hex[i * 2]);
        int lo = hexval(hex[i * 2 + 1]);
        if (hi < 0 || lo < 0) return "";
        out[i] = static_cast<char>((hi << 4) | lo);
    }
    return out;
}

} // namespace

__attribute__((visibility("default")))
std::string cipher_encrypt(const std::string& plain) {
    std::string enc;
    enc.resize(plain.size());
    for (size_t i = 0; i < plain.size(); ++i) {
        enc[i] = static_cast<char>(mix(static_cast<uint8_t>(plain[i]), i));
    }
    return to_hex(enc);
}

__attribute__((visibility("default")))
std::string cipher_decrypt(const std::string& hex) {
    std::string raw = from_hex(hex);
    std::string out;
    out.resize(raw.size());
    for (size_t i = 0; i < raw.size(); ++i) {
        out[i] = static_cast<char>(unmix(static_cast<uint8_t>(raw[i]), i));
    }
    return out;
}
