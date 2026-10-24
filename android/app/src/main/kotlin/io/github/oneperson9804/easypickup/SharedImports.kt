package io.github.oneperson9804.easypickup

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.AtomicFile
import android.webkit.MimeTypeMap
import org.json.JSONObject
import java.io.File
import java.util.UUID

/** Durable share drafts. Reading a draft never removes it; Dart acknowledges only after saving. */
object SharedImports {
    private fun directory(context: Context) = File(context.filesDir, "incoming-shares").apply { mkdirs() }

    fun stage(context: Context, intent: Intent) {
        val directory = directory(context)
        val id = "${System.currentTimeMillis()}-${UUID.randomUUID()}"
        val manifest = JSONObject()
        var image: File? = null
        try {
            if (intent.type?.startsWith("image/") == true) {
                val uri = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    else @Suppress("DEPRECATION") intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                requireNotNull(uri) { "分享中没有图片" }
                val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(context.contentResolver.getType(uri)) ?: "jpg"
                image = File(directory, "$id.$extension")
                context.contentResolver.openInputStream(uri)?.use { input -> image.outputStream().use { input.copyTo(it) } }
                    ?: throw IllegalStateException("无法读取分享图片")
                manifest.put("imageFile", image.name)
            } else {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()
                if (text.isNullOrEmpty()) return
                manifest.put("text", text)
            }
            val atomic = AtomicFile(File(directory, "$id.json"))
            val output = atomic.startWrite()
            try {
                output.write(manifest.toString().toByteArray(Charsets.UTF_8))
                atomic.finishWrite(output)
            } catch (error: Exception) {
                atomic.failWrite(output)
                throw error
            }
        } catch (error: Exception) {
            image?.delete()
            throw error
        }
    }

    fun peek(context: Context): Map<String, String>? {
        val directory = directory(context)
        val manifest = directory.listFiles()?.filter { it.extension == "json" }?.minByOrNull { it.name } ?: return null
        val input = JSONObject(manifest.readText(Charsets.UTF_8))
        val output = mutableMapOf("draftId" to manifest.nameWithoutExtension)
        input.optString("text").takeIf { it.isNotBlank() }?.let { output["text"] = it }
        input.optString("imageFile").takeIf { it.isNotBlank() }?.let { filename ->
            require(filename == File(filename).name && !filename.contains("..")) { "无效的图片路径" }
            val image = File(directory, filename)
            check(image.isFile) { "分享图片已不可用，请重新分享" }
            output["imagePath"] = image.absolutePath
        }
        check(output.size > 1) { "分享内容为空" }
        return output
    }

    fun acknowledge(context: Context, id: String) {
        require(Regex("[A-Za-z0-9-]{1,100}").matches(id)) { "无效的草稿标识" }
        val directory = directory(context)
        val manifest = File(directory, "$id.json")
        val acknowledged = File(directory, "$id.ack")
        if (manifest.isFile) check(manifest.renameTo(acknowledged)) { "无法确认分享草稿" }
        if (!acknowledged.isFile) return
        val input = JSONObject(acknowledged.readText(Charsets.UTF_8))
        input.optString("imageFile").takeIf { it.isNotBlank() }?.let { filename ->
            require(filename == File(filename).name && !filename.contains("..")) { "无效的图片路径" }
            val image = File(directory, filename)
            if (image.exists()) check(image.delete()) { "无法清理分享图片" }
        }
        check(acknowledged.delete()) { "无法清理分享草稿" }
    }
}
