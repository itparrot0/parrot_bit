# Deep Grove

머지로 숲을 키우고, 다 키운 조각이 낸 자원으로 보드를 넓히고, 땅 아래 동굴로 파고드는 머지 게임.
`apps/proto_merge`(2026-08-18 승격)의 검증된 코드를 이식해 시작했다.

- 기획: [`docs/prd/deep_grove.md`](../../docs/prd/deep_grove.md)
- 게임 규칙·컨텐츠: [`docs/design/deep_grove-themes.md`](../../docs/design/deep_grove-themes.md)
- 화면 흐름: [`docs/screen-flow/deep_grove.md`](../../docs/screen-flow/deep_grove.md)

```
lib/
├── domain/    순수 Dart 규칙: 보드(머지·스폰·산출·확장) · 테마 데이터 · 저장 형식   ← Flame 없이 테스트
├── economy/   창고·확장 진행 (아웃게임, 순수 Dart) + Riverpod 연결
├── game/      Flame 보드 · 조각 컴포넌트 · skins/(그래픽 교체 지점)
├── save/      core_storage 에 JSON 스냅샷
├── screens/   보드(홈) · 상점 · 설정 + 보드 위 시트
└── app.dart, main.dart
```

**숫자는 전부 `lib/domain/theme.dart`** (확장 비용·창고 용량·산출 속도·생성기 확률표·지대 보너스).

```sh
flutter pub get        # 저장소 루트에서 1회
cd apps/deep_grove
flutter test
flutter run -d chrome  # 브라우저 플레이 테스트
```
