# Keep ML Kit Text Recognition script classes for all 5 scripts
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# uCrop (image_cropper) references OkHttp for remote-image cropping. This app
# only crops local images and does not ship OkHttp, so silence R8's warnings.
-dontwarn okhttp3.**
