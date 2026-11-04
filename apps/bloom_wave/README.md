# Bloom Wave

씨앗으로 덮인 픽셀 그림에 물방울을 떨어뜨려 꽃 웨이브로 그림을 완성하는 한 손 퍼즐.
설계 문서는 [docs/](docs/) (확정 규칙: `00_규칙_확인_질문.md`, 기획: `01_게임기획서.md`).

이 앱은 모노레포의 다른 앱(Flutter)과 달리 **TypeScript 하나로** 규칙 엔진·레벨 생성기·앱이 같은 코드를 쓴다 (기획서 11장).

```
packages/core     규칙 엔진·솔버·생성기 (앱과 생성기 공유, node --test)
tools/levelgen    PNG → 클리어 보장 레벨 팩 CLI (build / verify)
app               Vite + PixiJS 앱, Capacitor Android
```

## 사전 조건
- Node.js 22.18 이상
- Android 빌드: Android SDK(API 36), **JDK 21** (Capacitor 8 요구 — JDK 17로는 `invalid source release: 21`로 실패), `ANDROID_HOME`
  - 다른 Flutter 앱은 JDK 17을 쓰므로, 이 앱을 빌드하는 셸에서만 `JAVA_HOME`을 JDK 21로 지정한다.
  - 앱이 직접 선언한 권한은 `VIBRATE`(햅틱)뿐이다. **인터넷·광고 ID 권한은 AdMob 플러그인이 추가한다** — Play 데이터 보안 양식에 광고를 반영해야 한다.
  - AdMob ID는 아직 Google **테스트 ID**다. 출시 전에 `app/src/monetize/ads.ts`와 `app/android/app/src/main/AndroidManifest.xml`을 실제 ID로 교체한다.

## 명령
```sh
npm install                 # 이 폴더에서
npm test                    # core + levelgen + app(Vitest)
npm run levels:build        # tools/levelgen/levels.config.json → out/pack-01.json (약 6분, app에 복사됨)
npm run levels:verify       # 팩 전체를 솔버로 재검증 (실패 시 종료 코드 1)
npm run dev                 # http://localhost:5173  (?manualTick=1 : 테스트용 수동 틱)
cd app && PW_CHANNEL=chrome npx playwright test   # 레벨 1~5 자동 클리어 + 스크린샷 (test-results/)
cd app && npm run android:debug                   # 디버그 APK
cd app && npm run android:release                 # 서명된 AAB (android/keystore.properties 필요)
```

## 아트 교체
- 레벨 그림: `tools/levelgen/art/<이름>.png` (지금은 `src/art-source.ts`의 텍스트 아트를 `npm run art -w @bloom-wave/levelgen`으로 변환한 플레이스홀더)
- 칸 스프라이트: `app/src/ui/textures.ts` (흰색으로 그려 tint로 색 입힘)
- 앱 아이콘: `app/assets/*.png` 교체 후 `cd app && npm run icons`
