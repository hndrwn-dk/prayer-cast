# WorkManager was added in 1.0.9 for AlarmHealWorker. Release R8 was
# stripping Room's WorkDatabase_Impl, so androidx.startup
# InitializationProvider threw on process start:
#   Failed to create an instance of class androidx.work.impl.WorkDatabase
# Pixel logcat: FATAL EXCEPTION before any Flutter frame.
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class com.tursinalabs.prayer_cast.AlarmHealWorker { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**
