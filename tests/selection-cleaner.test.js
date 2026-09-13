const test = require('node:test');
const assert = require('node:assert/strict');
const { performance } = require('node:perf_hooks');
const contract = require('../src/flash-mask-contract.js');
const cleaner = require('../src/selection-lasso-cleaner.js');

const WIDTH = 60;
const HEIGHT = 40;
// ponytail: broad unit-test ceiling catches accidental quadratic scans; it is not a product SLA.
const MAX_REPAIR_MILLISECONDS = 500;
const overrunTrace = Object.freeze([
  [12, 10], [23, 6], [42, 7], [52, 20], [42, 32], [18, 31], [7, 20], [10, 13],
  [22, 8], [16, 17], [26, 11], [13, 22], [23, 30], [11, 27], [20, 18], [24, 10], [20, 10]
].map(Object.freeze));
const naturalLasso = Object.freeze([[12, 10], [23, 6], [42, 7], [52, 20], [42, 32], [18, 31], [7, 20], [10, 13], [18, 9], [15, 15], [20, 10]].map(Object.freeze));
const bowtie = Object.freeze([[0, 0], [20, 20], [0, 19], [20, 0]].map(Object.freeze));
const multipleLoops = Object.freeze([[8, 8], [48, 8], [54, 20], [46, 33], [16, 34], [5, 22], [10, 12], [22, 8], [16, 17], [25, 12], [17, 22], [26, 17], [19, 11], [15, 15], [20, 10]].map(Object.freeze));
const complexScribble = Object.freeze([[5, 5], [55, 35], [5, 35], [55, 5], [5, 20], [55, 20]].map(Object.freeze));
const concave = Object.freeze([[6, 6], [52, 6], [52, 14], [33, 14], [33, 32], [21, 32], [21, 20], [6, 20]].map(Object.freeze));
const accuracyTrace = Object.freeze([
  [6, 6], [20, 6], [24, 2], [28, 10], [16, 10], [20, 6],
  [34, 6], [38, 2], [42, 10], [30, 10], [34, 6],
  [52, 6], [52, 14], [33, 14], [33, 32], [21, 32], [21, 20], [6, 20]
].map(Object.freeze));
const endpointTouch = Object.freeze([[0, 0], [10, 0], [10, 10], [5, 0], [7, 1], [6, 3], [5, 0], [0, 10]].map(Object.freeze));
const endpointTouchPrimary = Object.freeze([[5, 0], [10, 0], [10, 10]].map(Object.freeze));
const endpointTouchSmallLoop = Object.freeze([[5, 0], [7, 1], [6, 3]].map(Object.freeze));
const collinearOverlap = Object.freeze([[0, 0], [10, 0], [10, 10], [2, 0], [8, 0], [8, 3], [2, 3], [2, 0], [0, 10]].map(Object.freeze));
const collinearOverlapPrimary = Object.freeze([[2, 0], [8, 0], [10, 0], [10, 10]].map(Object.freeze));
const topologyEvents = Object.freeze([[0, 8], [4, 9], [25, 18], [23, 28], [6, 10], [9, 19], [7, 25], [7, 24], [0, 28]].map(Object.freeze));
const topologySampled = Object.freeze([[0, 8], [4, 9], [25, 18], [23, 28], [6, 10], [9, 19], [7, 25], [0, 28]].map(Object.freeze));
const topologySimplified = Object.freeze([[0, 8], [25, 18], [23, 28], [6, 10], [9, 19], [0, 28]].map(Object.freeze));

function createFromRegions(regions, width = WIDTH, height = HEIGHT) {
  return contract.createPayload({
    platform: 'web',
    sourceImage: { file_name: 'lasso.png', width, height },
    regions
  });
}

function hasRecoverableLassoFailure(error) {
  const messages = String(error.message).split('\n').filter(Boolean);
  return messages.length > 0
    && messages.every((message) => /\.points_px (self-intersects|has duplicate vertices|has zero area)$/.test(message))
    && messages.some((message) => /\.points_px (self-intersects|has duplicate vertices)$/.test(message));
}

function firstFormalCycle(raw, width = WIDTH, height = HEIGHT) {
  for (const cycle of cleaner.largestSimpleCycles(raw)) {
    try {
      createFromRegions([cycle], width, height);
      return cycle;
    } catch {}
  }
  return null;
}

function resolveLikeUi(raw, width = WIDTH, height = HEIGHT) {
  const points = cleaner.collapseSelectionLasso(raw);
  if (points.length < 3) return [];
  try {
    createFromRegions([points], width, height);
    return [points];
  } catch (error) {
    if (!hasRecoverableLassoFailure(error)) return [];
    const cycle = firstFormalCycle(points, width, height);
    return cycle ? [cycle] : [];
  }
}

function resolveLikeSmoothedUi(raw, displayPoints = raw, width = WIDTH, height = HEIGHT) {
  const simplified = cleaner.simplifySelectionLasso(raw, displayPoints);
  if (simplified.length >= 3) {
    try {
      createFromRegions([simplified], width, height);
      return [simplified];
    } catch {}
  }
  try {
    createFromRegions([raw], width, height);
    return [raw];
  } catch (error) {
    if (!hasRecoverableLassoFailure(error)) return [];
    const cycle = firstFormalCycle(raw, width, height);
    return cycle ? [cycle] : [];
  }
}

function densifyOpenPolyline(points) {
  const dense = [[...points[0]]];
  for (let index = 1; index < points.length; index++) {
    const [startX, startY] = points[index - 1];
    const [endX, endY] = points[index];
    const steps = Math.max(Math.abs(endX - startX), Math.abs(endY - startY));
    for (let step = 1; step <= steps; step++) {
      dense.push([
        startX + (endX - startX) * step / steps,
        startY + (endY - startY) * step / steps
      ]);
    }
  }
  return dense;
}

function smoothDisplayedGesture(cssPoints, { width, height, displayWidth, displayHeight }) {
  const imagePoints = [];
  const displayPoints = [];
  for (const [index, point] of cssPoints.entries()) {
    const imagePoint = [
      Math.round(point[0] * width / displayWidth),
      Math.round(point[1] * height / displayHeight)
    ];
    const previousImage = imagePoints.at(-1);
    const previousDisplay = displayPoints.at(-1);
    const isFinal = index === cssPoints.length - 1;
    if (!previousImage || ((previousImage[0] !== imagePoint[0] || previousImage[1] !== imagePoint[1])
      && (isFinal || cleaner.isDisplayPointFarEnough(previousDisplay, point)))) {
      imagePoints.push(imagePoint);
      displayPoints.push([...point]);
    }
  }
  return {
    sampled: imagePoints,
    points: cleaner.simplifySelectionLasso(imagePoints, displayPoints)
  };
}

function normalized(points, width, height) {
  return points.map(([x, y]) => [Number((x / width).toFixed(5)), Number((y / height).toFixed(5))]);
}

function assertEquivalentDisplayedShape(left, leftSize, right, rightSize) {
  assert.equal(left.length, right.length, 'the same gesture must retain the same simplified corners');
  for (const [index, point] of left.entries()) {
    const other = right[index];
    const leftX = point[0] / leftSize.sourceWidth;
    const leftY = point[1] / leftSize.sourceHeight;
    const rightX = other[0] / rightSize.sourceWidth;
    const rightY = other[1] / rightSize.sourceHeight;
    assert.ok(Math.abs(leftX - rightX) <= 2 / Math.min(leftSize.width, rightSize.width)
      && Math.abs(leftY - rightY) <= 2 / Math.min(leftSize.height, rightSize.height),
    `corner ${index} must stay within the two-CSS-pixel sampling threshold`);
  }
}

function assertUsableApproximation(raw, width = WIDTH, height = HEIGHT) {
  const regions = resolveLikeUi(raw, width, height);
  assert.ok(regions.length, 'a non-degenerate continuous lasso must produce at least one formal region');
  const payload = createFromRegions(regions, width, height);
  assert.deepEqual(contract.validatePayload(payload, 'web'), []);
  const mask = contract.rasterizeMask(payload);
  assert.ok(mask.some((pixel) => pixel === 1), 'the final regions must produce a non-empty mask');
  return { regions, payload, mask };
}

function signedArea(points) {
  return points.reduce((sum, [x1, y1], index) => {
    const [x2, y2] = points[(index + 1) % points.length];
    return sum + x1 * y2 - x2 * y1;
  }, 0) / 2;
}

function convexEnvelopeArea(raw) {
  const points = [...new Map(raw.map((point) => [`${point[0]},${point[1]}`, point])).values()]
    .sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cross = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
  const build = (items) => {
    const hull = [];
    for (const point of items) {
      while (hull.length >= 2 && cross(hull.at(-2), hull.at(-1), point) <= 0) hull.pop();
      hull.push(point);
    }
    return hull;
  };
  const hull = build(points).slice(0, -1).concat(build([...points].reverse()).slice(0, -1));
  return Math.abs(signedArea(hull));
}

function hasConcaveCorner(points) {
  const direction = Math.sign(signedArea(points));
  return points.some((point, index) => {
    const previous = points[(index - 1 + points.length) % points.length];
    const next = points[(index + 1) % points.length];
    return direction * ((point[0] - previous[0]) * (next[1] - point[1]) - (point[1] - previous[1]) * (next[0] - point[0])) < 0;
  });
}

test('Display-space sampling and RDP preserve the same concave contract region across resolution, display scaling, and hand jitter', () => {
  const denseCss = densifyOpenPolyline(concave).map(([x, y], index) =>
    y === 6 && x > 6 && x < 52 && index % 3 === 0 ? [x, y + 1] : [x, y]);
  const lowResolution = smoothDisplayedGesture(denseCss, { width: 60, height: 40, displayWidth: 60, displayHeight: 40 });
  const highResolution = smoothDisplayedGesture(denseCss, { width: 600, height: 400, displayWidth: 60, displayHeight: 40 });
  const zoomedCss = densifyOpenPolyline(concave.map(([x, y]) => [x * 2, y * 2])).map(([x, y], index) =>
    y === 12 && x > 12 && x < 104 && index % 3 === 0 ? [x, y + 1] : [x, y]);
  const zoomed = smoothDisplayedGesture(zoomedCss, { width: 600, height: 400, displayWidth: 120, displayHeight: 80 });
  const sparseConcave = smoothDisplayedGesture(concave, { width: 60, height: 40, displayWidth: 60, displayHeight: 40 });

  assert.ok(lowResolution.sampled.length < denseCss.length, 'moves under two CSS pixels must not all become image points');
  assert.ok(lowResolution.points.length * 4 <= denseCss.length, 'dense jitter must be materially reduced before contract validation');
  assert.deepEqual(sparseConcave.points, concave, 'an already-valid sparse concave polygon must remain unchanged');
  assert.ok(hasConcaveCorner(lowResolution.points));
  assert.deepEqual(normalized(lowResolution.points, 60, 40), normalized(highResolution.points, 600, 400), 'source resolution must not change a CSS-space gesture');
  assertEquivalentDisplayedShape(
    lowResolution.points,
    { width: 60, height: 40, sourceWidth: 60, sourceHeight: 40 },
    zoomed.points,
    { width: 120, height: 80, sourceWidth: 600, sourceHeight: 400 }
  );
  assert.deepEqual(contract.validatePayload(createFromRegions([lowResolution.points]), 'web'), []);

  const overrun = resolveLikeSmoothedUi(overrunTrace, overrunTrace);
  assert.deepEqual(overrun, [firstFormalCycle(overrunTrace)], 'an invalid simplification must fall back to the raw trace before choosing its largest strict-valid cycle');
  assert.deepEqual(resolveLikeSmoothedUi([[4, 20], [18, 20], [37, 20], [55, 20]]), []);
  assert.deepEqual(resolveLikeSmoothedUi([[4, 20], [55, 20]]), []);
});

test('Default smoothing does not expose three-pixel hand jitter as dense edit nodes', () => {
  const trace = [];
  for (let x = 0; x <= 40; x += 2) trace.push([x, x % 4 === 0 ? 0 : 3]);
  trace.push([40, 20], [0, 20]);

  const simplified = cleaner.simplifySelectionLasso(trace, trace);
  assert.deepEqual(simplified, [[0, 0], [40, 0], [40, 20], [0, 20]]);
  assert.ok(simplified.length * 4 < trace.length, 'small hand jitter should not become adjustment pressure');
});

test('Display-node sparsification preserves arc shape, with at least eight CSS pixels between adjacent final nodes', () => {
  const arc = [];
  for (let index = 0; index <= 72; index++) {
    const angle = index / 72 * Math.PI * 0.8;
    const radius = 30 + (index % 5 === 0 ? 3 : 0);
    arc.push([
      Math.round(50 + radius * Math.cos(angle)),
      Math.round(50 + radius * Math.sin(angle))
    ]);
  }
  arc.push([8, 8]);
  const simplified = cleaner.simplifySelectionLasso(arc, arc);
  const distances = simplified.map((point, index) => {
    const next = simplified[(index + 1) % simplified.length];
    return Math.hypot(next[0] - point[0], next[1] - point[1]);
  });

  assert.ok(simplified.length * 3 < arc.length, 'light arc jitter should materially reduce editable nodes');
  assert.ok(distances.every((distance) => distance >= 8), 'visible nodes must not overlap at the chosen CSS spacing');
  assert.deepEqual(cleaner.simplifySelectionLasso(concave, concave), concave, 'a sparse concave polygon must remain unchanged');
});

test('Closed paths do not treat an arbitrary seam as a fixed node; sparsification must preserve real corners', () => {
  const raw = [[35, 12], [50, 12], [50, 28], [32, 28], [32, 12], [35, 12]];
  const simplified = cleaner.simplifySelectionLasso(raw, raw);
  const contains = (point) => simplified.some(([x, y]) => x === point[0] && y === point[1]);
  const distances = simplified.map((point, index) => {
    const next = simplified[(index + 1) % simplified.length];
    return Math.hypot(next[0] - point[0], next[1] - point[1]);
  });

  assert.ok(simplified.length === 4 || simplified.length === 5, 'the closed shape should retain four or five real corners');
  assert.ok(contains([32, 12]), 'the real top-left turn must survive seam sparsification');
  assert.ok(simplified.every((point) => raw.some(([x, y]) => x === point[0] && y === point[1])), 'all visible nodes must remain raw geometry points');
  assert.ok(distances.every((distance) => distance >= 8), 'closed-loop visible nodes must keep the minimum spacing');
});

test('RDP must not turn a valid sampled raw trace into a smaller cycle: fall back to the raw strict payload when simplification fails', () => {
  assert.equal(topologyEvents.length, topologySampled.length + 1, 'the final event is a display-space rejection, not a changed raw trace');
  assert.deepEqual(cleaner.simplifySelectionLasso(topologySampled, topologySampled), topologySimplified);
  const rawPayload = createFromRegions([topologySampled], 30, 30);
  assert.deepEqual(contract.validatePayload(rawPayload, 'web'), []);
  assert.equal(contract.rasterizeMask(rawPayload).reduce((sum, value) => sum + value, 0), 243);
  assert.throws(() => createFromRegions([topologySimplified], 30, 30), /self-intersects/);
  assert.deepEqual(resolveLikeSmoothedUi(topologySampled, topologySampled, 30, 30), [topologySampled],
    'a legal sampled raw polygon must win before any cycle fallback');
});

test('The UI-to-contract boundary splits an ordinary self-intersecting lasso into the largest simple cycle while rejecting the original external polygon', () => {
  for (const raw of [accuracyTrace, overrunTrace, naturalLasso, bowtie, multipleLoops, complexScribble]) {
    assert.throws(() => createFromRegions([raw]), /self-intersects/, 'the shared contract must remain strict for uncleaned external input');
    const { regions, mask } = assertUsableApproximation(raw);
    const expected = firstFormalCycle(raw);
    assert.deepEqual(regions, [expected], 'the UI must use the largest strict-valid cycle from the same raw lasso');
    assert.notDeepEqual(regions, [raw]);
    assert.ok(mask.reduce((sum, pixel) => sum + pixel, 0) > 20, 'the approximation must retain a material selected area');
  }
  const concaveRegions = resolveLikeUi(concave);
  assert.deepEqual(concaveRegions, [concave], 'an already-valid concave polygon must not be widened into its hull');
  const bowtieCycle = firstFormalCycle(bowtie);
  assert.ok(Math.abs(signedArea(bowtieCycle)) < convexEnvelopeArea(bowtie), 'the bowtie must keep one real cycle instead of becoming its convex envelope');
  const accuracyCycle = firstFormalCycle(accuracyTrace);
  assert.ok(hasConcaveCorner(accuracyCycle), 'the regression trajectory must retain a concave boundary instead of becoming convex');
  assert.ok(Math.abs(signedArea(accuracyCycle)) < convexEnvelopeArea(accuracyTrace), 'the regression trajectory must not become its convex hull');
});

test('Equal-area cycles and non-integer intersections use stable ordering and deterministic pixel reduction', () => {
  const equalBowtie = [[0, 0], [20, 20], [0, 20], [20, 0]];
  const first = cleaner.largestSimpleCycles(equalBowtie);
  const second = cleaner.largestSimpleCycles(equalBowtie);
  assert.deepEqual(first, second, 'equal-area cycles must use the same traversal order every time');
  assert.deepEqual(resolveLikeUi(equalBowtie), [firstFormalCycle(equalBowtie)]);

  const fractionalCrossing = [[0, 0], [7, 9], [0, 10], [10, 0]];
  const cycle = firstFormalCycle(fractionalCrossing);
  assert.ok(cycle, 'a fractional intersection must still reduce to a formal pixel cycle');
  assert.ok(cycle.every(([x, y]) => Number.isInteger(x) && Number.isInteger(y)), 'intersection reduction must remain in pixel coordinates');
  assert.deepEqual(contract.validatePayload(createFromRegions([cycle]), 'web'), []);
});

test('Endpoint-on-edge and collinear overlap must preserve the main body instead of degenerating into a small loop', () => {
  assert.throws(() => createFromRegions([endpointTouch], 10, 10), /self-intersects/, 'external T-touch input must remain strict-invalid');
  assert.deepEqual(cleaner.largestSimpleCycles(endpointTouch)[0], endpointTouchPrimary, 'the endpoint on the old edge must split the main cycle before the repeated small loop');
  assert.deepEqual(resolveLikeUi(endpointTouch, 10, 10), [endpointTouchPrimary], 'the UI must emit the hard-coded main T-touch cycle');
  assert.notDeepEqual(resolveLikeUi(endpointTouch, 10, 10), [endpointTouchSmallLoop], 'the UI must not silently select the unrelated small triangle');
  const endpointPayload = createFromRegions([endpointTouchPrimary], 10, 10);
  assert.deepEqual(contract.validatePayload(endpointPayload, 'web'), []);
  assert.ok(contract.rasterizeMask(endpointPayload).reduce((sum, pixel) => sum + pixel, 0) > contract.rasterizeMask(createFromRegions([endpointTouchSmallLoop], 10, 10)).reduce((sum, pixel) => sum + pixel, 0));

  assert.throws(() => createFromRegions([collinearOverlap], 10, 10), /self-intersects/, 'external collinear overlap must remain strict-invalid');
  assert.deepEqual(cleaner.largestSimpleCycles(collinearOverlap)[0], collinearOverlapPrimary, 'overlapping edge endpoints must deterministically split the main cycle');
  assert.deepEqual(resolveLikeUi(collinearOverlap, 10, 10), [collinearOverlapPrimary]);
  assert.deepEqual(contract.validatePayload(createFromRegions([collinearOverlapPrimary], 10, 10), 'web'), []);
});

test('Gestures that cannot form an area remain empty', () => {
  assert.deepEqual(resolveLikeUi([[4, 20], [18, 20], [37, 20], [55, 20]]), []);
  assert.deepEqual(resolveLikeUi([[4, 20], [55, 20]]), []);
});

function longLasso(pointCount) {
  const points = [];
  for (let index = 0; index < pointCount; index++) {
    const angle = index * Math.PI * 2 / pointCount;
    points.push([
      Math.round(5000 + Math.cos(angle) * 4000),
      Math.round(5000 + Math.sin(angle) * 4000)
    ]);
  }
  return points;
}

function adversarialStar(pointCount) {
  const vertices = Array.from({ length: pointCount }, (_, index) => {
    const angle = index * Math.PI * 2 / pointCount;
    return [Math.round(1000000 + Math.cos(angle) * 800000), Math.round(1000000 + Math.sin(angle) * 800000)];
  });
  const stride = pointCount / 2 - 1;
  return Array.from({ length: pointCount }, (_, index) => vertices[index * stride % pointCount]);
}

test('Inputs with 500–4000 points fully participate in cycle splitting, while cleanup alone keeps a relaxed performance guardrail', () => {
  for (const pointCount of [500, 1000, 2000, 4000]) {
    const points = longLasso(pointCount);
    const seam = points[100];
    points.splice(101, 0, [seam[0] + 30, seam[1] + 30], [seam[0] - 20, seam[1] + 25], [seam[0], seam[1]]);
    const lateExtreme = [9500, 5000];
    points[points.length - 1] = lateExtreme;
    const started = performance.now();
    const cycles = cleaner.largestSimpleCycles(points);
    const elapsed = performance.now() - started;
    assert.ok(cycles[0]?.length >= 3, `${pointCount} points must produce a non-degenerate cycle`);
    assert.ok(cycles[0].length < points.length, `${pointCount} points must split instead of returning an oversized raw path`);
    assert.ok(cycles[0].some(([x, y]) => x === lateExtreme[0] && y === lateExtreme[1]), `${pointCount} points must retain an extreme beyond any fixed prefix`);
    assert.ok(elapsed < MAX_REPAIR_MILLISECONDS, `${pointCount} points must avoid an accidental quadratic scan (${elapsed.toFixed(1)}ms)`);
  }
});

test('A 4000-point star stays within the technical work limit without truncating RDP, and cycle repair stops safely', () => {
  const points = adversarialStar(4000);
  assert.equal(new Set(points.map(([x, y]) => `${x},${y}`)).size, points.length, 'the adversarial star must not depend on repeated vertices');
  const simplifyStarted = performance.now();
  const simplified = cleaner.simplifySelectionLasso(points, points);
  const simplifyElapsed = performance.now() - simplifyStarted;
  assert.deepEqual(simplified, points, 'an exhausted display-space simplifier must not truncate or invent a region');
  assert.ok(simplifyElapsed < MAX_REPAIR_MILLISECONDS, `the simplifier must respect its technical work cap (${simplifyElapsed.toFixed(1)}ms)`);

  const started = performance.now();
  const cycles = cleaner.largestSimpleCycles(points);
  const elapsed = performance.now() - started;
  assert.deepEqual(cycles, [], 'an exhausted repair must return no arbitrary formal cycle');
  // ponytail: broad unit-test ceiling bounds adversarial helper work; it is not a product SLA or input limit.
  assert.ok(elapsed < MAX_REPAIR_MILLISECONDS, `the adversarial star must hit the repair bound before quadratic work (${elapsed.toFixed(1)}ms)`);
});
