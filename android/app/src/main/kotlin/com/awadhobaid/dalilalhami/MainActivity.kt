package com.awadhobaid.dalilalhami

import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val APP_SHARE_CHANNEL = "com.awadhobaid.dalilalhami/app_share"
        private const val SHARE_METHOD = "shareApp"
        private const val DEFAULT_CHOOSER_TITLE = "مشاركة تطبيق دليل الحامي"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_SHARE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                SHARE_METHOD -> {
                    val text = call.argument<String>("text")?.trim().orEmpty()
                    val subject = call.argument<String>("subject")?.trim().orEmpty()
                    val requestedChooserTitle =
                        call.argument<String>("chooserTitle")?.trim().orEmpty()
                    val chooserTitle = requestedChooserTitle.ifEmpty {
                        DEFAULT_CHOOSER_TITLE
                    }

                    if (text.isEmpty()) {
                        result.error(
                            "INVALID_SHARE_TEXT",
                            "Share text must not be empty.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            if (subject.isNotEmpty()) {
                                putExtra(Intent.EXTRA_SUBJECT, subject)
                            }
                        }

                        startActivity(Intent.createChooser(shareIntent, chooserTitle))
                        result.success(null)
                    } catch (error: ActivityNotFoundException) {
                        result.error(
                            "SHARE_UNAVAILABLE",
                            "No Android application is available to receive the share action.",
                            null,
                        )
                    } catch (error: Exception) {
                        result.error(
                            "SHARE_FAILED",
                            error.message ?: "Unable to open the Android share sheet.",
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
