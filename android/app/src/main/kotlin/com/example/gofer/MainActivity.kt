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

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // -------------------------------------------------------------------
        // Default Dialer Channel (unchanged)
        // -------------------------------------------------------------------
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

        // -------------------------------------------------------------------
        // Blocked Numbers Channel (unchanged)
        // -------------------------------------------------------------------
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

        // -------------------------------------------------------------------
        // Incoming Call Channel (answer/reject calls from Flutter UI)
        // -------------------------------------------------------------------
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INCOMING_CALL_CHANNEL
        ).setMethodCallHandler { call, result ->
            val tm = getSystemService(TELECOM_SERVICE) as TelecomManager

            when (call.method) {
                // Answer incoming call
                "answerCall" -> {
                    try {
                        tm.acceptRingingCall()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CALL_ERROR", "Failed to answer call", e.localizedMessage)
                    }
                }

                // Reject incoming call
                "rejectCall" -> {
                    try {
                        tm.endCall()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CALL_ERROR", "Failed to reject call", e.localizedMessage)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // -------------------------------------------------------------------
    // Override onNewIntent to handle incoming call Intents when app is launched from background
    // -------------------------------------------------------------------
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)

        // Extract incoming number passed from BroadcastReceiver
        intent?.getStringExtra("incoming_number")?.let { number ->
            // Pass the number to Flutter via MethodChannel
            MethodChannel(
                flutterEngine?.dartExecutor?.binaryMessenger,
                INCOMING_CALL_CHANNEL
            ).invokeMethod(
                "incomingCall",
                mapOf("number" to number)
            )
        }
    }

    // -------------------------------------------------------------------
    // BroadcastReceiver to detect incoming calls even if app is closed
   
    //   Listens for changes in TelephonyManager.EXTRA_STATE (ringing, idle, offhook).
    //   Detects when the phone is ringing and gets the incoming number.
    //   Launches the MainActivity if the app is closed or in the background.
    //   Passes the incoming number via Intent extras.
    //   Ensures the activity is reused if already running (FLAG_ACTIVITY_SINGLE_TOP).
    
    // -------------------------------------------------------------------
    
    
    class IncomingCallReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            if (state == TelephonyManager.EXTRA_STATE_RINGING && incomingNumber != null) {
                // Launch MainActivity with incoming number as extra
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("incoming_number", incomingNumber)
                }
                context.startActivity(launchIntent)
            }
        }
    }

    // -------------------------------------------------------------------
    // Fetch blocked numbers
    // -------------------------------------------------------------------
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

    // -------------------------------------------------------------------
    // Block a number
    // -------------------------------------------------------------------
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

    // -------------------------------------------------------------------
    // Unblock a number
    // -------------------------------------------------------------------
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
