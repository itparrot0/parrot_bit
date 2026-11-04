// 회귀 테스트: 수동 틱 모드(?manualTick=1)에서 레벨 1~5를 솔버 해법(deploy/tick 수순)대로 자동 플레이해 클리어 화면 확인
import { test, expect, type Page } from "@playwright/test";

async function boot(page: Page) {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(String(e)));
  await page.goto("/?manualTick=1");
  await page.waitForFunction(() => !!(window as any).__bloom);
  return errors;
}

for (let n = 1; n <= 5; n++) {
  test(`레벨 ${n}: 솔버 해법대로 두면 클리어 화면이 나온다`, async ({ page }) => {
    const errors = await boot(page);
    const result = await page.evaluate((n) => {
      const B = (window as any).__bloom;
      const g = B.open(n);
      const c = g.controller;
      c.resume(); // 튜토리얼 안내를 닫은 상태로
      const sol = B.solve(g.level, c.options);
      if (!sol.solvable) return { status: "unsolvable" };
      for (const a of sol.solution) {
        if (a.type === "deploy") {
          if (!c.tapFront().ok) return { status: "tap-refused" };
          if (!c.options.realtime) while (c.step());
        } else c.step();
      }
      return { status: c.status, stars: c.stars() };
    }, n);
    expect(result.status).toBe("cleared");
    await page.waitForFunction(() => {
      const ctx = (window as any).__bloom.ctx;
      return !!ctx.current.view.getChildByLabel("overlay-clear", true);
    }, null, { timeout: 5000 });
    await page.screenshot({ path: `test-results/level-${n}-clear.png` });
    expect(errors).toEqual([]);
  });
}

test("탭 입력: 대기열을 탭하면 물방울이 슬롯으로 간다 (실제 포인터)", async ({ page }) => {
  const errors = await boot(page);
  await page.evaluate(() => { const g = (window as any).__bloom.open(6); g.controller.resume(); });
  const before = await page.evaluate(() => (window as any).__bloom.game().controller.state.queue.length);
  // 대기열 맨 앞(논리 좌표 160, 대기열 y)을 화면 좌표로 바꿔 탭
  const pt = await page.evaluate(() => {
    const B = (window as any).__bloom;
    const front = B.game().view.getChildByLabel("queue-front", true);
    const p = front.getGlobalPosition();
    return { x: p.x, y: p.y };
  });
  await page.mouse.click(pt.x, pt.y);
  const after = await page.evaluate(() => (window as any).__bloom.game().controller.state.queue.length);
  expect(after).toBe(before - 1);
  await page.screenshot({ path: "test-results/game-tap.png" });
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
  expect(errors).toEqual([]);
});
