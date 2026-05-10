package com.aibuddy.app

import android.content.Intent
import android.content.pm.ResolveInfo
import android.Manifest
import android.content.pm.PackageManager
import android.provider.ContactsContract
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val appLauncherChannel = "ai_buddy/app_launcher"
    private val contactsChannel = "com.ai-buddy.app/contacts"

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
                else -> result.notImplemented()
            }
        }
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

    private fun launchPackage(packageName: String): Boolean {
        if (packageName.isEmpty()) return false
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        startActivity(launchIntent)
        return true
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
}
