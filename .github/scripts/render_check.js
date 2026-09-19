// Post-deploy render check: does the app actually draw anything?
//
// The HTTP smoke test proves the right bytes are served. It cannot prove they
// render. Flutter web paints into a canvas, so a dart2js exception during
// startup leaves a blank blue rectangle while every asset still returns 200 —
// which is the exact shape of the bug that shipped in v1.1.0, and nothing in
// the pipeline would have caught it.
//
// So: load the real deployment at the sizes that have actually broken here,
// start a game, and check a board is on screen. Detection is by pixel colour
// rather than by selector, because there is nothing in the DOM to select: the
// home screen's cards and the board's white grid are both unmistakable against
// the blue gradient, and neither depends on a font or a golden baseline.
const { chromium } = require('playwright');
const fs = require('fs');

const SITE = process.argv[2];
const OUT = 'render-check';

// The sizes that have found bugs here, not the comfortable ones.
const VIEWPORTS = [
  ['iphone-se', 320, 568],
  ['fold-landscape', 653, 280],
  ['ipad', 834, 1194],
];

const TEAL = [0, 121, 107];      // the Daily Challenge card
const LIGHT = 200;               // the board is a near-white card

/// Decode a screenshot in the page and report what is on it: the fraction of
/// near-white pixels, and the centre of the largest teal region if any.
async function inspect(page, path) {
  const buf = await page.screenshot({ path });
  return page.evaluate(
    async ([dataUrl, teal, light]) => {
      const img = new Image();
      img.src = dataUrl;
      await img.decode();
      const c = document.createElement('canvas');
      c.width = img.width;
      c.height = img.height;
      const ctx = c.getContext('2d');
      ctx.drawImage(img, 0, 0);
      const { data } = ctx.getImageData(0, 0, c.width, c.height);
      let lightPx = 0, total = 0;
      let minX = 1e9, maxX = -1, minY = 1e9, maxY = -1, tealPx = 0;
      for (let y = 0; y < c.height; y += 2) {
        for (let x = 0; x < c.width; x += 2) {
          const i = (y * c.width + x) * 4;
          const r = data[i], g = data[i + 1], b = data[i + 2];
          total++;
          if (r > light && g > light && b > light) lightPx++;
          if (Math.abs(r - teal[0]) <= 18 &&
              Math.abs(g - teal[1]) <= 18 &&
              Math.abs(b - teal[2]) <= 18) {
            tealPx++;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      return {
        light: lightPx / total,
        teal: tealPx > 200
          ? { x: (minX + maxX) / 2, y: (minY + maxY) / 2 }
          : null,
        scale: c.width,
      };
    },
    ['data:image/png;base64,' + buf.toString('base64'), TEAL, LIGHT],
  );
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  const failures = [];

  for (const [name, width, height] of VIEWPORTS) {
    const ctx = await browser.newContext({
      viewport: { width, height },
      deviceScaleFactor: 2,
      isMobile: width < 700,
      hasTouch: width < 700,
    });
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(String(e).slice(0, 200)));

    try {
      await page.goto(SITE, { waitUntil: 'load' });
      await page.waitForTimeout(15000);

      // Scroll until the Daily Challenge card is visible, then tap it.
      let shot = await inspect(page, `${OUT}/${name}-home.png`);
      for (let i = 0; i < 6 && !shot.teal; i++) {
        await page.mouse.move(width / 2, height / 2);
        await page.mouse.wheel(0, 200);
        await page.waitForTimeout(700);
        shot = await inspect(page, `${OUT}/${name}-home.png`);
      }
      if (!shot.teal) {
        failures.push(`${name}: never found the Daily Challenge card`);
      } else {
        const px = shot.scale / width;   // screenshot px per CSS px
        await page.mouse.click(shot.teal.x / px, shot.teal.y / px);
        await page.waitForTimeout(9000);
        await page.mouse.move(2, 2);
        await page.waitForTimeout(400);
      }

      const game = await inspect(page, `${OUT}/${name}-game.png`);
      console.log(
        `${name} (${width}x${height}): ` +
        `${(game.light * 100).toFixed(1)}% of the screen is board`,
      );
      // A blank canvas is ~0%. A drawn 9x9 board is a large white card, and
      // the smallest share it takes on any of these viewports is ~20%.
      if (game.light < 0.10) {
        failures.push(
          `${name}: no board rendered — only ` +
          `${(game.light * 100).toFixed(1)}% of the screen is light`,
        );
      }
      if (errors.length) {
        failures.push(`${name}: JS errors — ${errors.join(' | ')}`);
      }
    } catch (e) {
      failures.push(`${name}: ${e.message.slice(0, 200)}`);
    }
    await ctx.close();
  }

  await browser.close();
  if (failures.length) {
    for (const f of failures) console.log(`::error::${f}`);
    process.exit(1);
  }
  console.log('Render check passed.');
})();
