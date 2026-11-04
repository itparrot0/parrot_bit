# 릴리스 빌드(R8) 축소 규칙.
# google_mobile_ads → play-services-ads 가 쓰는 WorkManager(Room) 는 리플렉션으로 WorkDatabase_Impl 을 만든다.
# R8 이 이 생성 클래스를 지우면 앱 시작 직후 "Failed to create an instance of androidx.work.impl.WorkDatabase"
# 로 즉시 종료된다 (2026-11-05 확인). 그래서 Room 데이터베이스 구현과 WorkManager 를 남긴다.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
