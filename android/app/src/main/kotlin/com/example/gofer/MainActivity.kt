package com.example.gofer

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.net.Uri
import android.provider.BlockedNumberContract
import android.content.BroadcastReceiver
import android.content.Context

class MainActivity: FlutterActivity() {

    private val CHANNEL = "dialer.default.channel" // Existing default dialer channel

    // Channel for blocked numbers feature
    private val BLOCKED_CHANNEL = "gofer.dialer/blocked_numbers"

    // Channel for incoming call actions (answer/reject)
    private val INCOMING_CALL_CHANNEL = "gofer.dialer/incoming_call"

    // -------------------------------------------------------------------
    // SharedPreferences key for storing incoming number when Flutter is not running
    // -------------------------------------------------------------------
    private val PREFS_NAME = "gofer_prefs"

    private fun saveIncomingNumber(context: Context, number: String) {
        // Saves incoming number for Flutter to read when engine starts
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString("incoming_number", number).apply()
    }

    private fun getStoredIncomingNumber(): String? {
        // Retrieves saved number for the Flutter side
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString("incoming_number", null)
    }

    private fun clearStoredIncomingNumber() {
        // Removes number after Flutter consumes it
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove("incoming_number").apply()
    }

    // -------------------------------------------------------------------
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Default Dialer Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "isDefaultDialer" -> {
                    val tm = getSystemService(TELECOM_SERVICE) as TelecomManager
                    val isDefault = tm.defaultDialerPackage == packageName
                    result.success(isDefault)
                }

                "requestDefaultDialer" -> {
                    val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
                    intent.putExtra(
                        TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME,
                        packageName
                    )
                    startActivity(intent)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // Blocked Numbers Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BLOCKED_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "getBlockedNumbers" -> result.success(getBlockedNumbers())
                "blockNumber" -> {
                    val number = call.argument<String>("number") ?: ""
                    result.success(blockNumber(number))
                }
                "unblockNumber" -> {
                    val number = call.argument<String>("number") ?: ""
                    result.success(unblockNumber(number))
                }
                else -> result.notImplemented()
            }
        }

        // Incoming Call Channel (answer/reject + shared prefs support)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INCOMING_CALL_CHANNEL
        ).setMethodCallHandler { call, result ->
            val tm = getSystemService(TELECOM_SERVICE) as TelecomManager

            when (call.method) {
                "answerCall" -> {
                    try {
                        tm.acceptRingingCall()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CALL_ERROR", "Failed to answer call", e.localizedMessage)
                    }
                }

                "rejectCall" -> {
                    try {
                        tm.endCall()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CALL_ERROR", "Failed to reject call", e.localizedMessage)
                    }
                }

                // Flutter requests stored incoming number (Option A)
                "getSavedIncomingNumber" -> {
                    result.success(getStoredIncomingNumber())
                }

                // Flutter clears stored number after reading it
                "clearSavedIncomingNumber" -> {
                    clearStoredIncomingNumber()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // Notify Flutter engine at startup if there is a stored incoming number
        val storedNumber = getStoredIncomingNumber()
        if (!storedNumber.isNullOrEmpty()) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                INCOMING_CALL_CHANNEL
            ).invokeMethod("incomingCallStored", null)
        }
    }

    // Override onNewIntent to handle incoming call Intents when app is in background
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)

        intent?.getStringExtra("incoming_number")?.let { number ->
            MethodChannel(
                flutterEngine?.dartExecutor?.binaryMessenger,
                INCOMING_CALL_CHANNEL
            ).invokeMethod(
                "incomingCall",
                mapOf("number" to number)
            )
        }
    }

    // BroadcastReceiver to detect incoming calls even if app is closed
    class IncomingCallReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val incomingNumber =
                intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            if (state == TelephonyManager.EXTRA_STATE_RINGING && incomingNumber != null) {

                // Store number for Flutter to read when engine starts
                saveNumberForFlutter(context, incomingNumber)

                // Launch MainActivity with incoming number (existing behavior)
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("incoming_number", incomingNumber)
                }
                context.startActivity(launchIntent)
            }
        }

        // Helper to access shared prefs from receiver
        private fun saveNumberForFlutter(context: Context, number: String) {
            val prefs = context.getSharedPreferences("gofer_prefs", Context.MODE_PRIVATE)
            prefs.edit().putString("incoming_number", number).apply()
        }
    }

    // Fetch blocked numbers
    private fun getBlockedNumbers(): List<String> {
        val list = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val uri = BlockedNumberContract.BlockedNumbers.CONTENT_URI
            val projection = arrayOf(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER)
            val cursor = contentResolver.query(uri, projection, null, null, null)
            cursor?.use {
                val index = cursor.getColumnIndex(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER)
                while (cursor.moveToNext()) {
                    list.add(cursor.getString(index))
                }
            }
        }
        return list
    }

    private fun blockNumber(number: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val values = ContentValues().apply {
                put(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER, number)
            }
            val uri: Uri? = contentResolver.insert(BlockedNumberContract.BlockedNumbers.CONTENT_URI, values)
            return uri != null
        }
        return false
    }

    private fun unblockNumber(number: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val uri = BlockedNumberContract.BlockedNumbers.CONTENT_URI
            val selection = "${BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER} = ?"
            val args = arrayOf(number)
            val rowsDeleted = contentResolver.delete(uri, selection, args)
            return rowsDeleted > 0
        }
        return false
    }
}
