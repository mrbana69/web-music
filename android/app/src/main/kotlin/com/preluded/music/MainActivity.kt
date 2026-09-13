package com.preluded.music

import android.webkit.CookieManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.preluded.music/cookies"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            val cookieManager = CookieManager.getInstance()
            cookieManager.setAcceptCookie(true)
        } catch (_: Exception) {}

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCookies") {
                val url = call.argument<String>("url") ?: "https://music.youtube.com"
                try {
                    val cookieManager = CookieManager.getInstance()
                    cookieManager.flush()
                    val cookies = cookieManager.getCookie(url)
                    result.success(cookies ?: "")
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else if (call.method == "flushCookies") {
                try {
                    val cookieManager = CookieManager.getInstance()
                    cookieManager.flush()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else if (call.method == "clearCookies") {
                try {
                    val cookieManager = CookieManager.getInstance()
                    cookieManager.removeAllCookies(null)
                    cookieManager.flush()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
