import type { Options } from "@bloom-wave/core/engine";

export type Band = "tutorial" | "intro" | "mid" | "hard";

export type LevelSpec = {
  art: string; // art/<art>.png
  variant?: number; // 같은 그림의 두 번째 레벨이면 2 (id: <art>-2)
  band: Band;
  role?: "breather" | "boss";
  tutorial?: string; // 앱이 보여 줄 튜토리얼 안내 키
  seeds: number[]; // 시드 여러 개를 돌려 목표에 가장 가까운 결과를 고른다
  starts: number;
  lanes: number; // 대기열 줄 수 (3 이상)
  scale?: number; // 그림 해상도 배율 (2 = 한 픽셀이 2×2 칸)
  dropMin: number;
  dropMax: number;
  targetWinRate: number;
  winRange: [number, number]; // 이 구간 안의 결과를 우선 고른다
  displacements?: number;
  options?: Partial<Options>;
};

export type PackConfig = {
  pack: string;
  copyTo?: string[]; // 설정 파일 기준 상대 경로. 앱이 읽는 위치로 복사
  defaults: { slotCount: number; options: Options; displacements: number; maxSolverNodes: number; maxColors: number; maxSize: number };
  levels: LevelSpec[];
};
