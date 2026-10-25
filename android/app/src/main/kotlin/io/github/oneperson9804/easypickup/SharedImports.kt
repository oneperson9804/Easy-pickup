package io.github.oneperson9804.easypickup

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.util.AtomicFile
import android.webkit.MimeTypeMap
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.util.UUID

/** Durable share drafts. Reading a draft never removes it; Dart acknowledges only after saving. */
object SharedImports {
    private fun directory(context: Context) = File(context.filesDir, "incoming-shares").apply { mkdirs() }

    fun stage(context: Context, intent: Intent) {
        val directory = directory(context)
        val id = "${System.currentTimeMillis()}-${UUID.randomUUID()}"
        val manifest = JSONObject()
        val images = mutableListOf<File>()
        try {
            if (intent.type?.startsWith("image/") == true) {
                val uris = if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
                    if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    else @Suppress("DEPRECATION") intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                } else {
                    val uri = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                        else @Suppress("DEPRECATION") intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    uri?.let { arrayListOf(it) }
                }
                val streams = uris?.takeIf { it.isNotEmpty() }
                    ?: intent.clipData?.let { clip -> (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri } }
                    ?: emptyList()
                require(streams.isNotEmpty()) { "分享中没有图片" }
                for ((index, uri) in streams.withIndex()) {
                    require(uri.scheme == "content") { "请使用系统分享选择图片" }
                    val mime = context.contentResolver.getType(uri) ?: intent.type.orEmpty()
                    require(mime.startsWith("image/")) { "请选择图片格式的文件" }
                    val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "jpg"
                    val image = File(directory, "$id-$index.$extension")
                    images.add(image)
                    context.contentResolver.openInputStream(uri)?.use { input -> image.outputStream().use { input.copyTo(it) } }
                        ?: throw IllegalStateException("无法读取分享图片")
                }
                if (images.size == 1) manifest.put("imageFile", images.single().name)
                else manifest.put("imageFiles", JSONArray(images.map { it.name }))
                intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                    ?.let { manifest.put("text", it) }
            } else {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()
                if (text.isNullOrEmpty()) return
                manifest.put("text", text)
            }
            writeManifest(directory, id, manifest)
        } catch (error: Exception) {
            images.forEach { it.delete() }
            throw error
        }
    }

    fun stageText(context: Context, text: String) {
        require(text.isNotBlank()) { "页面中没有文字" }
        writeManifest(directory(context), "${System.currentTimeMillis()}-${UUID.randomUUID()}", JSONObject().put("text", text))
    }

    fun stageBitmap(context: Context, bitmap: Bitmap) {
        val directory = directory(context)
        val id = "${System.currentTimeMillis()}-${UUID.randomUUID()}"
        val image = File(directory, "$id.png")
        try {
            image.outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) { "无法保存截图" } }
            writeManifest(directory, id, JSONObject().put("imageFile", image.name))
        } catch (error: Exception) { image.delete(); throw error }
    }

    private fun writeManifest(directory: File, id: String, manifest: JSONObject) {
        val atomic = AtomicFile(File(directory, "$id.json"))
        val output = atomic.startWrite()
        try {
            output.write(manifest.toString().toByteArray(Charsets.UTF_8))
            atomic.finishWrite(output)
        } catch (error: Exception) { atomic.failWrite(output); throw error }
    }

    private fun images(input: JSONObject): List<String> {
        val files = input.optJSONArray("imageFiles")?.let { values -> (0 until values.length()).map { values.getString(it) } }.orEmpty()
        val single = input.optString("imageFile").takeIf { it.isNotBlank() }
        return (files + listOfNotNull(single)).distinct()
    }

    fun peek(context: Context): Map<String, Any>? {
        val directory = directory(context)
        val manifest = directory.listFiles()?.filter { it.extension == "json" }?.minByOrNull { it.name } ?: return null
        val input = JSONObject(manifest.readText(Charsets.UTF_8))
        val output = mutableMapOf<String, Any>("draftId" to manifest.nameWithoutExtension)
        input.optString("text").takeIf { it.isNotBlank() }?.let { output["text"] = it }
        val imagePaths = images(input).map { filename ->
            require(filename == File(filename).name && !filename.contains("..")) { "无效的图片路径" }
            val image = File(directory, filename)
            check(image.isFile) { "分享图片已不可用，请重新分享" }
            image.absolutePath
        }
        if (imagePaths.size == 1) output["imagePath"] = imagePaths.single()
        else if (imagePaths.isNotEmpty()) output["imagePaths"] = imagePaths
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
        images(input).forEach { filename ->
            require(filename == File(filename).name && !filename.contains("..")) { "无效的图片路径" }
            val image = File(directory, filename)
            if (image.exists()) check(image.delete()) { "无法清理分享图片" }
        }
        check(acknowledged.delete()) { "无法清理分享草稿" }
    }
}
