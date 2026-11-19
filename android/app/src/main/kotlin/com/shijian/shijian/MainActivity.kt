package com.shijian.shijian

import android.app.PendingIntent
import android.app.WallpaperManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * 平台出口。Flutter 侧只认一个 MethodChannel：shijian/native。
 *
 * saveImage   存到系统相册（Pictures/拾间）
 * shareImage  以 content:// 分享（不能传 file:// 路径，Android 7 起会崩）
 * setWallpaper 设为壁纸
 * canInstall / installSettings / installApk  应用内更新
 *
 * 所有方法都在主线程回调；耗时活（解码、拷贝）在后台线程做，再切回主线程回结果。
 */
class MainActivity : FlutterActivity() {

    private val channelName = "shijian/native"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                val path = args["path"] as? String
                val mime = args["mime"] as? String
                val title = args["title"] as? String
                try {
                    when (call.method) {
                        "saveImage" -> {
                            if (path == null) {
                                result.success(false)
                            } else {
                                runAsync(result) { saveImage(path, mime) }
                            }
                        }
                        "shareImage" -> {
                            if (path == null) {
                                result.success(false)
                            } else {
                                shareImage(path, mime, title)
                                result.success(true)
                            }
                        }
                        "setWallpaper" -> {
                            if (path == null) {
                                result.success(false)
                            } else {
                                runAsync(result) { setWallpaper(path) }
                            }
                        }
                        "canInstall" -> result.success(canInstall())
                        "installSettings" -> {
                            openInstallSettings()
                            result.success(true)
                        }
                        "installApk" -> {
                            if (path == null) {
                                result.success(false)
                            } else {
                                runAsync(result) { installApk(path) }
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("platform_error", e.message, null)
                }
            }
    }

    /** 后台线程干活，主线程回结果。MethodChannel 的 result 必须在主线程调。 */
    private fun <T> runAsync(result: MethodChannel.Result, block: () -> T) {
        Thread {
            val value = try {
                block()
            } catch (e: Exception) {
                runOnUiThread { result.error("platform_error", e.message, null) }
                return@Thread
            }
            runOnUiThread { result.success(value) }
        }.start()
    }

    private fun guessMime(path: String): String = when (path.substringAfterLast('.', "").lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "webp" -> "image/webp"
        "gif" -> "image/gif"
        "heic", "heif" -> "image/heic"
        "zip" -> "application/zip"
        "txt" -> "text/plain"
        "epub" -> "application/epub+zip"
        else -> "application/octet-stream"
    }

    // ---------- 存相册 ----------

    private fun saveImage(path: String, mime: String?): Boolean {
        val src = File(path)
        if (!src.exists() || src.length() == 0L) return false
        val type = mime ?: guessMime(path)
        val name = src.name

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, type)
                put(MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/拾间")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val uri: Uri = contentResolver.insert(collection, values) ?: return false
            contentResolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { input -> input.copyTo(out) }
            } ?: return false
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return true
        }

        @Suppress("DEPRECATION")
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            "拾间"
        )
        if (!dir.exists() && !dir.mkdirs()) return false
        val dst = uniqueFile(dir, name)
        src.copyTo(dst, overwrite = false)
        MediaScannerConnection.scanFile(this, arrayOf(dst.absolutePath), arrayOf(type), null)
        return true
    }

    private fun uniqueFile(dir: File, name: String): File {
        var f = File(dir, name)
        if (!f.exists()) return f
        val base = name.substringBeforeLast('.')
        val ext = name.substringAfterLast('.', "")
        var i = 1
        while (f.exists()) {
            val n = if (ext.isEmpty()) "$base ($i)" else "$base ($i).$ext"
            f = File(dir, n)
            i++
        }
        return f
    }

    // ---------- 分享 ----------

    private fun shareImage(path: String, mime: String?, title: String?) {
        val f = File(path)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", f)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime ?: guessMime(path)
            putExtra(Intent.EXTRA_STREAM, uri)
            if (!title.isNullOrEmpty()) putExtra(Intent.EXTRA_TITLE, title)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, "分享到"))
    }

    // ---------- 壁纸 ----------

    private fun setWallpaper(path: String): Boolean {
        val opts = BitmapFactory.Options().apply { inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888 }
        val bmp = BitmapFactory.decodeFile(path, opts) ?: return false
        return try {
            WallpaperManager.getInstance(this).setBitmap(bmp)
            true
        } catch (e: Exception) {
            false
        } finally {
            bmp.recycle()
        }
    }

    // ---------- 应用内更新 ----------

    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val i = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                .setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
        }
    }

    private fun installApk(path: String): Boolean {
        val f = File(path)
        if (!f.exists()) return false
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL
        )
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            FileInputStream(f).use { input ->
                session.openWrite("shijian.apk", 0, f.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val intent = Intent(this, InstallReceiver::class.java)
                .setAction(InstallReceiver.ACTION_INSTALL_RESULT)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pending = PendingIntent.getBroadcast(this, sessionId, intent, flags)
            session.commit(pending.intentSender)
        }
        return true
    }
}

/** PackageInstaller 的结果回调。安装界面自己会弹，这里只负责收尾不崩。 */
class InstallReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_INSTALL_RESULT = "com.shijian.shijian.INSTALL_RESULT"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -1)
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            @Suppress("DEPRECATION")
            val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            confirm?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            confirm?.let { context.startActivity(it) }
        }
    }
}
