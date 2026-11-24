package com.ryu.music

import android.app.Activity
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
import java.nio.charset.Charset

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val CHANNEL = "com.ryu.music/media_store"
        private const val REQUEST_PICK_LRC = 4091
    }

    private var pendingLrcResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanAudio" -> {
                        Thread {
                            try {
                                val songs = queryLocalAudio()
                                runOnUiThread { result.success(songs) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("SCAN_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }

                    "getArtwork" -> {
                        val songId = (call.argument<Number>("songId"))?.toLong() ?: -1L
                        val albumId = (call.argument<Number>("albumId"))?.toLong() ?: -1L
                        Thread {
                            try {
                                val bytes = loadArtworkBytes(songId, albumId)
                                runOnUiThread { result.success(bytes) }
                            } catch (_: Exception) {
                                runOnUiThread { result.success(null) }
                            }
                        }.start()
                    }

                    "getLocalLyrics" -> {
                        val filePath = call.argument<String>("filePath")
                        Thread {
                            try {
                                val lyrics = findLocalLyrics(filePath)
                                runOnUiThread { result.success(lyrics) }
                            } catch (_: Exception) {
                                runOnUiThread { result.success(null) }
                            }
                        }.start()
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
                        startActivityForResult(intent, REQUEST_PICK_LRC)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_LRC) {
            val callback = pendingLrcResult
            pendingLrcResult = null
            if (callback == null) return

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val uri = data.data!!
                    val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use {
                        it.readText()
                    }
                    callback.success(text)
                } catch (e: Exception) {
                    callback.error("READ_ERROR", e.message, null)
                }
            } else {
                callback.success(null)
            }
        }
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

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} > 1000"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        contentResolver.query(collection, projection, selection, null, sortOrder)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
            val dateAddedCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val trackCol = cursor.getColumnIndex(MediaStore.Audio.Media.TRACK)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val contentUri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    id
                ).toString()

                val rawTitle = cursor.getString(titleCol)?.trim()
                val rawArtist = cursor.getString(artistCol)?.trim()
                val rawAlbum = cursor.getString(albumCol)?.trim()
                val filePath = if (dataCol >= 0) cursor.getString(dataCol) else null
                val dateAdded = if (dateAddedCol >= 0) cursor.getLong(dateAddedCol) else 0L
                val track = if (trackCol >= 0) cursor.getInt(trackCol) else 0

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
                item["albumId"] = cursor.getLong(albumIdCol)
                item["durationMs"] = cursor.getLong(durationCol)
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
            try {
                val songUri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                    songId
                )
                val bitmap = contentResolver.loadThumbnail(songUri, Size(512, 512), null)
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
                bitmap.recycle()
                return out.toByteArray()
            } catch (_: Exception) {
                // Fallback below
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
        return null
    }

    private fun findLocalLyrics(filePath: String?): String? {
        if (filePath.isNullOrBlank()) return null
        val audioFile = File(filePath)
        if (!audioFile.exists()) return null

        val basePath = filePath.substringBeforeLast('.')
        val lrcFile = File("$basePath.lrc")
        if (lrcFile.exists() && lrcFile.canRead()) {
            return lrcFile.readText(Charsets.UTF_8)
        }
        val txtFile = File("$basePath.txt")
        if (txtFile.exists() && txtFile.canRead()) {
            return txtFile.readText(Charsets.UTF_8)
        }

        return extractId3Uslt(audioFile)
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

                val limit = minOf(tagSize.toLong() + 10L, raf.length(), 2L * 1024L * 1024L)
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
                        val charset: Charset = when (encoding) {
                            1 -> Charsets.UTF_16
                            2 -> Charsets.UTF_16BE
                            3 -> Charsets.UTF_8
                            else -> Charsets.ISO_8859_1
                        }
                        val payload = data.copyOfRange(4, data.size)
                        val raw = String(payload, charset)
                        val sepIdx = raw.indexOf('\u0000')
                        val lyricsText = if (sepIdx >= 0 && sepIdx + 1 < raw.length) {
                            raw.substring(sepIdx + 1)
                        } else {
                            raw
                        }
                        val cleaned = lyricsText.trim('\u0000', '\uFEFF', ' ', '\n', '\r')
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
}
