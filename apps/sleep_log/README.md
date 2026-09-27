# sleep_log (슬립로그)

캘린더 기반 수면·감정 다이어리. 정신건강 목적.

- 기획: [`docs/prd/sleep_log.md`](../../docs/prd/sleep_log.md)
- 화면 흐름: [`docs/screen-flow/sleep_log.md`](../../docs/screen-flow/sleep_log.md)

## 현재 상태

**도메인 구현 완료** — 규칙과 판정은 전부 있고 테스트로 덮여 있다.
화면은 아직 placeholder 5개, 저장 계층은 없다.

## 구조

```
lib/
├── main.dart              # ProviderScope + MaterialApp.router
├── app/router.dart        # go_router — 라우트 이름 = 화면흐름 문서의 화면 ID
├── domain/                # 순수 Dart. Flutter 없이 테스트된다
│   ├── diary_date.dart        # 시각 없는 날짜 타입
│   ├── sleep_session.dart     # 취침·기상 → 수면시간 (자정 넘김)
│   ├── sleep_mark.dart        # 목표 수면시간과 z 4단계 판정
│   ├── mood_tag.dart          # 태그 + 묶음 + 기본 팔레트 15개
│   ├── diary_entry.dart       # 하루 기록
│   ├── safety_check.dart      # 안전 안내 2단계 판정
│   └── tag_sleep_report.dart  # 태그별 평균 수면시간
└── screens/               # 화면 5개 (전부 placeholder)
```

앞으로 추가될 곳:

```
lib/
├── data/                  # drift DB + Repository
└── widgets/               # 달력 (월 그리드를 직접 만든다 — 패키지 미사용)
```

**임계값·팔레트는 전부 `domain/`의 상수다.** 조정은 문서가 아니라 코드에서 한다.

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
