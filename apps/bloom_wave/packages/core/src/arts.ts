// 테스트/데모용 픽셀 아트. 실제 레벨은 디자이너가 만든 PNG를 같은 형식으로 변환해 쓴다.
import type { PixelArt } from "./generator.ts";

export const ARTS: PixelArt[] = [
  {
    name: "tulip",
    palette: ["r=#E5484D", "g=#46A758", "y=#F5D90A"],
    rows: [
      "..r.r.r..",
      "..rrrrr..",
      "..ryrrr..",
      "..rrrrr..",
      "...rrr...",
      "....g....",
      ".g..g..g.",
      "..g.g.g..",
      "...ggg...",
    ],
  },
  {
    name: "mushroom",
    palette: ["r=#E5484D", "w=#FFFFFF", "b=#8D6E63"],
    rows: [
      "...rrrr...",
      "..rrwwrr..",
      ".rwwrrrwr.",
      "rrrrrrrrrr",
      "rwrrrwwrrr",
      "rrrrrrrrrr",
      "...bbbb...",
      "...bwbb...",
      "...bbbb...",
      "..bbbbbb..",
    ],
  },
  {
    name: "sunflower",
    palette: ["y=#F5D90A", "o=#F76B15", "b=#6D4C41", "g=#46A758"],
    rows: [
      "...y.y.y...",
      "..yyyyyyy..",
      ".yyoobooyy.",
      "yyobbbbboyy",
      ".yobbbbboy.",
      "yyobbbbboyy",
      ".yyoobooyy.",
      "..yyyyyyy..",
      "...y.g.y...",
      ".gg..g..gg.",
      "..ggggggg..",
      ".....g.....",
    ],
  },
];
