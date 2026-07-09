package com.aibuddy.app

import android.content.Intent
import android.content.pm.ResolveInfo
import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.MediaRecorder
import android.os.Bundle
import android.provider.ContactsContract
import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val appLauncherChannel = "ai_buddy/app_launcher"
    private val contactsChannel = "com.ai-buddy.app/contacts"
    private val appsChannel = "com.aibuddy.app/apps"
    private lateinit var appManagerModule: AppManagerModule
    private val volumeChannel = "com.aibuddy.app/volume"
    private val wifiChannel = "com.aibuddy.app/wifi"
    private val bluetoothChannel = "com.aibuddy.app/bluetooth"
    private val voiceRecorderChannel = "com.aibuddy.app/voice_recorder"
    private val offlineSttChannel = "com.aibuddy.app/offline_stt"
    private val settingsChannel = "com.aibuddy.app/settings"
    private val filesChannel = "com.aibuddy.app/files"
    private val accessibilityChannel = "com.aibuddy.app/accessibility"
    private val mediaChannel = "com.aibuddy.app/media"
    private var mediaRecorder: MediaRecorder? = null
    private var speechRecognizer: android.speech.SpeechRecognizer? = null
    private var sttResult: String? = null
    private var sttCompleter: CompletableDeferred<String?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appLauncherChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")?.trim().orEmpty()
                    result.success(launchPackage(packageName))
                }
                "launchAppByQuery" -> {
                    val query = call.argument<String>("query")?.trim().orEmpty()
                    result.success(launchAppByQuery(query))
                }
                "shareToApp" -> {
                    val packageName = call.argument<String>("packageName")?.trim().orEmpty()
                    val text = call.argument<String>("text")?.orEmpty() ?: ""
                    result.success(shareToApp(packageName, text))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, contactsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "searchContacts" -> {
                    val query = call.argument<String>("query")?.trim().orEmpty()
                    val limit = call.argument<Int>("limit") ?: 10
                    if (checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                        result.success(searchContacts(query, limit))
                    } else {
                        result.error("PERMISSION_DENIED", "Contacts permission not granted", null)
                    }
                }
                "addContact" -> {
                    if (checkSelfPermission(Manifest.permission.WRITE_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                        val name  = call.argument<String>("name")?.trim().orEmpty()
                        val phone = call.argument<String>("phone")?.trim().orEmpty()
                        val email = call.argument<String>("email")?.trim().orEmpty()
                        result.success(addContact(name, phone, email))
                    } else {
                        result.error("PERMISSION_DENIED", "WRITE_CONTACTS permission not granted", null)
                    }
                }
                "editContact" -> {
                    if (checkSelfPermission(Manifest.permission.WRITE_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                        val contactId = call.argument<String>("contactId")?.trim().orEmpty()
                        val phone     = call.argument<String>("phone")?.trim().orEmpty()
                        val email     = call.argument<String>("email")?.trim().orEmpty()
                        result.success(updateContact(contactId, phone, email))
                    } else {
                        result.error("PERMISSION_DENIED", "WRITE_CONTACTS permission not granted", null)
                    }
                }
                "deleteContact" -> {
                    if (checkSelfPermission(Manifest.permission.WRITE_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                        val contactId = call.argument<String>("contactId")?.trim().orEmpty()
                        result.success(deleteContact(contactId))
                    } else {
                        result.error("PERMISSION_DENIED", "WRITE_CONTACTS permission not granted", null)
                    }
                }
                "makePhoneCall" -> {
                    val number = call.argument<String>("number")?.trim().orEmpty()
                    if (number.isEmpty()) {
                        result.success(false)
                    } else if (checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                        result.success(makePhoneCall(number))
                    } else {
                        result.error("PERMISSION_DENIED", "CALL_PHONE permission not granted", null)
                    }
                }
                "openDialer" -> {
                    val number = call.argument<String>("number")?.trim().orEmpty()
                    result.success(openDialer(number))
                }
                else -> result.notImplemented()
            }
        }

        // Volume control channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, volumeChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "setVolume" -> {
                    val stream = call.argument<String>("stream") ?: "music"
                    val level = call.argument<Double>("level") ?: 0.5
                    result.success(setVolume(stream, level))
                }
                "getVolume" -> {
                    val stream = call.argument<String>("stream") ?: "music"
                    result.success(getVolume(stream))
                }
                "setMute" -> {
                    val mute = call.argument<Boolean>("mute") ?: false
                    result.success(setMute(mute))
                }
                else -> result.notImplemented()
            }
        }

        // WiFi control channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWifiState" -> {
                    result.success(getWifiState())
                }
                "setWifiEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(setWifiEnabled(enabled))
                }
                else -> result.notImplemented()
            }
        }

        // Bluetooth control channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bluetoothChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBluetoothState" -> {
                    result.success(getBluetoothState())
                }
                "setBluetoothEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(setBluetoothEnabled(enabled))
                }
                else -> result.notImplemented()
            }
        }

        // Voice recorder channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, voiceRecorderChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val outputPath = call.argument<String>("outputPath") ?: ""
                    result.success(startRecording(outputPath))
                }
                "stopRecording" -> {
                    result.success(stopRecording())
                }
                else -> result.notImplemented()
            }
        }

        // Offline STT channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, offlineSttChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isOfflineAvailable" -> {
                    result.success(isOfflineSttAvailable())
                }
                "startListening" -> {
                    val preferOffline = call.argument<Boolean>("preferOffline") ?: true
                    val locale = call.argument<String>("locale") ?: "de_DE"
                    // Der Recognizer kann onError UND onResults liefern —
                    // result darf aber nur genau einmal beantwortet werden.
                    var replied = false
                    startOfflineListening(preferOffline, locale) { text ->
                        if (!replied) {
                            replied = true
                            result.success(text)
                        }
                    }
                }
                "stopListening" -> {
                    stopOfflineListening()
                    result.success(true)
                }
                "downloadOfflineLanguage" -> {
                    openOfflineSpeechSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Device Settings channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBrightness" -> {
                    val level = call.argument<Double>("level") ?: 0.5
                    result.success(setBrightness(level))
                }
                "getBrightness" -> {
                    result.success(getBrightness())
                }
                "setScreenTimeout" -> {
                    val seconds = call.argument<Int>("seconds") ?: 30
                    result.success(setScreenTimeout(seconds))
                }
                "getScreenTimeout" -> {
                    result.success(getScreenTimeout())
                }
                "setDoNotDisturb" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(setDoNotDisturb(enabled))
                }
                "getDoNotDisturb" -> {
                    result.success(getDoNotDisturb())
                }
                "openSettings" -> {
                    val page = call.argument<String>("page") ?: ""
                    result.success(openSystemSettings(page))
                }
                else -> result.notImplemented()
            }
        }

        // App Manager module
        appManagerModule = AppManagerModule(this)
        appManagerModule.register(flutterEngine)

        // File open channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFileWithMime" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    result.success(openFileWithMime(filePath, mimeType))
                }
                "hasAllFilesAccess" -> {
                    result.success(hasAllFilesAccess())
                }
                "requestAllFilesAccess" -> {
                    result.success(requestAllFilesAccess())
                }
                else -> result.notImplemented()
            }
        }

        // Accessibility / cross-app automation channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, accessibilityChannel).setMethodCallHandler { call, result ->
            val service = BuddyAccessibilityService.instance
            when (call.method) {
                "isEnabled" -> result.success(service != null)
                "openSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("A11y", "openSettings error: $e")
                        result.success(false)
                    }
                }
                "readScreen" -> {
                    if (service == null) result.error("NOT_ENABLED", "Accessibility service not enabled", null)
                    else result.success(service.readScreen())
                }
                "currentPackage" -> {
                    if (service == null) result.error("NOT_ENABLED", "Accessibility service not enabled", null)
                    else result.success(service.currentPackage())
                }
                "tapText" -> {
                    val text = call.argument<String>("text")?.trim().orEmpty()
                    if (service == null) result.error("NOT_ENABLED", "Accessibility service not enabled", null)
                    else result.success(service.tapByText(text))
                }
                "tapAt" -> {
                    val x = call.argument<Int>("x") ?: 0
                    val y = call.argument<Int>("y") ?: 0
                    if (service == null) result.error("NOT_ENABLED", "Accessibility service not enabled", null)
                    else result.success(service.tapAt(x, y))
                }
                "inputText" -> {
                    val text = call.argument<String>("text").orEmpty()
                    if (service == null) result.error("NOT_ENABLED", "Accessibility service not enabled", null)
                    else result.success(service.inputText(text))
                }
                "scroll" -> {
                    val forward = call.argument<Boolean>("forward") ?: true
                    if (service == null) result.error("NOT_ENABLED", "Accessibility service not enabled", null)
                    else result.success(service.scroll(forward))
                }
                "globalAction" -> {
                    val action = call.argument<String>("action").orEmpty()
                    if (service == null) {
                        result.error("NOT_ENABLED", "Accessibility service not enabled", null)
                    } else {
                        val ok = when (action) {
                            "back" -> service.back()
                            "home" -> service.home()
                            "recents" -> service.recents()
                            "notifications" -> service.notifications()
                            else -> false
                        }
                        result.success(ok)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Media / photo search channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "searchPhotos" -> {
                    val query = call.argument<String>("query")?.trim().orEmpty()
                    val limit = call.argument<Int>("limit") ?: 30
                    val daysBack = call.argument<Int>("daysBack") ?: 0
                    if (checkSelfPermission(mediaImagesPermission()) == PackageManager.PERMISSION_GRANTED) {
                        result.success(searchPhotos(query, limit, daysBack))
                    } else {
                        result.error("PERMISSION_DENIED", "Media images permission not granted", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── All-Files Access (broad filesystem) ──

    private fun hasAllFilesAccess(): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            android.os.Environment.isExternalStorageManager()
        } else {
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestAllFilesAccess(): Boolean {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                val intent = Intent(
                    android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    android.net.Uri.parse("package:$packageName")
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e("Files", "requestAllFilesAccess error: $e")
            // Fall back to the general all-files-access list.
            try {
                val intent = Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                true
            } catch (e2: Exception) {
                Log.e("Files", "requestAllFilesAccess fallback error: $e2")
                false
            }
        }
    }

    // ── Photo Search (MediaStore) ──

    private fun mediaImagesPermission(): String {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    }

    private fun searchPhotos(query: String, limit: Int, daysBack: Int): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            android.provider.MediaStore.Images.Media._ID,
            android.provider.MediaStore.Images.Media.DISPLAY_NAME,
            android.provider.MediaStore.Images.Media.DATA,
            android.provider.MediaStore.Images.Media.DATE_TAKEN,
            android.provider.MediaStore.Images.Media.BUCKET_DISPLAY_NAME
        )
        val selectionParts = mutableListOf<String>()
        val args = mutableListOf<String>()
        if (query.isNotEmpty()) {
            selectionParts.add(
                "(${android.provider.MediaStore.Images.Media.DISPLAY_NAME} LIKE ? OR " +
                    "${android.provider.MediaStore.Images.Media.BUCKET_DISPLAY_NAME} LIKE ?)"
            )
            args.add("%$query%")
            args.add("%$query%")
        }
        if (daysBack > 0) {
            val since = System.currentTimeMillis() - daysBack.toLong() * 24L * 60L * 60L * 1000L
            selectionParts.add("${android.provider.MediaStore.Images.Media.DATE_TAKEN} >= ?")
            args.add(since.toString())
        }
        val selection = if (selectionParts.isEmpty()) null else selectionParts.joinToString(" AND ")
        val sortOrder = "${android.provider.MediaStore.Images.Media.DATE_TAKEN} DESC"

        try {
            contentResolver.query(
                android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                if (args.isEmpty()) null else args.toTypedArray(),
                sortOrder
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media._ID)
                val nameCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.DISPLAY_NAME)
                val dataCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.DATA)
                val dateCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.DATE_TAKEN)
                val bucketCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
                var count = 0
                while (cursor.moveToNext() && count < limit) {
                    val id = cursor.getLong(idCol)
                    val uri = android.content.ContentUris.withAppendedId(
                        android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id
                    )
                    results.add(
                        mapOf(
                            "name" to (cursor.getString(nameCol) ?: ""),
                            "path" to (cursor.getString(dataCol) ?: ""),
                            "uri" to uri.toString(),
                            "dateTaken" to cursor.getLong(dateCol),
                            "album" to (cursor.getString(bucketCol) ?: "")
                        )
                    )
                    count++
                }
            }
        } catch (e: Exception) {
            Log.e("PhotoSearch", "searchPhotos error: $e")
        }
        return results
    }

    private fun searchContacts(query: String, limit: Int): List<Map<String, Any>> {
        val results = mutableListOf<Map<String, Any>>()
        if (query.isEmpty()) return results

        val normalizedQuery = query.lowercase(Locale.ROOT)
        val uri = ContactsContract.Contacts.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.DISPLAY_NAME
        )

        contentResolver.query(uri, projection, null, null, "${ContactsContract.Contacts.DISPLAY_NAME} ASC")?.use { cursor ->
            var count = 0
            while (cursor.moveToNext() && count < limit) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                val name = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME)) ?: ""

                if (name.lowercase(Locale.ROOT).contains(normalizedQuery) || normalizedQuery.isEmpty()) {
                    val phones = getPhoneNumbers(id)
                    val emails = getEmails(id)
                    
                    // Also match against phone numbers
                    if (name.lowercase(Locale.ROOT).contains(normalizedQuery) || 
                        phones.any { it["number"].toString().replace(Regex("[\\s\\-()]"), "").contains(normalizedQuery.replace(Regex("[\\s\\-()]"), "")) }) {
                        results.add(mapOf(
                            "id" to id,
                            "name" to name,
                            "phones" to phones,
                            "emails" to emails
                        ))
                        count++
                    }
                }
            }
        }
        return results
    }

    private fun getPhoneNumbers(contactId: Long): List<Map<String, String>> {
        val phones = mutableListOf<Map<String, String>>()
        val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.TYPE,
            ContactsContract.CommonDataKinds.Phone.LABEL
        )
        val selection = "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?"
        val selectionArgs = arrayOf(contactId.toString())

        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val number = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)) ?: ""
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.TYPE))
                val label = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.LABEL)) ?: phoneNumberTypeLabel(type)
                phones.add(mapOf("number" to number, "label" to label))
            }
        }
        return phones
    }

    private fun getEmails(contactId: Long): List<Map<String, String>> {
        val emails = mutableListOf<Map<String, String>>()
        val uri = ContactsContract.CommonDataKinds.Email.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Email.DATA,
            ContactsContract.CommonDataKinds.Email.TYPE,
            ContactsContract.CommonDataKinds.Email.LABEL
        )
        val selection = "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?"
        val selectionArgs = arrayOf(contactId.toString())

        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val address = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.DATA)) ?: ""
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.TYPE))
                val label = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Email.LABEL)) ?: emailTypeLabel(type)
                emails.add(mapOf("address" to address, "label" to label))
            }
        }
        return emails
    }

    private fun phoneNumberTypeLabel(type: Int): String = when (type) {
        ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE -> "Mobil"
        ContactsContract.CommonDataKinds.Phone.TYPE_HOME -> "Privat"
        ContactsContract.CommonDataKinds.Phone.TYPE_WORK -> "Geschaeftlich"
        ContactsContract.CommonDataKinds.Phone.TYPE_OTHER -> "Sonstige"
        else -> "Telefon"
    }

    private fun emailTypeLabel(type: Int): String = when (type) {
        ContactsContract.CommonDataKinds.Email.TYPE_HOME -> "Privat"
        ContactsContract.CommonDataKinds.Email.TYPE_WORK -> "Geschaeftlich"
        ContactsContract.CommonDataKinds.Email.TYPE_MOBILE -> "Mobil"
        ContactsContract.CommonDataKinds.Email.TYPE_OTHER -> "Sonstige"
        else -> "E-Mail"
    }

    // ── Contact Management (add/edit/delete) ──

    private fun addContact(name: String, phone: String, email: String): Boolean {
        return try {
            val values = android.content.ContentValues().apply {
                put(android.provider.ContactsContract.RawContacts.ACCOUNT_TYPE, null as String?)
                put(android.provider.ContactsContract.RawContacts.ACCOUNT_NAME, null as String?)
            }
            // insert() liefert die URI des neuen RawContacts — bulkInsert()
            // würde nur die Anzahl der Zeilen zurückgeben, nicht die ID.
            val rawUri = contentResolver.insert(
                android.provider.ContactsContract.RawContacts.CONTENT_URI,
                values
            ) ?: return false
            val rawId = android.content.ContentUris.parseId(rawUri)
            if (rawId <= 0) return false

            val ops = arrayListOf(
                android.content.ContentProviderOperation.newInsert(
                    android.provider.ContactsContract.Data.CONTENT_URI
                ).withValue(android.provider.ContactsContract.Data.RAW_CONTACT_ID, rawId)
                    .withValue(android.provider.ContactsContract.Data.MIMETYPE,
                        android.provider.ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, name)
                    .build()
            )
            if (phone.isNotEmpty()) {
                ops.add(android.content.ContentProviderOperation.newInsert(
                    android.provider.ContactsContract.Data.CONTENT_URI
                ).withValue(android.provider.ContactsContract.Data.RAW_CONTACT_ID, rawId)
                    .withValue(android.provider.ContactsContract.Data.MIMETYPE,
                        android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER, phone)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.Phone.TYPE,
                        android.provider.ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
                    .build())
            }
            if (email.isNotEmpty()) {
                ops.add(android.content.ContentProviderOperation.newInsert(
                    android.provider.ContactsContract.Data.CONTENT_URI
                ).withValue(android.provider.ContactsContract.Data.RAW_CONTACT_ID, rawId)
                    .withValue(android.provider.ContactsContract.Data.MIMETYPE,
                        android.provider.ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.Email.ADDRESS, email)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.Email.TYPE,
                        android.provider.ContactsContract.CommonDataKinds.Email.TYPE_HOME)
                    .build())
            }
            contentResolver.applyBatch(android.provider.ContactsContract.AUTHORITY, ops)
            true
        } catch (e: Exception) {
            Log.e("Contacts", "addContact error: $e")
            false
        }
    }

    private fun updateContact(contactId: String, phone: String, email: String): Boolean {
        if (contactId.isEmpty()) return false
        val id = contactId.toLongOrNull() ?: return false
        return try {
            val ops = arrayListOf<android.content.ContentProviderOperation>()
            // Find RAW_CONTACT_ID
            var rawContactId: Long = -1
            contentResolver.query(
                android.provider.ContactsContract.RawContacts.CONTENT_URI,
                arrayOf(android.provider.ContactsContract.RawContacts._ID),
                "${android.provider.ContactsContract.RawContacts.CONTACT_ID} = ?",
                arrayOf(id.toString()), null
            )?.use { c ->
                if (c.moveToFirst()) {
                    rawContactId = c.getLong(c.getColumnIndexOrThrow(android.provider.ContactsContract.RawContacts._ID))
                }
            }
            if (rawContactId < 0) return false

            if (phone.isNotEmpty()) {
                ops.add(android.content.ContentProviderOperation.newInsert(
                    android.provider.ContactsContract.Data.CONTENT_URI
                ).withValue(android.provider.ContactsContract.Data.RAW_CONTACT_ID, rawContactId)
                    .withValue(android.provider.ContactsContract.Data.MIMETYPE,
                        android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER, phone)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.Phone.TYPE,
                        android.provider.ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
                    .build())
            }
            if (email.isNotEmpty()) {
                ops.add(android.content.ContentProviderOperation.newInsert(
                    android.provider.ContactsContract.Data.CONTENT_URI
                ).withValue(android.provider.ContactsContract.Data.RAW_CONTACT_ID, rawContactId)
                    .withValue(android.provider.ContactsContract.Data.MIMETYPE,
                        android.provider.ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.Email.ADDRESS, email)
                    .withValue(android.provider.ContactsContract.CommonDataKinds.Email.TYPE,
                        android.provider.ContactsContract.CommonDataKinds.Email.TYPE_HOME)
                    .build())
            }
            if (ops.isNotEmpty()) {
                contentResolver.applyBatch(android.provider.ContactsContract.AUTHORITY, ops)
            }
            true
        } catch (e: Exception) {
            Log.e("Contacts", "updateContact error: $e")
            false
        }
    }

    private fun deleteContact(contactId: String): Boolean {
        if (contactId.isEmpty()) return false
        return try {
            val uri = android.provider.ContactsContract.RawContacts.CONTENT_URI
                .buildUpon()
                .appendQueryParameter(
                    android.provider.ContactsContract.CALLER_IS_SYNCADAPTER, "true"
                )
                .build()
            val id = contactId.toLongOrNull() ?: return false
            val rows = contentResolver.delete(uri,
                "${android.provider.ContactsContract.RawContacts.CONTACT_ID} = ?",
                arrayOf(id.toString()))
            if (rows > 0) {
                true
            } else {
                // Fallback: delete via contact ID URI
                try {
                    val contactUri = android.net.Uri.withAppendedPath(
                        android.provider.ContactsContract.Contacts.CONTENT_URI,
                        id.toString()
                    )
                    contentResolver.delete(contactUri, null, null)
                    true
                } catch (e: Exception) {
                    Log.e("Contacts", "deleteContact fallback error: $e")
                    false
                }
            }
        } catch (e: Exception) {
            Log.e("Contacts", "deleteContact error: $e")
            false
        }
    }

    // ── Phone Call ──

    private fun makePhoneCall(number: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_CALL, android.net.Uri.parse("tel:$number"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("PhoneCall", "makePhoneCall error: $e")
            false
        }
    }

    private fun openDialer(number: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_DIAL, android.net.Uri.parse("tel:$number"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("PhoneCall", "openDialer error: $e")
            false
        }
    }

    private fun launchPackage(packageName: String): Boolean {
        if (packageName.isEmpty()) return false
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        startActivity(launchIntent)
        return true
    }

    private fun shareToApp(packageName: String, text: String): Boolean {
        if (packageName.isEmpty() || text.isEmpty()) return false
        return try {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                setPackage(packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(sendIntent)
            true
        } catch (e: Exception) {
            Log.e("ShareToApp", "Failed: $e")
            false
        }
    }

    private fun launchAppByQuery(query: String): Boolean {
        if (query.isEmpty()) return false
        val normalizedQuery = normalize(query)
        if (normalizedQuery.isEmpty()) return false

        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val apps: List<ResolveInfo> = packageManager.queryIntentActivities(launcherIntent, 0)
        val best = apps
            .map { info ->
                val label = info.loadLabel(packageManager)?.toString().orEmpty()
                val packageName = info.activityInfo?.packageName.orEmpty()
                val normalizedLabel = normalize(label)
                val normalizedPackage = normalize(packageName)
                val score = when {
                    normalizedLabel == normalizedQuery -> 100
                    normalizedPackage == normalizedQuery -> 95
                    normalizedLabel.startsWith(normalizedQuery) -> 80
                    normalizedLabel.contains(normalizedQuery) -> 70
                    normalizedPackage.contains(normalizedQuery) -> 60
                    else -> 0
                }
                Triple(score, packageName, label)
            }
            .filter { it.first > 0 && it.second.isNotEmpty() }
            .maxByOrNull { it.first }

        return best?.let { launchPackage(it.second) } ?: false
    }

    private fun normalize(value: String): String {
        return value
            .lowercase(Locale.ROOT)
            .replace("ä", "ae")
            .replace("ö", "oe")
            .replace("ü", "ue")
            .replace("ß", "ss")
            .replace(Regex("[^a-z0-9.]+"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    // ── Offline Speech-to-Text ──

    private fun isOfflineSttAvailable(): Boolean {
        return try {
            val intent = android.content.Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            val activities = packageManager.queryIntentActivities(intent, 0)
            activities.isNotEmpty()
        } catch (e: Exception) {
            Log.e("OfflineSTT", "check error: $e")
            false
        }
    }

    private fun startOfflineListening(preferOffline: Boolean, locale: String, callback: (String?) -> Unit) {
        try {
            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                Log.e("OfflineSTT", "RECORD_AUDIO permission not granted")
                callback(null)
                return
            }

            runOnUiThread {
                speechRecognizer?.destroy()
                speechRecognizer = android.speech.SpeechRecognizer.createSpeechRecognizer(this)

                val intent = android.content.Intent(android.speech.RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE_MODEL, android.speech.RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE, locale)
                    putExtra(android.speech.RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
                    putExtra(android.speech.RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    if (preferOffline) {
                        putExtra(android.speech.RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    }
                }

                speechRecognizer?.setRecognitionListener(object : android.speech.RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {}
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {}
                    override fun onError(error: Int) {
                        Log.e("OfflineSTT", "Recognition error: $error")
                        if (error == android.speech.SpeechRecognizer.ERROR_NO_MATCH && preferOffline) {
                            // Fallback to online
                            startOfflineListening(false, locale, callback)
                        } else {
                            callback(null)
                        }
                    }
                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(android.speech.SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull()
                        Log.d("OfflineSTT", "Result: $text")
                        callback(text)
                    }
                    override fun onPartialResults(partialResults: Bundle?) {}
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                speechRecognizer?.startListening(intent)
            }
        } catch (e: Exception) {
            Log.e("OfflineSTT", "startListening error: $e")
            callback(null)
        }
    }

    private fun stopOfflineListening() {
        try {
            speechRecognizer?.stopListening()
        } catch (e: Exception) {
            Log.e("OfflineSTT", "stop error: $e")
        }
    }

    private fun openOfflineSpeechSettings() {
        try {
            val intent = android.content.Intent("com.google.android.settings.speech.EXTRA_DOWNLOAD_ENTRIES").apply {
                data = android.net.Uri.parse("package:com.google.android.googlequicksearchbox")
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("OfflineSTT", "openSettings error: $e")
            // Fallback to general speech settings
            try {
                val intent = android.content.Intent(android.provider.Settings.ACTION_VOICE_INPUT_SETTINGS)
                startActivity(intent)
            } catch (e2: Exception) {
                Log.e("OfflineSTT", "fallback settings error: $e2")
            }
        }
    }

    // ── Voice Recorder ──

    @Suppress("DEPRECATION")
    private fun startRecording(outputPath: String): Boolean {
        return try {
            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                Log.e("VoiceRecorder", "RECORD_AUDIO permission not granted")
                return false
            }
            mediaRecorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(outputPath)
                prepare()
                start()
            }
            true
        } catch (e: Exception) {
            Log.e("VoiceRecorder", "startRecording error: $e")
            mediaRecorder?.release()
            mediaRecorder = null
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun stopRecording(): Boolean {
        return try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            true
        } catch (e: Exception) {
            Log.e("VoiceRecorder", "stopRecording error: $e")
            mediaRecorder?.release()
            mediaRecorder = null
            false
        }
    }

    // ── Volume Control ──

    private fun getStreamType(stream: String): Int = when (stream) {
        "music" -> AudioManager.STREAM_MUSIC
        "alarm" -> AudioManager.STREAM_ALARM
        "notification" -> AudioManager.STREAM_NOTIFICATION
        "system" -> AudioManager.STREAM_SYSTEM
        "ring" -> AudioManager.STREAM_RING
        "voice_call" -> AudioManager.STREAM_VOICE_CALL
        else -> AudioManager.STREAM_MUSIC
    }

    private fun setVolume(stream: String, level: Double): Boolean {
        return try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            val streamType = getStreamType(stream)
            val maxVolume = audioManager.getStreamMaxVolume(streamType)
            val targetVolume = (level * maxVolume).toInt().coerceIn(0, maxVolume)
            audioManager.setStreamVolume(streamType, targetVolume, 0)
            true
        } catch (e: Exception) {
            Log.e("VolumeControl", "setVolume error: $e")
            false
        }
    }

    private fun getVolume(stream: String): Double {
        return try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            val streamType = getStreamType(stream)
            val current = audioManager.getStreamVolume(streamType)
            val max = audioManager.getStreamMaxVolume(streamType)
            if (max > 0) current.toDouble() / max.toDouble() else 0.0
        } catch (e: Exception) {
            Log.e("VolumeControl", "getVolume error: $e")
            0.0
        }
    }

    private fun setMute(mute: Boolean): Boolean {
        return try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            @Suppress("DEPRECATION")
            audioManager.isStreamMute(AudioManager.STREAM_MUSIC)
            // On newer APIs, use adjustVolume
            if (mute) {
                @Suppress("DEPRECATION")
                audioManager.setStreamMute(AudioManager.STREAM_MUSIC, true)
            } else {
                @Suppress("DEPRECATION")
                audioManager.setStreamMute(AudioManager.STREAM_MUSIC, false)
            }
            true
        } catch (e: Exception) {
            Log.e("VolumeControl", "setMute error: $e")
            false
        }
    }

    // ── WiFi Control ──

    @Suppress("DEPRECATION")
    private fun getWifiState(): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as android.net.wifi.WifiManager
            wifiManager.isWifiEnabled
        } catch (e: Exception) {
            Log.e("WifiControl", "getWifiState error: $e")
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun setWifiEnabled(enabled: Boolean): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as android.net.wifi.WifiManager
            wifiManager.isWifiEnabled = enabled
            true
        } catch (e: Exception) {
            Log.e("WifiControl", "setWifiEnabled error: $e")
            false
        }
    }

    // ── Bluetooth Control ──

    private fun getBluetoothState(): Boolean {
        return try {
            val bluetoothAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            bluetoothAdapter?.isEnabled ?: false
        } catch (e: Exception) {
            Log.e("BluetoothControl", "getBluetoothState error: $e")
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun setBluetoothEnabled(enabled: Boolean): Boolean {
        return try {
            val bluetoothAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            if (bluetoothAdapter == null) return false
            if (enabled) bluetoothAdapter.enable() else bluetoothAdapter.disable()
            true
        } catch (e: Exception) {
            Log.e("BluetoothControl", "setBluetoothEnabled error: $e")
            false
        }
    }

    // ── Device Settings (Brightness, Timeout, DND) ──

    @Suppress("DEPRECATION")
    private fun setBrightness(level: Double): Boolean {
        return try {
            if (android.provider.Settings.System.canWrite(applicationContext)) {
                val lp = window.attributes
                lp.screenBrightness = level.toFloat()
                window.attributes = lp
                true
            } else {
                // Open settings to request WRITE_SETTINGS
                val intent = Intent(android.provider.Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                false
            }
        } catch (e: Exception) {
            Log.e("Settings", "setBrightness error: $e")
            false
        }
    }

    private fun getBrightness(): Double {
        return try {
            val lp = window.attributes
            val brightness = lp.screenBrightness
            if (brightness < 0) {
                // Negative means using system brightness; get actual value
                android.provider.Settings.System.getInt(
                    contentResolver,
                    android.provider.Settings.System.SCREEN_BRIGHTNESS
                ).toDouble() / 255.0
            } else {
                brightness.toDouble()
            }
        } catch (e: Exception) {
            Log.e("Settings", "getBrightness error: $e")
            0.5
        }
    }

    private fun setScreenTimeout(seconds: Int): Boolean {
        return try {
            if (android.provider.Settings.System.canWrite(applicationContext)) {
                android.provider.Settings.System.putInt(
                    contentResolver,
                    android.provider.Settings.System.SCREEN_OFF_TIMEOUT,
                    seconds * 1000
                )
                true
            } else {
                val intent = Intent(android.provider.Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                false
            }
        } catch (e: Exception) {
            Log.e("Settings", "setScreenTimeout error: $e")
            false
        }
    }

    private fun getScreenTimeout(): Int {
        return try {
            android.provider.Settings.System.getInt(
                contentResolver,
                android.provider.Settings.System.SCREEN_OFF_TIMEOUT
            ) / 1000
        } catch (e: Exception) {
            Log.e("Settings", "getScreenTimeout error: $e")
            30
        }
    }

    private fun setDoNotDisturb(enabled: Boolean): Boolean {
        return try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val notificationManager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    if (enabled) {
                        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                    } else {
                        audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    }
                    true
                } else {
                    val intent = Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    false
                }
            } else {
                // API < 23: only AudioManager ringerMode available
                @Suppress("DEPRECATION")
                audioManager.ringerMode = if (enabled) {
                    AudioManager.RINGER_MODE_SILENT
                } else {
                    AudioManager.RINGER_MODE_NORMAL
                }
                true
            }
        } catch (e: Exception) {
            Log.e("Settings", "setDoNotDisturb error: $e")
            false
        }
    }

    private fun getDoNotDisturb(): Boolean {
        return try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            when (audioManager.ringerMode) {
                AudioManager.RINGER_MODE_SILENT, AudioManager.RINGER_MODE_VIBRATE -> true
                else -> false
            }
        } catch (e: Exception) {
            Log.e("Settings", "getDoNotDisturb error: $e")
            false
        }
    }

    private fun openSystemSettings(page: String): Boolean {
        return try {
            val intent = when (page) {
                "display" -> Intent(android.provider.Settings.ACTION_DISPLAY_SETTINGS)
                "sound" -> Intent(android.provider.Settings.ACTION_SOUND_SETTINGS)
                "wifi" -> Intent(android.provider.Settings.ACTION_WIFI_SETTINGS)
                "bluetooth" -> Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)
                "battery" -> Intent(android.provider.Settings.ACTION_BATTERY_SAVER_SETTINGS)
                "notifications" -> Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                "apps" -> Intent(android.provider.Settings.ACTION_APPLICATION_SETTINGS)
                "security" -> Intent(android.provider.Settings.ACTION_SECURITY_SETTINGS)
                "storage" -> Intent(android.provider.Settings.ACTION_INTERNAL_STORAGE_SETTINGS)
                "developer" -> Intent(android.provider.Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                else -> Intent(android.provider.Settings.ACTION_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("Settings", "openSystemSettings error: $e")
            false
        }
    }

    // ── Open File (PDF, Office, Images, etc.) ──

    private fun openFileWithMime(filePath: String, mimeType: String): Boolean {
        return try {
            val file = java.io.File(filePath)
            if (!file.exists()) return false

            val uri = androidx.core.content.FileProvider.getUriForFile(
                applicationContext,
                "${packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            // Find app that can handle it
            val resolveInfo = packageManager.queryIntentActivities(intent, 0)
            if (resolveInfo.isNotEmpty()) {
                startActivity(intent)
                true
            } else {
                // Try with generic type
                val genericIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "*/*")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                val genericResolve = packageManager.queryIntentActivities(genericIntent, 0)
                if (genericResolve.isNotEmpty()) {
                    startActivity(genericIntent)
                    true
                } else {
                    Log.e("OpenFile", "No app found to open $mimeType")
                    false
                }
            }
        } catch (e: Exception) {
            Log.e("OpenFile", "openFile error: $e")
            false
        }
    }
}
