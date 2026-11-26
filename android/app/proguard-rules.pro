# Keep ML Kit Text Recognition script classes for all 5 scripts
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# uCrop (image_cropper) references OkHttp for remote-image cropping. This app
# only crops local images and does not ship OkHttp, so silence R8's warnings.
-dontwarn okhttp3.**

# WorkManager -> Room, on the startup path.
#
# google_mobile_ads pulls in work-runtime, which opens its own Room database
# from androidx.startup's InitializationProvider -- before the first frame, so a
# failure here is an instant crash on tap. Room instantiates
# androidx.work.impl.WorkDatabase_Impl by reflection, so both its name and its
# no-arg constructor have to survive R8. Room's own consumer rules keep the
# RoomDatabase subclass *names* but not their <init>(), and R8 full mode drops
# the constructor, so release builds died with
#
#   Unable to get provider androidx.startup.InitializationProvider
#   Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
#
# Debug builds skip R8, which is why only the APK crashed. Re-check these rules
# if this stack trace ever comes back after a dependency bump.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keep class androidx.work.** { *; }
-dontwarn androidx.room.**
-dontwarn androidx.work.**
