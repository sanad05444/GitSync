package com.viscouspot.gitsync

import android.app.Service
import android.content.Intent
import android.os.IBinder
import io.flutter.Log

class GitSyncService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == null) {
            return START_STICKY
        }

        val repoman_repoIndex = intent.getIntExtra("repoman_repoIndex", 0)

        when (intent.action) {
            "INTENT_SYNC" -> {
                Log.d("ToServiceCommand", "Intent Sync")

                val intentSyncIntent = Intent(this, id.flutter.flutter_background_service.BackgroundService::class.java)
                intentSyncIntent.action = "INTENT_SYNC"
                intentSyncIntent.putExtra("repoman_repoIndex", repoman_repoIndex.toString())
                startService(intentSyncIntent)
            }
        }

        return START_STICKY
    }

    override fun onBind(p0: Intent?): IBinder? {
        return null
    }
}