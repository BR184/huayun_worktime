package com.hikiot.worktime

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }
    
    /**
     * 创建最高优先级通知渠道
     * 确保所有国产系统（小米、华为、OPPO、vivo等）默认开启所有通知功能
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "punch_reminder_high"
            val channelName = "打卡提醒"
            val channelDesc = "上下班打卡提醒通知（高优先级）"
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            
            // 删除所有旧渠道，确保重新创建
            notificationManager.deleteNotificationChannel("punch_reminder")
            notificationManager.deleteNotificationChannel("punch_reminder_high")
            
            // 创建新的最高优先级渠道
            // 使用 IMPORTANCE_HIGH (4) - 这是通知能使用的最高级别
            // IMPORTANCE_MAX (5) 仅用于系统级别，普通App无法使用
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = channelDesc
                
                // 启用振动 - 必须在创建时设置，之后无法修改
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                
                // 启用声音 - 使用系统默认通知铃声
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE) // 使用铃声级别
                    .build()
                setSound(soundUri, audioAttributes)
                
                // 启用LED灯
                enableLights(true)
                lightColor = 0xFF2196F3.toInt()
                
                // 显示角标
                setShowBadge(true)
                
                // 锁屏完整显示
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                
                // 允许绕过勿扰模式（Android 8.0+）
                setBypassDnd(false) // 不绕过勿扰，避免被系统拒绝
            }
            
            notificationManager.createNotificationChannel(channel)
            
            // 输出日志确认渠道创建
            val createdChannel = notificationManager.getNotificationChannel(channelId)
            if (createdChannel != null) {
                println("通知渠道创建成功: importance=${createdChannel.importance}, sound=${createdChannel.sound}, vibration=${createdChannel.shouldVibrate()}")
            }
        }
    }
}
