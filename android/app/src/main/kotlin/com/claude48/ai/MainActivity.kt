package com.claude48.ai

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import androidx.multidex.MultiDex
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/// M7 — MainActivity bridge JNI ke native .so:
///   - memek.so   : entry point utama (integrity + premium gate)
///   - aegis.so   : tamper detector (part a)
///   - cipher.so  : opaque predicate + string decrypt (part b)
///   - vault.so   : premium token verifier (part c)
class MainActivity : FlutterActivity() {
    private val channel = "com.claude48.ai/native"

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "integrityCheck" -> {
                            val sig = currentSignatureSha256()
                            val ok = NativeBridge.integrityCheck(this, sig)
                            result.success(ok)
                        }
                        "verifyPremium" -> {
                            val token = call.argument<String>("token") ?: ""
                            val streakDays = call.argument<Int>("streakDays") ?: 0
                            result.success(NativeBridge.verifyPremium(token, streakDays))
                        }
                        "encryptField" -> {
                            val plain = call.argument<String>("plain") ?: ""
                            result.success(NativeBridge.encryptField(plain))
                        }
                        "decryptField" -> {
                            val cipher = call.argument<String>("cipher") ?: ""
                            result.success(NativeBridge.decryptField(cipher))
                        }
                        "currentSignature" -> result.success(currentSignatureSha256())
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("NATIVE_ERR", t.message, null)
                }
            }
    }

    private fun currentSignatureSha256(): String {
        return try {
            val pm = packageManager
            val sigs: Array<Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = pm.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                info.signingInfo?.apkContentsSigners ?: emptyArray()
            } else {
                @Suppress("DEPRECATION")
                val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                info.signatures ?: emptyArray()
            }
            if (sigs.isEmpty()) return ""
            val md = MessageDigest.getInstance("SHA-256")
            md.update(sigs[0].toByteArray())
            md.digest().joinToString("") { "%02X".format(it) }
        } catch (_: Throwable) {
            ""
        }
    }
}

/// JNI stub — implementasi asli ada di libmemek.so.
/// Nama class dan method WAJIB stabil (di-keep di proguard) supaya
/// dynamic linker JNI bisa resolve simbol `Java_com_claude48_ai_NativeBridge_*`.
object NativeBridge {
    init {
        // Urutan load penting: dependency lib duluan, terakhir baru memek.
        System.loadLibrary("vault")
        System.loadLibrary("cipher")
        System.loadLibrary("aegis")
        System.loadLibrary("memek")
    }

    @JvmStatic external fun integrityCheck(ctx: Context, runtimeSigSha256: String): Boolean
    @JvmStatic external fun verifyPremium(token: String, streakDays: Int): Boolean
    @JvmStatic external fun encryptField(plain: String): String
    @JvmStatic external fun decryptField(cipher: String): String
}
