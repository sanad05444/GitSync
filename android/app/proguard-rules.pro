# Local Notificationd
-keep class com.dexterous.** { *; }

# In app Purchase
-keep class com.amazon.** {*;}
-keep class com.dooboolab.** { *; }
-keep class com.android.vending.billing.**
-dontwarn com.amazon.**
-keepattributes *Annotation*

# Reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keep class **.R$* { *; }
-keepclassmembers class * {
    public <init>(...);
}

-keep class org.xmlpull.v1.** { *; }