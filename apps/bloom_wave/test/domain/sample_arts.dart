// 테스트용 픽셀 아트 (TS 버전 packages/core/src/arts.ts 와 같다 — ts_reference.json 이 이 그림들로 만들어졌다)
import 'package:bloom_wave/domain/generator.dart';

const sampleArts = [
  PixelArt(
    'tulip',
    ['r=#E5484D', 'g=#46A758', 'y=#F5D90A'],
    [
      '..r.r.r..',
      '..rrrrr..',
      '..ryrrr..',
      '..rrrrr..',
      '...rrr...',
      '....g....',
      '.g..g..g.',
      '..g.g.g..',
      '...ggg...',
    ],
  ),
  PixelArt(
    'mushroom',
    ['r=#E5484D', 'w=#FFFFFF', 'b=#8D6E63'],
    [
      '...rrrr...',
      '..rrwwrr..',
      '.rwwrrrwr.',
      'rrrrrrrrrr',
      'rwrrrwwrrr',
      'rrrrrrrrrr',
      '...bbbb...',
      '...bwbb...',
      '...bbbb...',
      '..bbbbbb..',
    ],
  ),
  PixelArt(
    'sunflower',
    ['y=#F5D90A', 'o=#F76B15', 'b=#6D4C41', 'g=#46A758'],
    [
      '...y.y.y...',
      '..yyyyyyy..',
      '.yyoobooyy.',
      'yyobbbbboyy',
      '.yobbbbboy.',
      'yyobbbbboyy',
      '.yyoobooyy.',
      '..yyyyyyy..',
      '...y.g.y...',
      '.gg..g..gg.',
      '..ggggggg..',
      '.....g.....',
    ],
  ),
];
