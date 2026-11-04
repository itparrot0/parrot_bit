# Bloom Wave

씨앗으로 덮인 픽셀 그림에 물방울을 떨어뜨려 꽃 웨이브로 그림을 완성하는 한 손 퍼즐.
설계 문서는 [docs/](docs/) (확정 규칙: `00_규칙_확인_질문.md`, 기획: `01_게임기획서.md`).

**Flutter 앱이다 (2026-11-04 TypeScript에서 전환).** 규칙 엔진·솔버·생성기는 Flutter 없이 도는
순수 Dart(`lib/domain/`)이고, 앱과 레벨 생성기가 같은 파일을 쓴다. 전환 직전 TS 결과와 같다는 것을
`test/domain/ts_parity_test.dart`가 확인한다(전환 당시 120레벨 팩 `test/fixtures/pack-01-ts.json`의 솔버 해법·노드 수, 생성 레벨 바이트 단위).

```
lib/
├── domain/          순수 Dart: engine(규칙) · solver · generator   ← 앱과 tool/levelgen 공유
├── game/            GameController(틱 타이머) · 연출 상태 · 보드/물방울 그리기 · 비슷한 색
├── economy/         gold(완성 보상) · skins(꽃 스킨 목록) · gacha(뽑기 규칙·확률) — 조절 지점
├── save/            진행도·골드·설정 저장 (shared_preferences, schema 3)
├── platform/        광고(AdMob) · 결제(in_app_purchase) · 효과음 · 진동
├── screens/         홈 · 게임 · 설정(일시정지 메뉴에서) · 상점 · 스킨 뽑기
└── app.dart, main.dart
assets/levels/pack-01.json   출시 1000 스테이지 (tool/levelgen 이 만든다, 2~4스테이지마다 어려움 등급)
tool/levelgen/       PNG → 클리어 보장 레벨 팩 CLI (build / verify) — tool/levelgen/README.md
test/                domain · game · app(화면 흐름) · levelgen
```

## 화면 흐름 (2026-11-04)

- **홈**: 다음 스테이지 시작 + 상점 + 스킨 뽑기 버튼, 골드 잔액. 지난 스테이지를 다시 하는 메뉴(스테이지 맵·정원)는 없다.
- **상점**: 꽃 스킨 모음(조각 진행도·장착), 광고 제거, 스킨 뽑기로 가기.
- **스킨 뽑기**: 100 골드로 가챠 머신을 돌려 꽃 스킨 퍼즐 조각 1개. 4조각 모으면 해금, 중복은 10 골드(10%) 반환,
  해금한 스킨의 조각은 더 나오지 않는다. "확률 보기"는 규칙 함수의 값을 그대로 보여 준다.
  연출은 뽑기 화면에서만 돈다 — 게임 보드는 스킨마다 미리 만든 경로 하나를 그려서 어떤 스킨이든 비용이 같다.
- **게임**: 상단(홈·일시정지) / 보드 / 활성 슬롯 4칸 / 대기열 세로 줄 / 힌트·재시작.
  일시정지 메뉴: 계속하기 · 재시작 · **설정** · 홈.
- **완성**: Full Bloom 연출 + **골드 무작위 지급** → [홈] [다음 스테이지] (마지막 스테이지는 [홈]만).
  떠날 때 전면 광고 1회 (광고 제거 구매자는 없음).
- **실패**: [다시 하기] [홈], 광고 없음.

골드 지급량은 `lib/economy/gold.dart`의 `goldReward` (현재 10~30), 뽑기 가격·반환율은 `lib/economy/gacha.dart`의 `GachaConfig`.

## 명령

```sh
flutter pub get                 # 저장소 루트에서 1회 (pub workspace)
cd apps/bloom_wave
flutter test                    # domain · game · 화면 흐름 · levelgen
flutter run                     # 기기/에뮬레이터
flutter run -d chrome           # 브라우저 플레이 테스트 (광고는 가짜 패널)
flutter build apk --release     # APK (android/key.properties 없으면 디버그 키로 서명)
flutter build appbundle         # 스토어용 AAB (android/key.properties 필요)
dart run tool/levelgen/levelgen.dart verify tool/levelgen/out/pack-01.json
dart run tool/levelgen/levelgen.dart build tool/levelgen/levels.config.json   # 1000 스테이지 약 4분, assets 로 복사
```

## 출시 전 할 일

- **AdMob 테스트 ID → 실제 ID**: `lib/platform/ads.dart`, `android/app/src/main/AndroidManifest.xml`,
  `ios/Runner/Info.plist`(GADApplicationIdentifier). 인터넷·광고 ID 권한은 google_mobile_ads 플러그인이
  추가하므로 Play 데이터 보안 양식에 광고를 반영한다.
- **광고 제거 상품**: Play Console 에 관리형 상품 `remove_ads` 를 만든다. 결제는 `StoreBilling`(in_app_purchase)이
  처리한다 — 실기기 결제는 아직 확인하지 못했다.
- **업로드 키**: `android/key.properties` (storeFile, storePassword, keyAlias, keyPassword). git 에 올리지 않는다.
- 레벨 그림 363장(손그림 90 + 코드 그림 273: 풍경화·캐릭터·일러스트)은 아직 플레이스홀더 픽셀 아트다 (`tool/levelgen/art/`). 디자이너 PNG 로 같은 이름을 덮어쓰면 된다.
- 아이콘: `android/app/src/main/res/mipmap-*` (TS 버전에서 옮김), 원본 `assets/icon/`.
