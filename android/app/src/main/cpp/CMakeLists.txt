# M33 — Native hardening + decoy library.
#   memek.so    : entry point utama (WAJIB, JNI export)
#   aegis.so    : tamper / signature comparator (part a)
#   cipher.so   : opaque predicate + XOR/rot cipher (part b)
#   vault.so    : premium token verifier (part c)
#   keychain.so : penyimpan API key AI (M22, XOR-obfuscated)
cmake_minimum_required(VERSION 3.22.1)
project(claude48native LANGUAGES CXX ASM)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# EXPECTED_SIG_SHA256 dilempar dari gradle -DEXPECTED_SIG_SHA256="...".
if(NOT DEFINED EXPECTED_SIG_SHA256)
    set(EXPECTED_SIG_SHA256 "")
endif()
add_definitions(-DEXPECTED_SIG_SHA256="${EXPECTED_SIG_SHA256}")

# M33 — Keychain rolling-XOR encoded AI key list.
if(NOT DEFINED KEYCHAIN_XOR_HEX)
    set(KEYCHAIN_XOR_HEX "")
endif()
add_definitions(-DKEYCHAIN_XOR_HEX="${KEYCHAIN_XOR_HEX}")

# Harden every native target. RELRO/NOW protects GOT, noexecstack blocks
# executable stack, hidden visibility keeps internal symbols out of dynsym.
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN 1)
set(CMAKE_CXX_FLAGS_RELEASE "-O2 -fvisibility=hidden -fvisibility-inlines-hidden -fno-rtti -fno-exceptions -ffunction-sections -fdata-sections -fstack-protector-strong -D_FORTIFY_SOURCE=2")
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "-Wl,--gc-sections -Wl,--strip-all -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now")

add_library(aegis    SHARED aegis.cpp)
add_library(cipher   SHARED cipher.cpp)
add_library(vault    SHARED vault.cpp)
add_library(keychain SHARED keychain.cpp)
add_library(sentinel SHARED sentinel.cpp)
add_library(memek    SHARED memek.cpp)

# Build a 25 MiB decoy payload into libidinganteng.so. The generated payload
# lives in the CMake build tree, never in source control.
set(IDINGANTENG_BLOB "${CMAKE_CURRENT_BINARY_DIR}/idinganteng_blob.bin")
add_custom_command(
    OUTPUT "${IDINGANTENG_BLOB}"
    COMMAND "${CMAKE_COMMAND}"
            -DOUTPUT_FILE=${IDINGANTENG_BLOB}
            -DTARGET_SIZE=26214400
            -P "${CMAKE_CURRENT_SOURCE_DIR}/gen_garbage.cmake"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/gen_garbage.cmake"
    COMMENT "[idinganteng] Generating 26214400-byte decoy blob"
    VERBATIM)
add_custom_target(idinganteng_blob DEPENDS "${IDINGANTENG_BLOB}")
set(BLOB_PATH "${IDINGANTENG_BLOB}")
configure_file(idinganteng_blob.S.in
               "${CMAKE_CURRENT_BINARY_DIR}/idinganteng_blob.S" @ONLY)
set_source_files_properties(
    "${CMAKE_CURRENT_BINARY_DIR}/idinganteng_blob.S"
    PROPERTIES OBJECT_DEPENDS "${IDINGANTENG_BLOB}")
add_library(idinganteng SHARED
    idinganteng.cpp
    "${CMAKE_CURRENT_BINARY_DIR}/idinganteng_blob.S")
add_dependencies(idinganteng idinganteng_blob)

find_library(log-lib log)

target_link_libraries(aegis    ${log-lib})
target_link_libraries(cipher   ${log-lib})
target_link_libraries(vault    ${log-lib})
target_link_libraries(keychain ${log-lib})
target_link_libraries(sentinel ${log-lib})
target_link_libraries(idinganteng ${log-lib})
target_link_libraries(memek    aegis cipher vault keychain sentinel ${log-lib})
