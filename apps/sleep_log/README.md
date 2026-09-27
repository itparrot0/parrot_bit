# sleep_log (슬립로그)

캘린더 기반 수면·감정 다이어리. 정신건강 목적.

- 기획: [`docs/prd/sleep_log.md`](../../docs/prd/sleep_log.md)
- 화면 흐름: [`docs/screen-flow/sleep_log.md`](../../docs/screen-flow/sleep_log.md)

## 현재 상태

스캐폴딩 완료 — 라우트 골격과 빈 화면 5개만 있다. 기능은 미구현.

## 구조

```
lib/
├── main.dart              # ProviderScope + MaterialApp.router
├── app/router.dart        # go_router — 라우트 이름 = 화면흐름 문서의 화면 ID
└── screens/               # 화면 5개 (전부 placeholder)
```

앞으로 추가될 곳:

```
lib/
├── domain/                # 순수 Dart 모델 (수면 기록, z 단계 판정, 감정 태그)
└── data/                  # drift DB + Repository
```

## 앱별 결정 (저장소 공통 규칙과 다른 점)

- **플랫폼은 Android·iOS만.** 개인 건강 기록이라 Web을 빼고, 사용 맥락(기상 직후
  폰)과 맞지 않아 Desktop도 뺐다 (PRD §6).
- **일기 DB는 이 앱 안에 drift로 둔다.** `core_storage`에는 설정값만 넣는다 —
  테이블 스키마는 도메인 지식이라 패키지에 넣으면 `docs/04-package-boundaries.md`
  위반이다. **이 앱이 저장소에서 drift를 처음 쓰는 앱이 된다** (PRD §9-3).
- **네트워크를 쓰지 않는다.** 로컬 전용이므로 `core_network` 의존이 없다 (PRD §9-1).
- 달력 위젯은 `lib/widgets/`에 둔다. 두 번째 앱이 같은 달력을 쓸 때까지
  `core_ui`로 추출하지 않는다 (Rule of Two).

## 실행

저장소 루트에서 의존성을 해석한다 (pub workspace).

```sh
flutter pub get                       # 루트에서 1회
cd apps/sleep_log && flutter run
flutter test                          # 이 앱만
```
