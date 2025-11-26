package com.example.gofer

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.net.Uri
import android.provider.BlockedNumberContract
import android.provider.CallLog
import android.content.BroadcastReceiver
import android.content.Context

class MainActivity : FlutterActivity() {

    private val CHANNEL = "dialer.default.channel" // Existing default dialer channel

    // Channel for blocked numbers feature
    private val BLOCKED_CHANNEL = "gofer.dialer/blocked_numbers"

    // Channel for incoming call actions (answer/reject)
    private val INCOMING_CALL_CHANNEL = "gofer.dialer/incoming_call"

    // -------------------------------------------------------------------
    // SharedPreferences key for storing incoming number when Flutter is not running yet
    // -------------------------------------------------------------------
    private val PREFS_NAME = "gofer_prefs"

    // -------------------------------------------------------------------
    // NEW: Map to track call start times for logging duration
    // Key = phone number, Value = call start timestamp in millis
    // -------------------------------------------------------------------
    companion object {
        val callStartTimes = mutableMapOf<String, Long>() // <-- static access for receiver

        // ----------------------------------------------------------------------
        // NEW: Helper to insert a call log into Android system database
        // Can be safely called from BroadcastReceiver even if MainActivity is not alive
        // ----------------------------------------------------------------------
        fun saveCallLog(context: Context? = null, number: String, type: Int, duration: Int) {
            try {
                val values = ContentValues().apply {
                    put(CallLog.Calls.NUMBER, number)
                    put(CallLog.Calls.TYPE, type)
                    put(CallLog.Calls.DATE, System.currentTimeMillis())
                    put(CallLog.Calls.DURATION, duration)
                    put(CallLog.Calls.NEW, if (type == CallLog.Calls.MISSED_TYPE) 1 else 0)
                }

                context?.contentResolver?.insert(CallLog.Calls.CONTENT_URI, values)
            } catch (e: SecurityException) {
                e.printStackTrace() // WRITE_CALL_LOG permission required
            }
        }
    }

    private fun saveIncomingNumber(context: Context, number: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString("incoming_number", number).apply()
    }

    private fun getStoredIncomingNumber(): String? {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString("incoming_number", null)
    }

    private fun clearStoredIncomingNumber() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove("incoming_number").apply()
    }

    // -------------------------------------------------------------------
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // -------------------------------------------------------------------
        // Cache the engine globally so Background Receivers can access it
        // -------------------------------------------------------------------
        FlutterEngineCache
            .getInstance()
            .put("main_engine", flutterEngine)
        // -------------------------------------------------------------------

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

                // -------------------------------------------------------------------
                // END ONGOING CALL (Feature F3)
                // -------------------------------------------------------------------
                "endCall" -> {
                    try {
                        tm.endCall()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CALL_ERROR", "Failed to end call", e.localizedMessage)
                    }
                }

                "getSavedIncomingNumber" -> {
                    result.success(getStoredIncomingNumber())
                }

                "clearSavedIncomingNumber" -> {
                    clearStoredIncomingNumber()
                    result.success(null)
                }

                "placeCall" -> {
                    val number = call.argument<String>("number") ?: ""
                    if (number.isNotEmpty()) {
                        val telUri = Uri.parse("tel:$number")
                        val callIntent = Intent(Intent.ACTION_DIAL, telUri)
                        callIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        try {
                            startActivity(callIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CALL_ERROR", "Failed to place call", e.localizedMessage)
                        }
                    } else {
                        result.error("CALL_ERROR", "No number provided", "Number argument is null or empty")
                    }
                }

                // -------------------------------------------------------------------
                // DELETE CALL HISTORY FOR GIVEN NUMBER (Feature F2)
                // -------------------------------------------------------------------
                "deleteCallHistoryForNumber" -> {
                    val number = call.argument<String>("number") ?: ""
                    if (number.isNotEmpty()) {
                        try {
                            val normalized = number.replace(Regex("\\D"), "")
                            val deletedRows = contentResolver.delete(
                                CallLog.Calls.CONTENT_URI,
                                "REPLACE(${CallLog.Calls.NUMBER}, '-', '') = ?",
                                arrayOf(normalized)
                            )
                            result.success(deletedRows > 0)
                        } catch (e: SecurityException) {
                            result.error("PERMISSION_ERROR", "WRITE_CALL_LOG permission required", e.localizedMessage)
                        } catch (e: Exception) {
                            result.error("DELETE_ERROR", "Failed to delete call history", e.localizedMessage)
                        }
                    } else {
                        result.error("CALL_ERROR", "No number provided", "Number argument is null or empty")
                    }
                }

                else -> result.notImplemented()
            }
        }

        val storedNumber = getStoredIncomingNumber()
        if (!storedNumber.isNullOrEmpty()) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                INCOMING_CALL_CHANNEL
            ).invokeMethod("incomingCallStored", null)
        }
    }

    // -------------------------------------------------------------------
    // FIX: Correct signature for onNewIntent
    // -------------------------------------------------------------------
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra("incoming_number")?.let { number ->
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, INCOMING_CALL_CHANNEL)
                    .invokeMethod("incomingCall", mapOf("number" to number))
            }
        }
    }

    class IncomingCallReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val incomingNumber =
                intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            // ----------------------------------------------------------------------
            // Track call start times to calculate duration for call logs
            // ----------------------------------------------------------------------
            if (state == TelephonyManager.EXTRA_STATE_RINGING && incomingNumber != null) {
                saveNumberForFlutter(context, incomingNumber)
                callStartTimes[incomingNumber] = System.currentTimeMillis()

                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("incoming_number", incomingNumber)
                }
                context.startActivity(launchIntent)
            }

            // Call answered: store start time if not already
            if (state == TelephonyManager.EXTRA_STATE_OFFHOOK && incomingNumber != null) {
                callStartTimes[incomingNumber] = callStartTimes[incomingNumber] ?: System.currentTimeMillis()
            }

            // ----------------------------------------------------------------------
            // Notify Flutter when the call ends (state becomes IDLE)
            // Also store call log in system database
            // ----------------------------------------------------------------------
            if (state == TelephonyManager.EXTRA_STATE_IDLE) {

                // Notify Flutter safely
                val engine = FlutterEngineCache.getInstance().get("main_engine")
                engine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, "gofer.dialer/incoming_call")
                        .invokeMethod("callEnded", null)
                }

                // Save call log safely even if MainActivity not running
                incomingNumber?.let { number ->
                    val startTime = callStartTimes[number] ?: System.currentTimeMillis()
                    val duration = ((System.currentTimeMillis() - startTime) / 1000).toInt()
                    val type = if (duration > 0) CallLog.Calls.INCOMING_TYPE else CallLog.Calls.MISSED_TYPE

                    MainActivity.saveCallLog(context = context, number = number, type = type, duration = duration)
                    callStartTimes.remove(number)
                }
            }
        }

        private fun saveNumberForFlutter(context: Context, number: String) {
            val prefs = context.getSharedPreferences("gofer_prefs", Context.MODE_PRIVATE)
            prefs.edit().putString("incoming_number", number).apply()
        }
    }

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
