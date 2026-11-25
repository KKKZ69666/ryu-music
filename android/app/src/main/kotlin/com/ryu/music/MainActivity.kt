package com.ryu.music

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.charset.Charset
import java.nio.charset.CodingErrorAction
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val CHANNEL = "com.ryu.music/media_store"
        private const val REQUEST_PICK_LRC = 4091
    }

    private val ioExecutor: ExecutorService = Executors.newFixedThreadPool(4)
    private var pendingLrcResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSdkInt" -> result.success(Build.VERSION.SDK_INT)

                    "scanAudio" -> {
                        ioExecutor.execute {
                            try {
                                val songs = queryLocalAudio()
                                runOnUiThread { result.success(songs) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("SCAN_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    "getArtwork" -> {
                        val songId = (call.argument<Number>("songId"))?.toLong() ?: -1L
                        val albumId = (call.argument<Number>("albumId"))?.toLong() ?: -1L
                        ioExecutor.execute {
                            try {
                                val bytes = loadArtworkBytes(songId, albumId)
                                runOnUiThread { result.success(bytes) }
                            } catch (_: Exception) {
                                runOnUiThread { result.success(null) }
                            }
                        }
                    }

                    "getLocalLyrics" -> {
                        val filePath = call.argument<String>("filePath")
                        ioExecutor.execute {
                            try {
                                val lyrics = findLocalLyrics(filePath)
                                runOnUiThread { result.success(lyrics) }
                            } catch (_: Exception) {
                                runOnUiThread { result.success(null) }
                            }
                        }
                    }

                    "pickLrcFile" -> {
                        if (pendingLrcResult != null) {
                            result.error("BUSY", "File picker already open", null)
                            return@setMethodCallHandler
                        }
                        pendingLrcResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf("text/plain", "application/octet-stream", "application/lrc")
                            )
                        }
                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, REQUEST_PICK_LRC)
                        } catch (e: ActivityNotFoundException) {
                            pendingLrcResult = null
                            result.error("NO_PICKER", "No system document picker available", e.message)
                        } catch (e: Exception) {
                            pendingLrcResult = null
                            result.error("PICK_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_LRC) {
            val callback = pendingLrcResult
            pendingLrcResult = null
            if (callback == null) return

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                ioExecutor.execute {
                    try {
                        val rawBytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        val decoded = rawBytes?.let { decodeTextWithBom(it) }
                        runOnUiThread { callback.success(decoded) }
                    } catch (e: Exception) {
                        runOnUiThread { callback.error("READ_ERROR", e.message, null) }
                    }
                }
            } else {
                callback.success(null)
            }
        }
    }

    override fun onDestroy() {
        ioExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun queryLocalAudio(): List<Map<String, Any?>> {
        val resultList = ArrayList<Map<String, Any?>>()
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.TRACK
        )

        val selection =
            "(${MediaStore.Audio.Media.IS_MUSIC} != 0 OR ${MediaStore.Audio.Media.MIME_TYPE} LIKE 'audio/%') " +
                "AND (${MediaStore.Audio.Media.DURATION} IS NULL OR ${MediaStore.Audio.Media.DURATION} > 1000)"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        contentResolver.query(collection, projection, selection, null, sortOrder)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
            val durationCol = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
            val dateAddedCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val trackCol = cursor.getColumnIndex(MediaStore.Audio.Media.TRACK)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val filePath = if (dataCol >= 0 && !cursor.isNull(dataCol)) {
                    cursor.getString(dataCol)
                } else {
                    null
                }

                // Skip Android system ringtones/alarms/notifications folders
                if (filePath != null && (
                        filePath.contains("/Ringtones/", ignoreCase = true) ||
                            filePath.contains("/Notifications/", ignoreCase = true) ||
                            filePath.contains("/Alarms/", ignoreCase = true)
                        )
                ) {
                    continue
                }

                val contentUri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    id
                ).toString()

                val rawTitle = if (titleCol >= 0 && !cursor.isNull(titleCol)) {
                    cursor.getString(titleCol)?.trim()
                } else {
                    null
                }
                val rawArtist = if (artistCol >= 0 && !cursor.isNull(artistCol)) {
                    cursor.getString(artistCol)?.trim()
                } else {
                    null
                }
                val rawAlbum = if (albumCol >= 0 && !cursor.isNull(albumCol)) {
                    cursor.getString(albumCol)?.trim()
                } else {
                    null
                }
                val albumId = if (albumIdCol >= 0 && !cursor.isNull(albumIdCol)) {
                    cursor.getLong(albumIdCol)
                } else {
                    -1L
                }
                val durationMs = if (durationCol >= 0 && !cursor.isNull(durationCol)) {
                    cursor.getLong(durationCol)
                } else {
                    0L
                }
                val dateAdded = if (dateAddedCol >= 0 && !cursor.isNull(dateAddedCol)) {
                    cursor.getLong(dateAddedCol)
                } else {
                    0L
                }
                val track = if (trackCol >= 0 && !cursor.isNull(trackCol)) {
                    cursor.getInt(trackCol)
                } else {
                    0
                }

                val fallbackTitle = filePath
                    ?.substringAfterLast('/')
                    ?.substringBeforeLast('.')
                    ?: "Unknown Title"

                val title = if (rawTitle.isNullOrEmpty()) fallbackTitle else rawTitle
                val artist = if (rawArtist.isNullOrEmpty() || rawArtist == "<unknown>") {
                    "Unknown Artist"
                } else {
                    rawArtist
                }
                val album = if (rawAlbum.isNullOrEmpty() || rawAlbum == "<unknown>") {
                    "Unknown Album"
                } else {
                    rawAlbum
                }

                val item = HashMap<String, Any?>()
                item["id"] = id
                item["title"] = title
                item["artist"] = artist
                item["album"] = album
                item["albumId"] = albumId
                item["durationMs"] = durationMs
                item["uri"] = contentUri
                item["filePath"] = filePath
                item["dateAdded"] = dateAdded
                item["trackNumber"] = track
                resultList.add(item)
            }
        }
        return resultList
    }

    private fun loadArtworkBytes(songId: Long, albumId: Long): ByteArray? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && songId > 0) {
            var bitmap: Bitmap? = null
            try {
                val songUri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    songId
                )
                bitmap = contentResolver.loadThumbnail(songUri, Size(512, 512), null)
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
                return out.toByteArray()
            } catch (_: Exception) {
                // Fallback below
            } finally {
                if (bitmap != null && !bitmap.isRecycled) {
                    bitmap.recycle()
                }
            }
        }

        if (songId > 0) {
            val retriever = MediaMetadataRetriever()
            try {
                val songUri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    songId
                )
                retriever.setDataSource(this, songUri)
                val embedded = retriever.embeddedPicture
                if (embedded != null && embedded.isNotEmpty()) {
                    return embedded
                }
            } catch (_: Exception) {
                // Fallback below
            } finally {
                try {
                    retriever.release()
                } catch (_: Exception) {
                }
            }
        }

        if (albumId > 0) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                var albumBitmap: Bitmap? = null
                try {
                    val albumUri = ContentUris.withAppendedId(
                        MediaStore.Audio.Albums.EXTERNAL_CONTENT_URI,
                        albumId
                    )
                    albumBitmap = contentResolver.loadThumbnail(albumUri, Size(512, 512), null)
                    val out = ByteArrayOutputStream()
                    albumBitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
                    return out.toByteArray()
                } catch (_: Exception) {
                } finally {
                    if (albumBitmap != null && !albumBitmap.isRecycled) {
                        albumBitmap.recycle()
                    }
                }
            } else {
                try {
                    val albumArtUri = ContentUris.withAppendedId(
                        Uri.parse("content://media/external/audio/albumart"),
                        albumId
                    )
                    contentResolver.openInputStream(albumArtUri)?.use { input ->
                        return input.readBytes()
                    }
                } catch (_: Exception) {
                }
            }
        }
        return null
    }

    private fun findLocalLyrics(filePath: String?): String? {
        if (filePath.isNullOrBlank()) return null
        val audioFile = File(filePath)
        val basePath = filePath.substringBeforeLast('.')

        for (ext in listOf("lrc", "LRC", "txt", "TXT")) {
            val sidecar = File("$basePath.$ext")
            if (sidecar.exists() && sidecar.canRead()) {
                return decodeTextWithBom(sidecar.readBytes())
            }
        }

        if (!audioFile.exists()) return null
        return extractId3Uslt(audioFile)
    }

    private fun decodeTextWithBom(bytes: ByteArray): String {
        if (bytes.isEmpty()) return ""
        return when {
            bytes.size >= 2 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xFE.toByte() ->
                String(bytes, 2, bytes.size - 2, Charsets.UTF_16LE)
            bytes.size >= 2 && bytes[0] == 0xFE.toByte() && bytes[1] == 0xFF.toByte() ->
                String(bytes, 2, bytes.size - 2, Charsets.UTF_16BE)
            bytes.size >= 3 &&
                bytes[0] == 0xEF.toByte() &&
                bytes[1] == 0xBB.toByte() &&
                bytes[2] == 0xBF.toByte() ->
                String(bytes, 3, bytes.size - 3, Charsets.UTF_8)
            else -> String(bytes, Charsets.UTF_8)
        }.trim('\u0000', '\uFEFF', '\uFFFE')
    }

    private fun extractId3Uslt(file: File): String? {
        if (!file.exists() || !file.canRead() || file.length() < 128) return null
        try {
            RandomAccessFile(file, "r").use { raf ->
                val header = ByteArray(10)
                if (raf.read(header) != 10) return null
                if (header[0] != 'I'.code.toByte() ||
                    header[1] != 'D'.code.toByte() ||
                    header[2] != '3'.code.toByte()
                ) {
                    return null
                }

                val majorVersion = header[3].toInt() and 0xFF
                val tagSize = ((header[6].toInt() and 0x7F) shl 21) or
                    ((header[7].toInt() and 0x7F) shl 14) or
                    ((header[8].toInt() and 0x7F) shl 7) or
                    (header[9].toInt() and 0x7F)

                val limit = minOf(tagSize.toLong() + 10L, raf.length(), 4L * 1024L * 1024L)
                while (raf.filePointer + 10 < limit) {
                    val frameHeader = ByteArray(10)
                    if (raf.read(frameHeader) != 10) break
                    val frameId = String(frameHeader, 0, 4, Charsets.ISO_8859_1)
                    if (frameId.isBlank() || frameId[0] == '\u0000') break

                    val frameSize = if (majorVersion == 4) {
                        ((frameHeader[4].toInt() and 0x7F) shl 21) or
                            ((frameHeader[5].toInt() and 0x7F) shl 14) or
                            ((frameHeader[6].toInt() and 0x7F) shl 7) or
                            (frameHeader[7].toInt() and 0x7F)
                    } else {
                        ((frameHeader[4].toInt() and 0xFF) shl 24) or
                            ((frameHeader[5].toInt() and 0xFF) shl 16) or
                            ((frameHeader[6].toInt() and 0xFF) shl 8) or
                            (frameHeader[7].toInt() and 0xFF)
                    }

                    if (frameSize <= 0 || raf.filePointer + frameSize > limit) break

                    if (frameId == "USLT") {
                        val data = ByteArray(frameSize)
                        raf.readFully(data)
                        if (data.size <= 4) return null
                        val encoding = data[0].toInt() and 0xFF
                        val isDoubleByte = (encoding == 1 || encoding == 2)
                        var lyricsStart = 4
                        if (isDoubleByte) {
                            while (lyricsStart + 1 < data.size) {
                                if (data[lyricsStart] == 0.toByte() && data[lyricsStart + 1] == 0.toByte()) {
                                    lyricsStart += 2
                                    break
                                }
                                lyricsStart += 2
                            }
                        } else {
                            while (lyricsStart < data.size) {
                                if (data[lyricsStart] == 0.toByte()) {
                                    lyricsStart += 1
                                    break
                                }
                                lyricsStart += 1
                            }
                        }

                        if (lyricsStart >= data.size) return null
                        val lyricsBytes = data.copyOfRange(lyricsStart, data.size)
                        val raw = decodeId3String(lyricsBytes, encoding)
                        val cleaned = raw.trim('\u0000', '\uFEFF', '\uFFFE', ' ', '\n', '\r')
                        if (cleaned.isNotEmpty()) return cleaned
                    } else {
                        raf.seek(raf.filePointer + frameSize)
                    }
                }
            }
        } catch (_: Exception) {
        }
        return null
    }

    private fun decodeId3String(bytes: ByteArray, encoding: Int): String {
        return when (encoding) {
            1 -> String(bytes, Charsets.UTF_16)
            2 -> String(bytes, Charsets.UTF_16BE)
            3 -> String(bytes, Charsets.UTF_8)
            else -> {
                try {
                    val decoder = Charsets.UTF_8.newDecoder()
                        .onMalformedInput(CodingErrorAction.REPORT)
                        .onUnmappableCharacter(CodingErrorAction.REPORT)
                    decoder.decode(ByteBuffer.wrap(bytes)).toString()
                } catch (_: Exception) {
                    String(bytes, Charsets.ISO_8859_1)
                }
            }
        }
    }
}
