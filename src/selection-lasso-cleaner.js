(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.FlashMaskSelectionCleaner = api;
})(typeof globalThis === 'object' ? globalThis : this, () => {
  'use strict';

  // ponytail: this caps only expensive self-crossing repair; valid polygons still use the strict shared contract without a vertex limit.
  const MAX_REPAIR_WORK = 500000;
  const DISPLAY_SAMPLE_DISTANCE = 2;
  const DISPLAY_SIMPLIFY_TOLERANCE = 3.5;
  const DISPLAY_NODE_SPACING = 8;
  const samePoint = (a, b) => a[0] === b[0] && a[1] === b[1];
  const pointKey = ([x, y]) => `${x},${y}`;

  function collapseSelectionLasso(rawPoints) {
    const points = [];
    for (const point of rawPoints || []) {
      const copy = [point[0], point[1]];
      if (!points.length || !samePoint(points.at(-1), copy)) points.push(copy);
    }
    if (points.length > 1 && samePoint(points[0], points.at(-1))) points.pop();
    return points;
  }

  function isDisplayPointFarEnough(previous, point, minimumDistance = DISPLAY_SAMPLE_DISTANCE) {
    if (!previous) return true;
    const distance = Number.isFinite(minimumDistance) && minimumDistance >= 0 ? minimumDistance : DISPLAY_SAMPLE_DISTANCE;
    const x = point[0] - previous[0];
    const y = point[1] - previous[1];
    return x * x + y * y >= distance * distance;
  }

  function distanceToSegmentSquared(point, start, end) {
    const x = end[0] - start[0];
    const y = end[1] - start[1];
    const length = x * x + y * y;
    if (length === 0) {
      const pointX = point[0] - start[0];
      const pointY = point[1] - start[1];
      return pointX * pointX + pointY * pointY;
    }
    const ratio = Math.max(0, Math.min(1, ((point[0] - start[0]) * x + (point[1] - start[1]) * y) / length));
    const pointX = point[0] - (start[0] + ratio * x);
    const pointY = point[1] - (start[1] + ratio * y);
    return pointX * pointX + pointY * pointY;
  }

  function enforceDisplayNodeSpacing(pairs, minimumDistance = DISPLAY_NODE_SPACING) {
    if (pairs.length <= 3) return pairs;
    const spacingSquared = (Number.isFinite(minimumDistance) && minimumDistance >= 0 ? minimumDistance : DISPLAY_NODE_SPACING) ** 2;
    const previous = pairs.map((_, index) => (index + pairs.length - 1) % pairs.length);
    const next = pairs.map((_, index) => (index + 1) % pairs.length);
    const removed = new Uint8Array(pairs.length);
    const pending = Array.from({ length: pairs.length }, (_, index) => index);
    let pendingIndex = 0;
    let remaining = pairs.length;

    const distanceSquared = (left, right) => {
      const x = left.display[0] - right.display[0];
      const y = left.display[1] - right.display[1];
      return x * x + y * y;
    };
    const turnStrength = (index) => {
      const before = pairs[previous[index]].display;
      const point = pairs[index].display;
      const after = pairs[next[index]].display;
      const beforeX = point[0] - before[0];
      const beforeY = point[1] - before[1];
      const afterX = after[0] - point[0];
      const afterY = after[1] - point[1];
      const length = Math.hypot(beforeX, beforeY) * Math.hypot(afterX, afterY);
      return length ? 1 - (beforeX * afterX + beforeY * afterY) / length : 0;
    };

    while (pendingIndex < pending.length && remaining > 3) {
      const left = pending[pendingIndex++];
      if (removed[left]) continue;
      const right = next[left];
      if (removed[right] || distanceSquared(pairs[left], pairs[right]) >= spacingSquared) continue;
      const drop = turnStrength(left) < turnStrength(right) ? left : right;
      removed[drop] = 1;
      next[previous[drop]] = next[drop];
      previous[next[drop]] = previous[drop];
      remaining -= 1;
      pending.push(previous[drop], drop);
    }

    const output = [];
    let start = 0;
    while (removed[start]) start = next[start];
    for (let index = start; index !== start || !output.length; index = next[index]) {
      output.push(pairs[index]);
    }
    return output;
  }

  function simplifySelectionLasso(rawPoints, rawDisplayPoints, tolerance = DISPLAY_SIMPLIFY_TOLERANCE) {
    if (!Array.isArray(rawPoints) || !Array.isArray(rawDisplayPoints) || rawPoints.length !== rawDisplayPoints.length) return collapseSelectionLasso(rawPoints);
    const pairs = [];
    for (let index = 0; index < rawPoints.length; index++) {
      const image = rawPoints[index];
      const display = rawDisplayPoints[index];
      if (!Array.isArray(image) || !Array.isArray(display) || !Number.isFinite(display[0]) || !Number.isFinite(display[1])) return collapseSelectionLasso(rawPoints);
      if (!pairs.length || !samePoint(pairs.at(-1).image, image)) pairs.push({ image: [image[0], image[1]], display: [display[0], display[1]] });
    }
    if (pairs.length > 1 && samePoint(pairs[0].image, pairs.at(-1).image)) pairs.pop();
    if (pairs.length <= 2) return pairs.map(({ image }) => image);
    const squaredTolerance = (Number.isFinite(tolerance) && tolerance >= 0 ? tolerance : DISPLAY_SIMPLIFY_TOLERANCE) ** 2;
    const keep = new Uint8Array(pairs.length);
    const pending = [[0, pairs.length - 1]];
    keep[0] = 1;
    keep[pairs.length - 1] = 1;
    let work = 0;
    while (pending.length) {
      const [start, end] = pending.pop();
      let farthest = -1;
      let farthestDistance = squaredTolerance;
      for (let index = start + 1; index < end; index++) {
        // ponytail: stop simplifying adversarial traces rather than dropping points; strict validation and the existing repair cap decide fail-closed output.
        if (++work > MAX_REPAIR_WORK) return pairs.map(({ image }) => image);
        const distance = distanceToSegmentSquared(pairs[index].display, pairs[start].display, pairs[end].display);
        if (distance > farthestDistance) {
          farthest = index;
          farthestDistance = distance;
        }
      }
      if (farthest !== -1) {
        keep[farthest] = 1;
        pending.push([start, farthest], [farthest, end]);
      }
    }
    const simplifiedPairs = pairs.filter((_, index) => keep[index]);
    return enforceDisplayNodeSpacing(simplifiedPairs).map(({ image }) => image);
  }

  function signedArea(points) {
    return points.reduce((sum, [x1, y1], index) => {
      const [x2, y2] = points[(index + 1) % points.length];
      return sum + x1 * y2 - x2 * y1;
    }, 0) / 2;
  }

  function splitAtRepeatedVertex(points) {
    const seen = new Map();
    for (let index = 0; index < points.length; index++) {
      const key = pointKey(points[index]);
      const first = seen.get(key);
      if (first !== undefined && index - first > 1) {
        return [
          collapseSelectionLasso(points.slice(first, index)),
          collapseSelectionLasso([...points.slice(index), ...points.slice(0, first)])
        ];
      }
      seen.set(key, index);
    }
    return null;
  }

  function pointOnOpenSegment(a, b, point) {
    const cross = (b[0] - a[0]) * (point[1] - a[1]) - (b[1] - a[1]) * (point[0] - a[0]);
    return cross === 0 && !samePoint(a, point) && !samePoint(b, point)
      && point[0] >= Math.min(a[0], b[0]) && point[0] <= Math.max(a[0], b[0])
      && point[1] >= Math.min(a[1], b[1]) && point[1] <= Math.max(a[1], b[1]);
  }

  function useRepairWork(budget, amount = 1) {
    budget.used += amount;
    return budget.used <= MAX_REPAIR_WORK;
  }

  function properIntersection(a, b, c, d) {
    const abX = b[0] - a[0];
    const abY = b[1] - a[1];
    const cdX = d[0] - c[0];
    const cdY = d[1] - c[1];
    const denominator = abX * cdY - abY * cdX;
    if (denominator === 0) return null;
    const t = ((c[0] - a[0]) * cdY - (c[1] - a[1]) * cdX) / denominator;
    const u = ((c[0] - a[0]) * abY - (c[1] - a[1]) * abX) / denominator;
    if (t <= 0 || t >= 1 || u <= 0 || u >= 1) return null;
    return [Math.round(a[0] + t * abX), Math.round(a[1] + t * abY)];
  }

  function firstInteraction(points, budget) {
    const count = points.length;
    if (count < 4) return null;
    let minX = points[0][0];
    let maxX = minX;
    let minY = points[0][1];
    let maxY = minY;
    for (const [x, y] of points) {
      minX = Math.min(minX, x);
      maxX = Math.max(maxX, x);
      minY = Math.min(minY, y);
      maxY = Math.max(maxY, y);
    }
    const cellsPerSide = Math.ceil(Math.sqrt(count));
    const cellSize = Math.max(1, Math.ceil(Math.max(maxX - minX, maxY - minY) / cellsPerSide));
    const cells = new Map();
    for (let second = 0; second < count; second++) {
      if (!useRepairWork(budget)) return { exhausted: true };
      const secondEnd = (second + 1) % count;
      const a = points[second];
      const b = points[secondEnd];
      const firstColumn = Math.floor((Math.min(a[0], b[0]) - minX) / cellSize);
      const lastColumn = Math.floor((Math.max(a[0], b[0]) - minX) / cellSize);
      const firstRow = Math.floor((Math.min(a[1], b[1]) - minY) / cellSize);
      const lastRow = Math.floor((Math.max(a[1], b[1]) - minY) / cellSize);
      const candidates = new Set();
      const keys = [];
      for (let row = firstRow; row <= lastRow; row++) {
        for (let column = firstColumn; column <= lastColumn; column++) {
          if (!useRepairWork(budget)) return { exhausted: true };
          const key = `${column},${row}`;
          keys.push(key);
          for (const first of cells.get(key) || []) {
            if (!useRepairWork(budget)) return { exhausted: true };
            candidates.add(first);
          }
        }
      }
      for (const first of candidates) {
        if (!useRepairWork(budget)) return { exhausted: true };
        const firstEnd = (first + 1) % count;
        if (firstEnd === second || secondEnd === first) continue;
        const c = points[first];
        const d = points[firstEnd];
        if (pointOnOpenSegment(c, d, a)) return { type: 'touch', edge: first, point: a };
        if (pointOnOpenSegment(c, d, b)) return { type: 'touch', edge: first, point: b };
        if (pointOnOpenSegment(a, b, c)) return { type: 'touch', edge: second, point: c };
        if (pointOnOpenSegment(a, b, d)) return { type: 'touch', edge: second, point: d };
        const point = properIntersection(c, d, a, b);
        if (point) return { type: 'intersection', first, second, point };
      }
      for (const key of keys) {
        if (!useRepairWork(budget)) return { exhausted: true };
        const edgeIndexes = cells.get(key) || [];
        edgeIndexes.push(second);
        cells.set(key, edgeIndexes);
      }
    }
    return null;
  }

  function insertTouchVertex(points, { edge, point }) {
    return collapseSelectionLasso([...points.slice(0, edge + 1), [point[0], point[1]], ...points.slice(edge + 1)]);
  }

  function splitAtProperIntersection(points, intersection) {
    const { first, second, point } = intersection;
    return [
      collapseSelectionLasso([point, ...points.slice(first + 1, second + 1)]),
      collapseSelectionLasso([point, ...points.slice(second + 1), ...points.slice(0, first + 1)])
    ];
  }

  // ponytail: split in encounter order; equal-area cycles retain their first completed traversal order.
  function largestSimpleCycles(rawPoints) {
    const initial = collapseSelectionLasso(rawPoints);
    if (initial.length < 3) return [];
    const budget = { used: 0 };
    const pending = [initial];
    const cycles = [];
    while (pending.length) {
      const points = collapseSelectionLasso(pending.pop());
      if (points.length < 3) continue;
      if (!useRepairWork(budget, points.length)) return [];
      const interaction = firstInteraction(points, budget);
      if (interaction?.exhausted) return [];
      if (interaction?.type === 'touch') {
        pending.push(insertTouchVertex(points, interaction));
        continue;
      }
      const split = splitAtRepeatedVertex(points) || (interaction ? splitAtProperIntersection(points, interaction) : null);
      if (split) {
        const [first, second] = split;
        if (second.length >= 3) pending.push(second);
        if (first.length >= 3) pending.push(first);
      } else if (signedArea(points) !== 0) {
        cycles.push({ points, order: cycles.length });
      }
    }
    return cycles
      .sort((left, right) => Math.abs(signedArea(right.points)) - Math.abs(signedArea(left.points)) || left.order - right.order)
      .map(({ points }) => points.map(([x, y]) => [x, y]));
  }

  return { collapseSelectionLasso, isDisplayPointFarEnough, largestSimpleCycles, simplifySelectionLasso };
});
