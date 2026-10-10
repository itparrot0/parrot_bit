# 작업 이력

> 진행 중인 것들이 **어디서 멈췄고 다음 한 걸음이 무엇인지** 적는다.
> 설계 근거는 각 PRD·설계 문서에 있으므로 여기서 되풀이하지 않는다.
> 새 작업을 시작할 때 이 문서를 먼저 읽고, 멈출 때 갱신한다.

- **마지막 갱신**: 2026-10-10
- **상태**: 아래 두 건 모두 **중단(보류)** — 새 프로젝트 기획으로 넘어감

---

## 1. 머지 게임 — 승격 후 정식 기획 단계에서 멈춤

| | |
|---|---|
| 코드 | `apps/proto_merge` (프로토타입, 동작함) |
| 문서 | `docs/prd/proto_merge.md` (승격 판정 기록 포함), `docs/design/theme-design.md` |
| 마지막 커밋 | `a5c25c4` (2026-09-27) |

**끝난 것**: 드래그드롭 머지 조작 검증 완료 → **승격 판정**(2026-08-18). 그래픽
교체 지점을 `lib/game/skins/`로 분리해, 텍스트→이미지 전환이 레지스트리 한 곳
수정으로 끝나는 상태.

**멈춘 지점**: 테마 설계 초안까지 썼고 **아무것도 확정하지 않았다.**
`docs/design/theme-design.md`의 §2·§3·§4가 전부 `[제안 — 확인 필요]`다.

**다시 시작하면 할 일**:

1. §7의 열린 결정 6개를 정한다. 그중 **6번(지형이 스폰 종류를 정하는 구조)이
   가장 크다** — 채택하면 확장·지대·체인 해금이 한 메커닉으로 합쳐지고 §1의
   "생성기 1개 = 체인 1개" 전제가 깨진다. 검증 방법까지 문서에 적혀 있다.
2. 정식 앱 이름 → `docs/prd/<이름>.md` 작성.
3. 승격 절차 실행: `apps/<이름>` 생성 → `lib/domain/`·`lib/game/skins/` 이식 →
   `apps/proto_merge` 삭제 (`docs/03-architecture.md` §6).

**지우지 말 것**: `apps/proto_merge`는 이식이 끝날 때까지 남긴다. 체인 조합을
손에 쥐고 실험할 수 있는 유일한 것이다.

---

## 2. 슬립로그 — 저장 계층 직전에서 멈춤

| | |
|---|---|
| 코드 | `apps/sleep_log` |
| 문서 | `docs/prd/sleep_log.md`, `docs/screen-flow/sleep_log.md` |
| 마지막 커밋 | `e5f0a6a` (2026-09-27) |

**끝난 것**: 스캐폴딩 → 도메인 → 달력 위젯. 테스트 95개 통과.

- `lib/domain/` — 수면시간 계산(자정 넘김), z 4단계 판정, 감정 태그 팔레트,
  안전 안내 2단계 판정, 태그별 수면 집계. 순수 Dart.
- `lib/widgets/calendar/` — 월간 달력. 패키지를 쓰지 않고 직접 만들었다.
- 화면은 `calendar`만 구현. `onboarding`/`entry`/`report`/`settings`는 placeholder.

**멈춘 지점**: **`lib/data/`가 없다.** 그래서 달력이 비어 있다 —
모든 날이 "기록 없음" 점으로 그려지고, 저장·조회가 전혀 안 된다.

**다시 시작하면 할 일** (권하는 순서):

1. **`lib/data/` — drift DB + Repository.** 이 앱이 저장소에서 drift를 처음 쓴다.
   스키마는 앱 안에 두고 `core_storage`는 설정값만 (PRD §9-3 확정).
   `drift`·`drift_dev`·`build_runner` 의존 추가가 여기서 처음 필요하다.
2. 데이터가 붙으면 코드의 `TODO(sleep_log)` 3개가 풀린다:
   - `calendar_screen.dart:17` — `today`·`records`를 Provider에서 받기
   - `calendar_screen.dart:27` — "오늘 기록" CTA를 기록 없을 때만 띄우기
   - `month_calendar.dart` `monthsBack` — 임시 상한(24)을 가장 오래된 기록의 달로
3. `entry` 화면 (시각 입력 + 태그 복수 선택) → `onboarding` → `report` → `settings`
4. `router.dart:56` — `tag_palette`는 v1.x 범위이므로 v1에서는 그대로 둔다.

**남은 확인 사항** (전부 코드 상수·데이터라 구현 중 조정 가능):
초기 팔레트 15개 문구, 무료 커스텀 태그 개수(3), z 임계값(1.5/0.5시간),
안전 안내 조건 수치.

---

## 저장소 공통 메모

- **`melos run format`은 검사만 하지 않고 파일을 덮어쓴다.** `dart format
  --set-exit-if-changed .`가 파일을 재작성한 뒤 exit 1을 낸다. CI에서는 작업
  트리를 버리니 검사처럼 동작하지만, 로컬에서 돌리면 재포맷이 남는다.
  저장소는 `d51467d`에서 한 번 전체 정렬했다.
- **CI 워크플로가 없다.** `docs/03-architecture.md` §1은 CI가
  `melos run analyze && melos run test`만 돌리면 되게 유지한다고 전제하는데,
  `.github/`가 아직 없다.
- `apps/proto_merge`에는 `flutter create`가 만든 `analysis_options.yaml`이
  남아 있다. 루트 것과 내용이 같아 `apps/sleep_log`에서는 지웠다.
