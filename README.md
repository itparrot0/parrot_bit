# parrot_bit

IT Parrot 모바일 앱 모노레포 (Flutter + Melos + pub workspace).

> **예외: `apps/bloom_wave`는 TypeScript(Vite + PixiJS + Capacitor) 앱이다.**
> pub workspace·melos에 들어가지 않으며, 빌드·테스트는 그 폴더의
> `npm install && npm test`로 따로 돌린다 ([apps/bloom_wave/README.md](apps/bloom_wave/README.md)).

## 구조

```
apps/                # 앱 (릴리즈 앱 + proto_* 프로토타입, bloom_wave는 TypeScript)
packages/
├── core_ui          # 공통 위젯, 테마, 디자인 토큰
├── core_network     # API 클라이언트, 에러 처리
├── core_storage     # 로컬 저장소 추상화
├── core_analytics   # 로깅/분석 추상화
└── core_utils       # 순수 Dart 유틸
docs/                # PRD·화면흐름·아키텍처·패키지 경계 문서
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
