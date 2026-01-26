package com.aidx.health.app

import android.net.Uri
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

class WearDataListenerService : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        try {
            for (event in dataEvents) {
                if (event.type == DataEvent.TYPE_CHANGED) {
                    val item = event.dataItem
                    val uri: Uri = item.uri
                    if (uri.path == "/live_vitals") {
                        val dataMap = DataMapItem.fromDataItem(item).dataMap
                        val heartRate = dataMap.getInt("heartRate", -1)
                        val spo2 = dataMap.getInt("spo2", -1)
                        val bpSys = dataMap.getInt("bpSystolic", -1)
                        val bpDia = dataMap.getInt("bpDiastolic", -1)
                        val json = "{" +
                                "\"heartRate\":$heartRate," +
                                "\"spo2\":$spo2," +
                                "\"bpSystolic\":$bpSys," +
                                "\"bpDiastolic\":$bpDia" +
                                "}"
                        MainActivity.sendWearData(json)
                    }
                }
            }
        } catch (_: Throwable) {
            // Ignore malformed/unexpected data
        } finally {
            dataEvents.release()
        }
    }
}