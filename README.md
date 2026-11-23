# parrot_bit

IT Parrot 모바일 앱 모노레포 (Flutter + Melos + pub workspace).

- **마지막 갱신**: 2026-11-21
- **도구 버전**: Flutter 3.50.1 / Dart 3.14.0, Gradle 9.5.0 / AGP 9.3.1 / Kotlin 2.4.20 (앱 네 개 공통)
- 진행 상황과 다음 할 일은 [docs/status.md](docs/status.md)에 적는다.

## 앱

| 앱 | 설명 | 상태 (2026-11-21) |
|---|---|---|
| `apps/bloom_wave` | Bloom Wave — 물방울로 픽셀 그림을 꽃피우는 한 손 퍼즐 | Flutter 전환 완료, 2000스테이지 팩·피날레 애니메이션 반영, 출시 준비 |
| `apps/sleep_log` | 슬립로그 — 캘린더 기반 수면·감정 다이어리 | v1 기능 전부 동작, 암호화 백업·기기 이전 포함, 실기기 확인 단계 |
| `apps/deep_grove` | Deep Grove — 머지로 숲을 키우고 보드를 넓히는 머지 게임 | v0.1 + 보상형 광고·결제, 실기기 확인 전 |
| `apps/proto_idle_visit` | 방치형 캐릭터 수집 프로토타입 | 첫 동작판, 플레이 판정 대기 |

## 구조

```
apps/                # 앱 (릴리즈 앱 + proto_* 프로토타입)
packages/
├── core_ui          # 공통 위젯, 테마, 디자인 토큰
├── core_network     # API 클라이언트, 에러 처리
├── core_storage     # 로컬 저장소 추상화
├── core_analytics   # 로깅/분석 추상화
└── core_utils       # 순수 Dart 유틸
docs/
├── prd/             # 앱별 기획서
├── screen-flow/     # 앱별 화면 흐름
├── design/          # 설계 메모 (테마, 경제 시뮬레이션 등)
└── status.md        # 작업 이력 — 어디서 멈췄고 다음 한 걸음이 무엇인지
```

자세한 구조/규칙은 [docs/03-architecture.md](docs/03-architecture.md), 패키지별 경계는 [docs/04-package-boundaries.md](docs/04-package-boundaries.md) 참고.

## 시작하기

사전 조건: PATH에 Flutter SDK(`H:\ITParrot\flutter_sdk\flutter\bin`)와
pub 전역 실행 파일 경로(`%LOCALAPPDATA%\Pub\Cache\bin`, melos용)가 있어야 한다.
melos는 `dart pub global activate melos`로 전역 활성화되어 있다.

```sh
flutter pub get     # 워크스페이스 전체 의존성 해석 (bootstrap)
melos run analyze   # 전체 정적 분석
melos run test      # 전체 테스트 (dart + flutter 패키지)
melos run format    # 포맷 검사
```

앱 하나만 테스트하거나 빌드할 때는 해당 앱 디렉터리에서 실행한다.

```sh
cd apps/bloom_wave
flutter test
flutter build apk --debug
```

## Android 빌드 메모 (2026-11-21)

- Flutter 3.50.1은 Gradle 9.3.1 이상, AGP 9.1.1 이상을 요구한다. 앱 네 개 모두
  템플릿 기본값(Gradle 9.5.0 / AGP 9.3.1 / Kotlin 2.4.20)으로 맞춰 두었다. Flutter를 올리면
  `flutter_tools/lib/src/android/gradle_utils.dart`의 `template*` 상수를 확인해 같이 올린다.
- 각 앱 `android/gradle.properties`에 `kotlin.incremental=false`가 들어 있다. Windows에서 pub 캐시(C:)와
  프로젝트(H:)의 드라이브가 달라 Kotlin 2.4 증분 캐시가 "different roots"로 실패하기 때문이다.
- `flutter build apk`는 한 번에 한 앱씩 돌린다. 동시에 돌리면 SDK 안의 Gradle 플러그인 컴파일 캐시를
  서로 덮어써 실패한다.
