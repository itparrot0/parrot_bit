// 회귀 테스트: 수동 틱 모드(?manualTick=1)에서 레벨을 솔버 해법(deploy(lane)/tick 수순)대로 자동 플레이해 완성 화면 확인.
// ?noAds=1 이면 웹 가짜 광고가 바로 닫힌다.
import { test, expect, type Page } from "@playwright/test";

async function boot(page: Page, query = "?manualTick=1&noAds=1") {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(String(e)));
  await page.goto("/" + query);
  await page.waitForFunction(() => !!(window as any).__bloom);
  return errors;
}

/** 레벨을 열고 시작 안내(난이도 경고·튜토리얼)를 버튼으로 모두 닫는다 */
async function openLevel(page: Page, n: number) {
  await page.evaluate((n) => {
    const B = (window as any).__bloom;
    B.open(n);
    for (let k = 0; k < 6; k++) {
      const v = B.game().view;
      const btn = v.getChildByLabel("btn-difficulty-ok", true) ?? v.getChildByLabel("btn-tutorial-ok", true);
      if (!btn) break;
      btn.onTap();
    }
  }, n);
}

async function solveAndPlay(page: Page) {
  return page.evaluate(() => {
    const B = (window as any).__bloom;
    const g = B.game();
    const c = g.controller;
    const sol = B.solve(g.level, c.options);
    if (!sol.solvable) return { status: "unsolvable" };
    for (const a of sol.solution) {
      if (a.type === "deploy") {
        if (!c.tap(a.lane).ok) return { status: "tap-refused" };
        if (!c.options.realtime) while (c.step());
      } else c.step();
    }
    return { status: c.status, hasStars: "stars" in c };
  });
}

const hasLabel = (page: Page, l: string) =>
  page.evaluate((l) => !!(window as any).__bloom.ctx.root.getChildByLabel(l, true), l);

for (let n = 1; n <= 5; n++) {
  test(`레벨 ${n}: 솔버 해법대로 두면 완성 화면 (별점 없음)`, async ({ page }) => {
    const errors = await boot(page);
    await openLevel(page, n);
    const result = await solveAndPlay(page);
    expect(result).toEqual({ status: "cleared", hasStars: false });
    await page.waitForFunction(() => !!(window as any).__bloom.ctx.current.view.getChildByLabel("overlay-clear", true), null, { timeout: 8000 });
    expect(await hasLabel(page, "full-bloom")).toBe(true);
    await page.waitForTimeout(700);
    await page.screenshot({ path: `test-results/level-${n}-clear.png` });
    expect(errors).toEqual([]);
  });
}

test("완성 후 다음 스테이지: 광고(웹 가짜)가 뜨고 닫으면 다음 레벨, 실패 시 광고 없음", async ({ page }) => {
  const errors = await boot(page, "?manualTick=1");
  await openLevel(page, 6);
  expect((await solveAndPlay(page)).status).toBe("cleared");
  await page.waitForFunction(() => !!(window as any).__bloom.ctx.current.view.getChildByLabel("btn-next", true), null, { timeout: 8000 });
  await page.evaluate(() => { (window as any).__bloom.game().view.getChildByLabel("btn-next", true).onTap(); });
  await page.waitForTimeout(200);
  expect(await hasLabel(page, "overlay-ad")).toBe(true);
  await page.screenshot({ path: "test-results/ad-mock.png" });
  await page.waitForTimeout(1100); // 닫기 버튼은 1초 뒤 활성
  await page.evaluate(() => { (window as any).__bloom.ctx.root.getChildByLabel("btn-ad-close", true).onTap(); });
  await page.waitForTimeout(100);
  expect(await hasLabel(page, "overlay-ad")).toBe(false);
  expect(await page.evaluate(() => (window as any).__bloom.game().levelNo)).toBe(7);

  // 광고 제거 구매자는 광고 없이 바로 다음 레벨
  await page.evaluate(() => { (window as any).__bloom.ctx.save.data.noAds = true; });
  await openLevel(page, 7);
  expect((await solveAndPlay(page)).status).toBe("cleared");
  await page.waitForFunction(() => !!(window as any).__bloom.ctx.current.view.getChildByLabel("btn-next", true), null, { timeout: 8000 });
  await page.evaluate(() => { (window as any).__bloom.game().view.getChildByLabel("btn-next", true).onTap(); });
  await page.waitForTimeout(200);
  expect(await hasLabel(page, "overlay-ad")).toBe(false);
  expect(await page.evaluate(() => (window as any).__bloom.game().levelNo)).toBe(8);

  // 실패: 광고 없음
  await page.evaluate(() => { (window as any).__bloom.ctx.save.data.noAds = false; });
  await openLevel(page, 8);
  await page.evaluate(() => {
    const c = (window as any).__bloom.game().controller;
    let guard = 0;
    // 쓸 수 없는 물방울만 골라 넣어 슬롯을 막는다 (없으면 아무거나)
    while (c.status === "playing" && guard++ < 500) {
      const lanes = c.state.lanes.map((_: unknown, i: number) => i).filter((i: number) => c.canTap(i));
      const bad = lanes.find((i: number) => !c.usable(i));
      if (bad !== undefined) c.tap(bad); else if (!c.step() && lanes.length) c.tap(lanes[0]); else if (!lanes.length && !c.step()) break;
    }
  });
  const st = await page.evaluate(() => (window as any).__bloom.game().controller.status);
  if (st === "failed") {
    await page.waitForFunction(() => !!(window as any).__bloom.ctx.current.view.getChildByLabel("overlay-fail", true), null, { timeout: 5000 });
    await page.evaluate(() => (window as any).__bloom.game().view.getChildByLabel("btn-retry", true).onTap());
    await page.waitForTimeout(200);
    expect(await hasLabel(page, "overlay-ad")).toBe(false);
  }
  expect(errors).toEqual([]);
});

for (const [n, d] of [[41, "hard"], [81, "superHard"], [89, "megaHard"]] as const) {
  test(`레벨 ${n}: 시작 전 ${d} 경고창`, async ({ page }) => {
    const errors = await boot(page);
    await page.evaluate((n) => (window as any).__bloom.open(n), n);
    await page.waitForTimeout(500);
    expect(await hasLabel(page, `overlay-difficulty-${d}`)).toBe(true);
    expect(await page.evaluate(() => (window as any).__bloom.game().controller.paused)).toBe(true);
    await page.screenshot({ path: `test-results/difficulty-${d}.png` });
    await page.evaluate(() => (window as any).__bloom.game().view.getChildByLabel("btn-difficulty-ok", true).onTap());
    expect(await hasLabel(page, `overlay-difficulty-${d}`)).toBe(false);
    expect(await page.evaluate(() => (window as any).__bloom.game().controller.paused)).toBe(false);
    await page.screenshot({ path: `test-results/game-${d}.png` });
    expect(errors).toEqual([]);
  });
}

/** 줄 n 의 맨 앞 물방울을 실제 포인터로 탭 */
async function clickLane(page: Page, lane: number) {
  const pt = await page.evaluate((lane) => {
    const front = (window as any).__bloom.game().view.getChildByLabel(`lane-front-${lane}`, true);
    const p = front.getGlobalPosition();
    return { x: p.x, y: p.y };
  }, lane);
  await page.mouse.click(pt.x, pt.y);
}

test("탭 입력: 줄을 탭하면 그 줄의 맨 앞이 슬롯으로 간다 (실제 포인터, 오래 플레이해도 영역 유지)", async ({ page }) => {
  // 실시간 틱으로 진행 (피드백 #5: 플레이 중 탭 영역이 밀리는 문제 회귀 확인)
  const errors = await boot(page, "?noAds=1");
  await openLevel(page, 6);
  const q = () => page.evaluate(() => (window as any).__bloom.game().controller.state.lanes.map((l: unknown[]) => l.length));
  const lanes = (await q()).length;
  expect(lanes).toBeGreaterThanOrEqual(3);
  await page.screenshot({ path: "test-results/game-layout.png" });
  let taps = 0;
  for (let round = 0; round < 3; round++) {
    for (let k = 0; k < 12; k++) {
      const before = await q();
      const st = await page.evaluate(() => { const c = (window as any).__bloom.game().controller; return { status: c.status, can: c.state.lanes.map((_: unknown, i: number) => c.canTap(i)) }; });
      if (st.status !== "playing") break;
      const lane = st.can.findIndex(Boolean);
      if (lane < 0) { await page.waitForTimeout(350); continue; }
      await clickLane(page, lane);
      const after = await q();
      expect(after[lane]).toBe(before[lane] - 1);
      taps++;
      await page.waitForTimeout(120);
    }
    // 재시작 버튼 없이 이어서 다른 상황도 (재시작 후에도 동일하게 동작)
    await page.evaluate(() => (window as any).__bloom.game().restart());
    await page.waitForTimeout(100);
  }
  expect(taps).toBeGreaterThan(6);
  expect(errors).toEqual([]);
});

test("레이아웃: 보드·슬롯·대기열·버튼이 서로 겹치지 않는다", async ({ page }) => {
  const errors = await boot(page);
  for (const n of [1, 41, 81, 89, 120]) {
    await openLevel(page, n);
    const r = await page.evaluate(() => {
      const g = (window as any).__bloom.game();
      const b = (l: string) => { const o = g.view.getChildByLabel(l, true); const r = o.getBounds(); return { top: r.y, bottom: r.y + r.height, left: r.x, right: r.x + r.width }; };
      const boardB = g.board.getBounds();
      return { board: { top: boardB.y, bottom: boardB.y + boardB.height, left: boardB.x, right: boardB.x + boardB.width }, slot: b("slot-bg-0"), lane: b("lane-hit-0"), undo: b("btn-hint"), w: window.innerWidth };
    });
    expect(r.board.bottom).toBeLessThanOrEqual(r.slot.top);
    expect(r.slot.bottom).toBeLessThanOrEqual(r.lane.top);
    expect(r.lane.bottom).toBeLessThanOrEqual(r.undo.top);
    expect(r.board.left).toBeGreaterThanOrEqual(0);
    expect(r.board.right).toBeLessThanOrEqual(r.w);
    await page.screenshot({ path: `test-results/layout-${n}.png` });
  }
  expect(errors).toEqual([]);
});

test("물방울을 누르고 있으면 보드에 그 색 미리보기, 동그라미 밖으로 빼면 선택 취소", async ({ page }) => {
  const errors = await boot(page);
  await openLevel(page, 9);
  const front = await page.evaluate(() => {
    const g = (window as any).__bloom.game();
    const p = g.view.getChildByLabel("lane-front-0", true).getGlobalPosition();
    return { x: p.x, y: p.y, color: g.controller.front(0).color, len: g.controller.state.lanes[0].length };
  });
  const state = () => page.evaluate(() => { const g = (window as any).__bloom.game(); return { preview: g.board.previewColor, len: g.controller.state.lanes[0].length }; });
  // 누르고 있는 동안: 미리보기
  await page.mouse.move(front.x, front.y);
  await page.mouse.down();
  await page.waitForTimeout(100);
  expect(await state()).toEqual({ preview: front.color, len: front.len });
  await page.screenshot({ path: "test-results/hold-preview.png" });
  // 동그라미 안에서 조금 움직여도 유지
  await page.mouse.move(front.x + 15, front.y + 10);
  expect((await state()).preview).toBe(front.color);
  // 밖으로 벗어나면 취소, 떼어도 탭되지 않음
  await page.mouse.move(front.x, front.y - 250, { steps: 5 });
  expect((await state()).preview).toBeNull();
  await page.mouse.up();
  expect(await state()).toEqual({ preview: null, len: front.len });
  // 다시 누르고 안에서 떼면 탭
  await page.mouse.move(front.x, front.y);
  await page.mouse.down();
  await page.mouse.up();
  expect(await state()).toEqual({ preview: null, len: front.len - 1 });
  expect(errors).toEqual([]);
});

test("도움말: 1스테이지는 길게 누르기 안내, 비슷한 색이 처음 나오는 스테이지는 비슷한 색 안내", async ({ page }) => {
  const errors = await boot(page);
  const seen = async (n: number) => page.evaluate((n) => {
    const B = (window as any).__bloom;
    B.open(n);
    const keys: string[] = [];
    for (let k = 0; k < 6; k++) {
      const v = B.game().view;
      const box = v.getChildByLabel("overlay-tutorial", true);
      const btn = v.getChildByLabel("btn-difficulty-ok", true) ?? v.getChildByLabel("btn-tutorial-ok", true);
      if (!btn) break;
      if (box) keys.push(box.children[1].label);
      btn.onTap();
    }
    return keys;
  }, n);
  expect(await seen(1)).toEqual(["tutorial-wave", "tutorial-hold"]);
  await page.evaluate(() => (window as any).__bloom.open(9));
  await page.waitForTimeout(400);
  await page.screenshot({ path: "test-results/tutorial-similar.png" });
  expect(await seen(9)).toEqual(["tutorial-similar"]);
  expect(await seen(10)).toEqual([]);
  expect(errors).toEqual([]);
});

test("완성 화면에는 다음 스테이지 버튼만 있다 (다시 하기·맵 없음)", async ({ page }) => {
  const errors = await boot(page);
  await openLevel(page, 2);
  expect((await solveAndPlay(page)).status).toBe("cleared");
  await page.waitForFunction(() => !!(window as any).__bloom.ctx.current.view.getChildByLabel("btn-next", true), null, { timeout: 8000 });
  const labels = await page.evaluate(() => {
    const o = (window as any).__bloom.game().view.getChildByLabel("overlay-clear", true);
    const out: string[] = [];
    const walk = (c: any) => { if (c.label?.startsWith("btn-")) out.push(c.label); c.children?.forEach(walk); };
    walk(o);
    return out;
  });
  expect(labels).toEqual(["btn-next"]);
  await page.waitForTimeout(600);
  await page.screenshot({ path: "test-results/clear-next-only.png" });
  expect(errors).toEqual([]);
});

test("메뉴 화면 스크린샷: 타이틀, 맵, 정원, 설정", async ({ page }) => {
  const errors = await boot(page);
  await page.waitForTimeout(300);
  await page.screenshot({ path: "test-results/title.png" });
  for (const [btn, name] of [["btn-stages", "map"], ["btn-garden", "garden"], ["btn-settings", "settings"]]) {
    await page.evaluate((btn) => {
      const ctx = (window as any).__bloom.ctx;
      while (ctx.pop());
      ctx.current.view.getChildByLabel(btn, true).onTap();
    }, btn);
    await page.waitForTimeout(300);
    await page.screenshot({ path: `test-results/${name}.png` });
  }
  // 설정: 광고 제거 구매(개발용 결제) → 저장에 반영
  await page.evaluate(() => (window as any).__bloom.ctx.current.view.getChildByLabel("btn-remove-ads", true).onTap());
  await page.waitForFunction(() => (window as any).__bloom.ctx.save.data.noAds === true);
  await page.waitForTimeout(300);
  await page.screenshot({ path: "test-results/settings-noads.png" });
  expect(errors).toEqual([]);
});
