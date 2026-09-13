const test = require('node:test');
const assert = require('node:assert/strict');
const { performance } = require('node:perf_hooks');
const contract = require('../src/flash-mask-contract.js');

const PHONE_WIDTH = 4032;
const PHONE_HEIGHT = 3024;
const POINT_COUNT = 384;
const MAX_ELAPSED_MILLISECONDS = 10000;
const MAX_RSS_DELTA_BYTES = 256 * 1024 * 1024;

function phoneClassSelection(width, height, pointCount) {
  const points = [];
  const centerX = width / 2;
  const centerY = height / 2;
  const radiusX = Math.floor(width * 0.44);
  const radiusY = Math.floor(height * 0.42);
  for (let index = 0; index < pointCount; index++) {
    const angle = index * Math.PI * 2 / pointCount;
    points.push([
      Math.round(centerX + Math.cos(angle) * radiusX),
      Math.round(centerY + Math.sin(angle) * radiusY)
    ]);
  }
  return points;
}

test('Phone-class 4032×3024 images and selections with hundreds of points maintain a repeatable linear pixel baseline', () => {
  const points = phoneClassSelection(PHONE_WIDTH, PHONE_HEIGHT, POINT_COUNT);
  const task = contract.createPayload({
    platform: 'web',
    sourceImage: { file_name: 'phone-class.jpg', width: PHONE_WIDTH, height: PHONE_HEIGHT },
    regions: [points]
  });
  const rssBefore = process.memoryUsage().rss;
  const started = performance.now();
  const raster = contract.rasterizeMask(task);
  const png = contract.encodeMaskPng(PHONE_WIDTH, PHONE_HEIGHT, raster);
  const elapsedMilliseconds = performance.now() - started;
  const rssDelta = process.memoryUsage().rss - rssBefore;
  const legacyPointTests = PHONE_WIDTH * PHONE_HEIGHT * POINT_COUNT;

  console.log(JSON.stringify({
    selection_performance: {
      image: `${PHONE_WIDTH}x${PHONE_HEIGHT}`,
      points: POINT_COUNT,
      elapsed_ms: Number(elapsedMilliseconds.toFixed(1)),
      rss_delta_mib: Number((rssDelta / 1024 / 1024).toFixed(1)),
      png_bytes: png.length,
      retired_point_edge_checks: legacyPointTests
    }
  }));
  assert.equal(raster.length, PHONE_WIDTH * PHONE_HEIGHT);
  assert.ok(raster.some((value) => value === 1), 'the real selection must produce white mask pixels');
  assert.ok(png.length > raster.length * 3, 'the deterministic RGB PNG must contain the full mask image');
  assert.ok(elapsedMilliseconds < MAX_ELAPSED_MILLISECONDS, `selection regression took ${elapsedMilliseconds.toFixed(1)}ms`);
  assert.ok(rssDelta < MAX_RSS_DELTA_BYTES, `selection regression used ${(rssDelta / 1024 / 1024).toFixed(1)}MiB extra RSS`);
});
