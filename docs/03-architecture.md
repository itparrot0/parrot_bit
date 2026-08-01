# 아키텍처 문서

> 저장소 전체에 적용되는 구조 결정을 기록한다. 앱별 예외는 해당 앱 README에 적는다.
> 각 결정에는 상태를 표기한다: **[확정]** / **[제안 — 확인 필요]**

## 1. 모노레포 구조 **[확정]**

```
parrot_bit/                      # 저장소 루트
├── pubspec.yaml                 # 루트: pub workspace + melos 설정
├── melos.yaml                   # (melos 6 이하 사용 시) — 7+는 pubspec.yaml에 통합
├── analysis_options.yaml        # 루트 공통 린트 — 모든 패키지가 include
├── docs/                        # 본 문서들
├── apps/
│   ├── proto_*/                 # 프로토타입 앱 (§6 참고) — 릴리즈 CI 제외
│   └── <app_name>/              # 릴리즈 앱 (게임 / 유틸)
└── packages/
    ├── core_ui/                 # 공통 위젯, 테마, 디자인 토큰
    ├── core_network/            # API 클라이언트, 에러 처리
    ├── core_storage/            # 로컬 저장소 추상화
    ├── core_analytics/          # 로깅/분석 추상화
    ├── core_utils/              # 순수 Dart 유틸
    └── core_game/               # (게임 2개째부터) Flame 공통 컴포넌트 — §5 참고
```

- 툴링: **melos + pub workspaces** (Dart 3.6+ 네이티브 워크스페이스, melos 7 기준 `pubspec.yaml`의 `melos:` 섹션에 설정).
- 루트 `pubspec.yaml`의 `workspace:`에 모든 앱/패키지를 나열하고, 각 패키지는 `resolution: workspace`를 선언한다 → 저장소 전체가 단일 버전 해석을 공유해 의존성 충돌을 조기에 발견한다.
- 공통 melos 스크립트: `bootstrap`(= `melos bootstrap`), `analyze`, `test`, `format`. CI는 `melos run analyze && melos run test`만 실행하면 되게 유지한다.

## 2. 패키지 분리 기준 **[확정]**

새 패키지를 만드는 조건 — 셋 다 만족해야 한다:

1. **2개 이상의 앱에서 실제로 사용**되거나, 사용이 확정된 코드다 (Rule of Two). 첫 앱 개발 중에는 앱 내부 `lib/` 안에 두고, 두 번째 사용처가 생길 때 추출한다. 예외: `core_*` 5종은 뼈대이므로 선제 생성한다.
2. **독립적으로 테스트 가능**하다 — 앱을 띄우지 않고 `flutter test` / `dart test`가 돈다.
3. **한 문장으로 책임을 말할 수 있다.** 두 문장이 필요하면 패키지 2개다.

패키지별 상세 경계는 `docs/04-package-boundaries.md`에서 정의한다.

## 3. 상태관리 및 주요 기술 선택

| 영역 | 선택 | 상태 |
|------|------|------|
| 상태관리 | **Riverpod** (flutter_riverpod) | [확정] |
| 라우팅 | go_router | [확정] |
| 게임 엔진 | Flame | [확정] |
| 네트워크 | dio (core_network 내부에 캡슐화) | [확정] |
| 로컬 저장소 | shared_preferences → 필요 시 drift (core_storage 내부에 캡슐화) | [확정] |
| 모델/직렬화 | freezed + json_serializable | [확정] |
| 린트 | flutter_lints 기반 루트 공통 analysis_options | [확정] |

**Riverpod 제안 근거**: 앱이 여러 개인 모노레포에서는 Provider 정의를 패키지에 두고 앱에서 override하는 패턴(예: `core_analytics`의 구현체 주입)이 자연스럽고, 게임/유틸 양쪽에서 같은 방식을 쓸 수 있다. Bloc 선호 시 이 행만 바꾸면 되고 나머지 구조는 동일하다.

**게임 앱에서의 상태 분리 규칙 [확정]**:
- **인게임 상태**(엔티티 위치, 점수 계산 중인 값, 물리)는 Flame 컴포넌트/`FlameGame` 내부에 둔다. Riverpod로 프레임 단위 상태를 옮기지 않는다.
- **아웃게임 상태**(설정, 최고점수, 재화, 화면 라우팅)는 Riverpod가 담당한다.
- 두 세계의 접점은 명시적 브리지 하나로 제한한다: 게임 시작 시 설정을 주입받고, 게임 종료 시 결과를 콜백/이벤트로 내보낸다. Flame 컴포넌트가 Provider를 직접 읽지 않는다.

## 4. 데이터 흐름 **[확정]**

```
UI (Widget / Flame HUD)
  ↓ 이벤트                    ↑ 상태 구독
Controller (Riverpod Notifier)
  ↓ 호출                      ↑ 도메인 모델
Repository (앱 내부 lib/ — 앱별 도메인 로직)
  ↓                           ↑
core_network / core_storage   (패키지 — 순수 I/O, 도메인을 모름)
```

- **도메인 로직(Repository)은 앱에 둔다.** `core_*` 패키지는 도메인을 모르는 인프라 계층이다. "유저 프로필 저장"은 앱의 Repository, "key-value 저장"은 `core_storage`.
- 에러는 `core_network`/`core_storage`가 자체 예외 타입으로 정규화해서 던지고, Repository가 도메인 결과로 변환한다. UI 계층에서 dio 예외를 직접 잡지 않는다.
- 분석 이벤트는 Controller 계층에서만 발행한다 (`core_analytics` 인터페이스 경유). 위젯에서 직접 로깅하지 않는다.

## 5. 의존 방향 규칙 **[확정]**

```
apps/* ──→ packages/*        (허용)
packages/* ──→ apps/*        (금지)
core_* ──→ core_utils        (허용 — 유일한 패키지 간 의존)
core_* ──→ 다른 core_*       (그 외 전부 금지)
core_game ──→ core_utils     (허용; Flame 의존은 core_game과 게임 앱만)
```

- `core_ui`가 `core_network`를 알게 되는 순간 경계가 무너진다. 패키지 간 조합이 필요하면 **앱에서 조합**한다.
- Flame 의존성은 게임 앱과 `core_game`에만 존재한다. 유틸 앱 빌드에 Flame이 섞이면 안 된다.

## 6. 프로토타입 전략 **[확정 제안]**

**하이브리드: 불확실성의 종류에 따라 나눈다.**

| | 게임 앱 | 유틸 앱 |
|---|---|---|
| 핵심 불확실성 | "재미있는가?" (무엇을 만들지) | "잘 만들었는가?" (어떻게 만들지) |
| 방식 | **별도 프로토타입 앱** `apps/proto_<이름>` | **앱 내부에서 단계로 진행** (v0.x → v1) |
| 코드 운명 | 기본값은 폐기, 승격 시 새 앱으로 이식 | 그대로 릴리즈 코드로 성장 |

**게임 — `apps/proto_*` 규칙**:
- 프로토타입은 `core_*` 패키지에 의존해도 된다(빠른 출발). 역방향은 금지.
- 릴리즈 CI/배포 파이프라인에서 제외한다: melos 필터 `--ignore="proto_*"`.
- 린트/테스트 기준을 완화해도 된다. 단, 패키지 코드는 건드리지 않는다 — 프로토타입에서 패키지 수정이 필요해지면 앱 로컬에 복사해서 실험한다.
- PRD의 "검증 가설" 섹션(가설·판정 기준·타임박스)을 반드시 채운다. **폐기는 실패가 아니라 정상 종료다.**
- **승격 절차**: 프로토타입을 rename하지 않는다. `apps/<정식이름>`을 새로 만들고(정식 bundle id, 아이콘, 파이어베이스 설정, 린트 풀 적용), 검증된 코드만 의도적으로 이식한 뒤 `proto_*`를 삭제한다.

**유틸 — 앱 내부 단계 규칙**:
- 처음부터 `apps/<정식이름>`으로 시작하되 v0.x 동안 기능을 최소로 유지한다. 실험적 기능은 feature flag 또는 별도 브랜치로 관리한다.
- 예외: 유틸 앱이라도 핵심 컨셉 자체가 불확실하면(예: 새로운 입력 방식) 게임과 같은 `proto_*` 방식을 쓴다. 기준은 앱 종류가 아니라 **불확실성이 '무엇'에 있는가**다.

## 7. 네이밍 / 버저닝 **[확정]**

- 앱: `snake_case`, 프로토타입은 `proto_` 접두사. 패키지: `core_` 접두사(인프라), 향후 특정 도메인 공유 시 `feature_` 접두사.
- 패키지는 `publish_to: none`, 버전은 워크스페이스 단일 해석에 맡기고 앱만 `version: x.y.z+n`을 관리한다.

## 8. 마이그레이션 메모 (완료 — 2026-07-30)

1. ~~루트의 `flutter create` 앱 잔재 폐기, 루트를 워크스페이스 전용으로 전환~~ ✔
2. ~~`packages/core_*` 5종 스캐폴딩 + bootstrap (melos 7.8.2, analyze/test 통과)~~ ✔
3. 첫 앱(또는 첫 `proto_*`) 생성 — **다음 단계**. `flutter create`로 `apps/` 아래에 생성 후 루트 `pubspec.yaml`의 `workspace:` 목록에 추가하고, 앱 pubspec에 `resolution: workspace`를 선언한다.
