package com.siyainfotech.mobile_app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.siyainfotech.mobile_app/share_intent"
    private val sharedFilesList: MutableList<Map<String, Any?>> = mutableListOf()
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedFiles" -> {
                    val copy = ArrayList(sharedFilesList)
                    sharedFilesList.clear()
                    result.success(copy)
                }
                "clearSharedFiles" -> {
                    sharedFilesList.clear()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        val type = intent.type

        val files = mutableListOf<Map<String, Any?>>()

        if (Intent.ACTION_SEND == action) {
            @Suppress("DEPRECATION")
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            if (uri != null) {
                val fileData = processUri(uri, type, text, subject)
                if (fileData != null) {
                    files.add(fileData)
                }
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            @Suppress("DEPRECATION")
            val uriList = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            if (uriList != null) {
                for (uri in uriList) {
                    val fileData = processUri(uri, type, text, subject)
                    if (fileData != null) {
                        files.add(fileData)
                    }
                }
            }
        }

        if (files.isNotEmpty()) {
            sharedFilesList.addAll(files)
            // If Flutter engine is already running, push to Flutter immediately
            methodChannel?.invokeMethod("onFilesShared", files)
        }
    }

    private fun processUri(
        uri: Uri,
        mimeType: String?,
        extraText: String?,
        extraSubject: String?
    ): Map<String, Any?>? {
        return try {
            val contentResolver = applicationContext.contentResolver
            var fileName = "shared_doc_${System.currentTimeMillis()}"
            var fileSize = 0L

            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1) {
                            val name = cursor.getString(nameIndex)
                            if (!name.isNullOrBlank()) {
                                fileName = name
                            }
                        }
                        val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (sizeIndex != -1) {
                            fileSize = cursor.getLong(sizeIndex)
                        }
                    }
                }
            } catch (e: Exception) {
                uri.lastPathSegment?.let { seg ->
                    if (seg.isNotBlank()) fileName = seg
                }
            }

            // Ensure proper extension if missing
            val cleanMime = mimeType ?: contentResolver.getType(uri) ?: "application/octet-stream"
            if (!fileName.contains(".")) {
                when {
                    cleanMime.contains("pdf") -> fileName += ".pdf"
                    cleanMime.contains("jpeg") || cleanMime.contains("jpg") -> fileName += ".jpg"
                    cleanMime.contains("png") -> fileName += ".png"
                    cleanMime.contains("webp") -> fileName += ".webp"
                }
            }

            // Persistent local directory inside app's private filesDir (survives force close, offline, reboot)
            val docsDir = File(applicationContext.filesDir, "whatsapp_shared_docs")
            if (!docsDir.exists()) {
                docsDir.mkdirs()
            }

            // Sanitize file name for filesystem safety
            val safeName = fileName.replace("[^a-zA-Z0-9._-]".toRegex(), "_")
            val destFile = File(docsDir, "${System.currentTimeMillis()}_$safeName")

            var digest: MessageDigest? = null
            try {
                digest = MessageDigest.getInstance("SHA-256")
            } catch (_: Exception) {}

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        digest?.update(buffer, 0, bytesRead)
                    }
                    output.flush()
                }
            }

            val hashHex = digest?.digest()?.joinToString("") { "%02x".format(it) } ?: ""
            if (fileSize <= 0L) {
                fileSize = destFile.length()
            }

            val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).format(Date())

            mapOf(
                "filePath" to destFile.absolutePath,
                "fileName" to fileName,
                "mimeType" to cleanMime,
                "fileSize" to fileSize,
                "fileHash" to hashHex,
                "source" to "WhatsApp Share",
                "receivedAt" to nowIso,
                "extraText" to extraText,
                "extraSubject" to extraSubject
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
