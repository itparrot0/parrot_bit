# levelgen — 픽셀 아트 PNG → 클리어 보장 레벨 팩

순수 Dart CLI. 규칙 엔진·솔버·생성기는 앱과 같은 `lib/domain/` 코드를 쓴다 (Flutter import 없음).
모든 명령은 `apps/bloom_wave` 에서 실행한다.

```sh
dart run tool/levelgen/levelgen.dart build tool/levelgen/levels.config.json   # 1000 스테이지 생성 (4코어 약 4분)
dart run tool/levelgen/levelgen.dart build tool/levelgen/levels.config.json --threads 1 --limit 10   # 일부만 빠르게
dart run tool/levelgen/levelgen.dart verify tool/levelgen/out/pack-01.json    # 팩 재검증 (실패 시 종료 코드 1)
dart run tool/levelgen/levelgen.dart art      # src/art_source.dart 텍스트 아트 → art/*.png, art/names.json
dart run tool/levelgen/levelgen.dart config   # levels.config.json 다시 만들기 (src/make_config.dart)
dart run tool/levelgen/levelgen.dart icons <outDir>   # 앱 아이콘 원본 PNG (1024px, splash 2732px)
flutter test test/levelgen
```

- `build` 결과: `out/pack-01.json`(한 줄에 레벨 하나), `out/report.csv`(난이도 지표), `out/previews/*.png`(시작 상태 미리보기, git 제외).
  `--limit` 없이 돌리면 `copyTo`(설정 파일 기준 경로)인 `assets/levels/pack-01.json` 으로 복사된다.
- isolate 로 병렬 생성하지만 결과는 스레드 수와 무관하게 바이트 단위로 같다. 같은 설정·그림이면 언제나 같은 팩이 나온다.
- 종료 코드: 성공 0, `verify` 실패 1, 잘못된 사용법 2.

## 그림(art)
- 레벨 그림은 `art/<이름>.png` (1픽셀 = 1칸, 알파 < 128 은 빈 칸, 16×16 이하 권장). 이름은 `levels.config.json` 의 `art` 값.
- 색이 `maxColors`(6)를 넘으면 가장 가까운 두 색을 칸 수가 적은 쪽 → 많은 쪽으로 합친다 (경고 출력). 3칸 미만인 색도 경고.
- 표시 이름(ko/en)은 `art/names.json`. 지금 PNG 는 `src/art_source.dart` 의 텍스트 아트로 만든 플레이스홀더라,
  디자이너 PNG 가 오면 같은 이름으로 덮어쓰고 `build` 만 다시 돌리면 된다 (`art` 명령은 PNG 를 덮어쓰니 주의).

## verify 가 확인하는 것
1. 칸 배열 길이 = 너비×높이, 물방울 총량 = 칠할 칸 수, 물방울 색·양이 올바름
2. 대기열이 3줄 이상이고 빈 줄이 없음
3. 8방향으로 이어진 덩어리마다 시작 발아 지점이 있음
4. 솔버(노드 한도 200,000)가 클리어 수순을 찾고, 그 수순을 재생하면 실제로 클리어됨
5. 레벨 id 중복 없음
