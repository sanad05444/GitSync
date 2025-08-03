package com.viscouspot.gitsync

import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class GitTileSyncService: TileService() {
    override fun onClick() {
        super.onClick()
        val tileSyncIntent = Intent(this, id.flutter.flutter_background_service.BackgroundService::class.java)
        tileSyncIntent.action = "TILE_SYNC"
        startService(tileSyncIntent)
    }
}