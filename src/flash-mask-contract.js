(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.FlashMaskContract = api;
})(typeof globalThis === 'object' ? globalThis : this, () => {
  'use strict';

  const DEFAULT_INSTRUCTION = 'This JSON identifies areas the user selected in the source image. Each polygon marks one selected area; multiple polygons form a combined selection; the first and last points are connected automatically. Interpret the selected areas and any `prompt` in the context of the current conversation. If `prompt` is present, it expresses the user\'s intent regarding the image.';
  const COORDINATE_SYSTEM = { origin: 'top-left', x_direction: 'right', y_direction: 'down' };
  const CRC_TABLE = (() => {
    const table = new Uint32Array(256);
    for (let index = 0; index < 256; index++) {
      let value = index;
      for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
      table[index] = value >>> 0;
    }
    return table;
  })();

  const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
  const isFiniteNumber = (value) => typeof value === 'number' && Number.isFinite(value);
  const round5 = (value) => Math.round(value * 100000) / 100000;
  const pairKey = ([x, y]) => `${x},${y}`;

  function addUnknownFieldErrors(value, allowed, path, errors) {
    if (!isObject(value)) return;
    for (const key of Object.keys(value)) if (!allowed.includes(key)) errors.push(`${path}.${key} is not allowed`);
  }

  function signedArea(points) {
    let sum = 0;
    for (let index = 0; index < points.length; index++) {
      const [x1, y1] = points[index];
      const [x2, y2] = points[(index + 1) % points.length];
      sum += x1 * y2 - x2 * y1;
    }
    return sum / 2;
  }

  function orientation(a, b, c) {
    const value = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
    return Math.abs(value) < 1e-9 ? 0 : value > 0 ? 1 : -1;
  }

  function onSegment(a, b, point) {
    return orientation(a, b, point) === 0
      && point[0] >= Math.min(a[0], b[0]) - 1e-9 && point[0] <= Math.max(a[0], b[0]) + 1e-9
      && point[1] >= Math.min(a[1], b[1]) - 1e-9 && point[1] <= Math.max(a[1], b[1]) + 1e-9;
  }

  function segmentsIntersect(a, b, c, d) {
    const abC = orientation(a, b, c);
    const abD = orientation(a, b, d);
    const cdA = orientation(c, d, a);
    const cdB = orientation(c, d, b);
    if (abC === 0 && onSegment(a, b, c)) return true;
    if (abD === 0 && onSegment(a, b, d)) return true;
    if (cdA === 0 && onSegment(c, d, a)) return true;
    if (cdB === 0 && onSegment(c, d, b)) return true;
    return abC !== abD && cdA !== cdB;
  }

  function polygonIsSimple(points) {
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
    const cellsPerSide = Math.ceil(Math.sqrt(points.length));
    const cellSize = Math.max(1, Math.ceil(Math.max(maxX - minX, maxY - minY) / cellsPerSide));
    const cells = new Map();
    const compared = new Set();
    for (let index = 0; index < points.length; index++) {
      const end = (index + 1) % points.length;
      const [startX, startY] = points[index];
      const [endX, endY] = points[end];
      const firstColumn = Math.floor((Math.min(startX, endX) - minX) / cellSize);
      const lastColumn = Math.floor((Math.max(startX, endX) - minX) / cellSize);
      const firstRow = Math.floor((Math.min(startY, endY) - minY) / cellSize);
      const lastRow = Math.floor((Math.max(startY, endY) - minY) / cellSize);
      for (let row = firstRow; row <= lastRow; row++) {
        for (let column = firstColumn; column <= lastColumn; column++) {
          const key = `${column},${row}`;
          const candidates = cells.get(key) ?? [];
          for (const other of candidates) {
            const otherEnd = (other + 1) % points.length;
            if (end === other || otherEnd === index) continue;
            const pair = other < index ? `${other}:${index}` : `${index}:${other}`;
            if (compared.has(pair)) continue;
            compared.add(pair);
            if (segmentsIntersect(points[index], points[end], points[other], points[otherEnd])) return false;
          }
          candidates.push(index);
          cells.set(key, candidates);
        }
      }
    }
    return true;
  }

  function isLocalPixelPoint(pair) {
    return Array.isArray(pair) && pair.length === 2
      && Number.isInteger(pair[0]) && pair[0] >= 0
      && Number.isInteger(pair[1]) && pair[1] >= 0;
  }

  function isLocalNormalizedPoint(pair) {
    return Array.isArray(pair) && pair.length === 2
      && isFiniteNumber(pair[0]) && pair[0] >= 0 && pair[0] <= 1
      && isFiniteNumber(pair[1]) && pair[1] >= 0 && pair[1] <= 1;
  }

  function validateLocalPixelPoints(points, path, errors) {
    if (!Array.isArray(points) || points.length < 3) {
      errors.push(`${path} must contain at least three points`);
      return;
    }
    for (const [index, pair] of points.entries()) {
      if (!Array.isArray(pair) || pair.length !== 2 || !Number.isInteger(pair[0]) || !Number.isInteger(pair[1])) {
        errors.push(`${path}[${index}] must be an integer [x, y] pair`);
      } else if (pair[0] < 0 || pair[1] < 0) {
        errors.push(`${path}[${index}] must be a non-negative [x, y] pair`);
      }
    }
  }

  function validateLocalNormalizedPoints(points, path, errors) {
    if (!Array.isArray(points) || points.length < 3) {
      errors.push(`${path} must contain at least three points`);
      return;
    }
    for (const [index, pair] of points.entries()) {
      if (!isLocalNormalizedPoint(pair)) errors.push(`${path}[${index}] must be a normalized [x, y] pair`);
    }
  }

  // Schema/profile validate local fields; this shared layer compares valid fields across the payload.
  function validateSharedPayload(payload) {
    const errors = [];
    if (!isObject(payload) || !isObject(payload.source_image) || !Array.isArray(payload.regions)) return errors;

    const source = payload.source_image;
    const { file_name: fileName, file_path: filePath, width, height } = source;
    if (typeof fileName === 'string' && fileName && typeof filePath === 'string' && filePath && !filePath.endsWith(`/${fileName}`)) {
      errors.push('payload.source_image.file_path must end with the same file name');
    }
    if (!Number.isInteger(width) || width <= 0 || !Number.isInteger(height) || height <= 0) return errors;

    const ids = new Set();
    for (const [index, region] of payload.regions.entries()) {
      if (!isObject(region)) continue;
      const path = `payload.regions[${index}]`;
      if (Number.isInteger(region.id) && region.id > 0) {
        if (ids.has(region.id)) errors.push(`${path}.id must be unique`);
        ids.add(region.id);
      }

      const points = region.points_px;
      if (!Array.isArray(points) || points.length < 3 || !points.every(isLocalPixelPoint)) continue;
      for (const [pointIndex, pair] of points.entries()) {
        if (pair[0] > width || pair[1] > height) errors.push(`${path}.points_px[${pointIndex}] is outside the image bounds`);
      }
      if (new Set(points.map(pairKey)).size !== points.length) errors.push(`${path}.points_px has duplicate vertices`);
      if (signedArea(points) === 0) errors.push(`${path}.points_px has zero area`);
      if (!polygonIsSimple(points)) errors.push(`${path}.points_px self-intersects`);

      const normalized = region.points_normalized;
      if (!Array.isArray(normalized) || normalized.length !== points.length || !normalized.every(isLocalNormalizedPoint)) continue;
      for (const [pointIndex, pair] of normalized.entries()) {
        const expected = [round5(points[pointIndex][0] / width), round5(points[pointIndex][1] / height)];
        if (Math.abs(pair[0] - expected[0]) > 1e-10 || Math.abs(pair[1] - expected[1]) > 1e-10) {
          errors.push(`${path}.points_normalized[${pointIndex}] does not match points_px`);
        }
      }
    }
    return errors;
  }

  function validateLocalPayload(payload, profile = 'base') {
    const errors = [];
    if (!['base', 'web', 'mac'].includes(profile)) return [`profile ${profile} is unknown`];
    if (!isObject(payload)) return ['payload must be an object'];

    addUnknownFieldErrors(payload, ['mask_spec_version', 'instruction', 'source_image', 'coordinate_system', 'regions', 'prompt'], 'payload', errors);
    for (const field of ['mask_spec_version', 'instruction', 'source_image', 'coordinate_system', 'regions']) {
      if (!(field in payload)) errors.push(`payload.${field} is required`);
    }
    if (payload.mask_spec_version !== '1.0') errors.push('payload.mask_spec_version must equal 1.0');
    if (typeof payload.instruction !== 'string' || !payload.instruction.trim()) errors.push('payload.instruction must be a non-empty string');
    if ('prompt' in payload && (typeof payload.prompt !== 'string' || !payload.prompt.trim())) errors.push('payload.prompt must be omitted or non-blank text');

    const source = payload.source_image;
    if (!isObject(source)) {
      errors.push('payload.source_image must be an object');
    } else {
      addUnknownFieldErrors(source, ['file_name', 'width', 'height', 'file_path'], 'payload.source_image', errors);
      for (const field of ['file_name', 'width', 'height']) if (!(field in source)) errors.push(`payload.source_image.${field} is required`);
      if (typeof source.file_name !== 'string' || !source.file_name) errors.push('payload.source_image.file_name must be a non-empty string');
      if (!Number.isInteger(source.width) || source.width <= 0) errors.push('payload.source_image.width must be a positive integer');
      if (!Number.isInteger(source.height) || source.height <= 0) errors.push('payload.source_image.height must be a positive integer');
      const hasPath = Object.hasOwn(source, 'file_path');
      if (hasPath && (typeof source.file_path !== 'string' || !source.file_path || !source.file_path.startsWith('/'))) {
        errors.push('payload.source_image.file_path must be an absolute path');
      }
      if (profile === 'web' && hasPath) errors.push('payload.source_image.file_path is forbidden for web');
      if (profile === 'mac' && !hasPath) errors.push('payload.source_image.file_path is required for mac');
    }

    const coordinates = payload.coordinate_system;
    if (!isObject(coordinates)) {
      errors.push('payload.coordinate_system must be an object');
    } else {
      addUnknownFieldErrors(coordinates, ['origin', 'x_direction', 'y_direction'], 'payload.coordinate_system', errors);
      if (coordinates.origin !== COORDINATE_SYSTEM.origin || coordinates.x_direction !== COORDINATE_SYSTEM.x_direction || coordinates.y_direction !== COORDINATE_SYSTEM.y_direction) {
        errors.push('payload.coordinate_system must be top-left/right/down');
      }
    }

    if (!Array.isArray(payload.regions) || !payload.regions.length) {
      errors.push('payload.regions must contain at least one region');
      return errors;
    }
    for (const [index, region] of payload.regions.entries()) {
      const path = `payload.regions[${index}]`;
      if (!isObject(region)) {
        errors.push(`${path} must be an object`);
        continue;
      }
      addUnknownFieldErrors(region, ['id', 'shape', 'points_px', 'points_normalized'], path, errors);
      for (const field of ['id', 'shape', 'points_px', 'points_normalized']) if (!(field in region)) errors.push(`${path}.${field} is required`);
      if (!Number.isInteger(region.id) || region.id <= 0) errors.push(`${path}.id must be a positive integer`);
      if (region.shape !== 'polygon') errors.push(`${path}.shape must equal polygon`);
      validateLocalPixelPoints(region.points_px, `${path}.points_px`, errors);
      validateLocalNormalizedPoints(region.points_normalized, `${path}.points_normalized`, errors);
    }
    return errors;
  }

  function validatePayload(payload, profile = 'base') {
    return [...validateLocalPayload(payload, profile), ...validateSharedPayload(payload)];
  }

  function assertValidPayload(payload, profile = 'base') {
    const errors = validatePayload(payload, profile);
    if (errors.length) throw new Error(errors.join('\n'));
    return payload;
  }

  function inputPoint(point) {
    if (Array.isArray(point)) return [point[0], point[1]];
    if (isObject(point)) return [point.x, point.y];
    return [undefined, undefined];
  }

  function createPayload({ platform, sourceImage, regions, prompt, instruction = DEFAULT_INSTRUCTION }) {
    if (!['web', 'mac'].includes(platform)) throw new Error('platform must be web or mac');
    const source = {
      file_name: sourceImage?.file_name,
      width: sourceImage?.width,
      height: sourceImage?.height
    };
    if (platform === 'mac') source.file_path = sourceImage?.file_path;
    const payload = {
      mask_spec_version: '1.0',
      instruction,
      source_image: source,
      coordinate_system: { ...COORDINATE_SYSTEM },
      regions: (regions || []).map((region, index) => {
        const points = region.map(inputPoint);
        return {
          id: index + 1,
          shape: 'polygon',
          points_px: points,
          points_normalized: points.map(([x, y]) => [round5(x / source.width), round5(y / source.height)])
        };
      })
    };
    if (prompt !== undefined && prompt !== null) {
      if (typeof prompt !== 'string') throw new Error('prompt must be text when provided');
      if (prompt.trim()) payload.prompt = prompt;
    }
    return assertValidPayload(payload, platform);
  }

  function pointInOrOnPolygon(point, polygon) {
    let inside = false;
    for (let index = 0, previous = polygon.length - 1; index < polygon.length; previous = index++) {
      const a = polygon[previous];
      const b = polygon[index];
      if (onSegment(a, b, point)) return true;
      if ((a[1] > point[1]) !== (b[1] > point[1]) && point[0] < (b[0] - a[0]) * (point[1] - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
    }
    return inside;
  }

  function rasterizeMask(payload) {
    assertValidPayload(payload);
    const { width, height } = payload.source_image;
    const mask = new Uint8Array(width * height);
    for (const region of payload.regions) rasterizePolygon(mask, width, height, region.points_px);
    return mask;
  }

  function rasterizePolygon(mask, width, height, points) {
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
    const firstX = Math.max(0, Math.ceil(minX - 0.5));
    const lastX = Math.min(width - 1, Math.floor(maxX - 0.5));
    const firstY = Math.max(0, Math.ceil(minY - 0.5));
    const lastY = Math.min(height - 1, Math.floor(maxY - 0.5));
    if (firstX > lastX || firstY > lastY) return;

    for (let y = firstY; y <= lastY; y++) {
      const pointY = y + 0.5;
      const crossings = [];
      for (let index = 0, previous = points.length - 1; index < points.length; previous = index++) {
        const a = points[previous];
        const b = points[index];
        if ((a[1] > pointY) !== (b[1] > pointY)) crossings.push((b[0] - a[0]) * (pointY - a[1]) / (b[1] - a[1]) + a[0]);
      }
      crossings.sort((first, second) => first - second);
      let crossing = 0;
      let inside = false;
      const row = y * width;
      for (let x = firstX; x <= lastX; x++) {
        const pointX = x + 0.5;
        let onBoundary = false;
        while (crossing < crossings.length && crossings[crossing] <= pointX + 1e-9) {
          if (Math.abs(crossings[crossing] - pointX) < 1e-9) onBoundary = true;
          inside = !inside;
          crossing += 1;
        }
        if (inside || onBoundary) mask[row + x] = 1;
      }
    }
  }

  function maskFileName(fileName) {
    const dot = fileName.lastIndexOf('.');
    const base = dot > 0 ? fileName.slice(0, dot) : fileName;
    return `${base}-蒙版.png`;
  }

  function crc32(bytes) {
    let value = 0xffffffff;
    for (const byte of bytes) value = CRC_TABLE[(value ^ byte) & 0xff] ^ (value >>> 8);
    return (value ^ 0xffffffff) >>> 0;
  }

  function writeUint32(output, offset, value) {
    output[offset] = (value >>> 24) & 255;
    output[offset + 1] = (value >>> 16) & 255;
    output[offset + 2] = (value >>> 8) & 255;
    output[offset + 3] = value & 255;
  }

  function encodeMaskPng(width, height, mask) {
    if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0 || !(mask instanceof Uint8Array) || mask.length !== width * height) {
      throw new Error('invalid mask dimensions');
    }
    const rowLength = 1 + width * 3;
    const rawLength = rowLength * height;
    const blockCount = Math.ceil(rawLength / 65535);
    const zlibLength = 2 + blockCount * 5 + rawLength + 4;
    const output = new Uint8Array(57 + zlibLength);
    let offset = 0;
    output.set([137, 80, 78, 71, 13, 10, 26, 10], offset);
    offset += 8;
    writeUint32(output, offset, 13);
    offset += 4;
    const ihdrStart = offset;
    output.set([73, 72, 68, 82], offset);
    offset += 4;
    writeUint32(output, offset, width);
    writeUint32(output, offset + 4, height);
    output.set([8, 2, 0, 0, 0], offset + 8);
    offset += 13;
    writeUint32(output, offset, crc32(output.subarray(ihdrStart, offset)));
    offset += 4;
    writeUint32(output, offset, zlibLength);
    offset += 4;
    const idatStart = offset;
    output.set([73, 68, 65, 84, 0x78, 0x01], offset);
    offset += 6;
    let rawRemaining = rawLength;
    let blockRemaining = 0;
    let adlerA = 1;
    let adlerB = 0;
    const writeRawByte = (value) => {
      if (blockRemaining === 0) {
        const length = Math.min(65535, rawRemaining);
        output[offset++] = length === rawRemaining ? 1 : 0;
        output[offset++] = length & 255;
        output[offset++] = length >>> 8;
        const inverse = (~length) & 0xffff;
        output[offset++] = inverse & 255;
        output[offset++] = inverse >>> 8;
        blockRemaining = length;
      }
      output[offset++] = value;
      adlerA += value;
      if (adlerA >= 65521) adlerA -= 65521;
      adlerB += adlerA;
      if (adlerB >= 65521) adlerB -= 65521;
      blockRemaining -= 1;
      rawRemaining -= 1;
    };
    for (let y = 0; y < height; y++) {
      writeRawByte(0);
      for (let x = 0; x < width; x++) {
        const value = mask[y * width + x] ? 255 : 0;
        writeRawByte(value);
        writeRawByte(value);
        writeRawByte(value);
      }
    }
    writeUint32(output, offset, ((adlerB << 16) | adlerA) >>> 0);
    offset += 4;
    writeUint32(output, offset, crc32(output.subarray(idatStart, offset)));
    offset += 4;
    writeUint32(output, offset, 0);
    output.set([73, 69, 78, 68], offset + 4);
    writeUint32(output, offset + 8, crc32(output.subarray(offset + 4, offset + 8)));
    return output;
  }

  function orientationDimensions(width, height, orientation) {
    if (!Number.isInteger(width) || !Number.isInteger(height) || !Number.isInteger(orientation) || orientation < 1 || orientation > 8) throw new Error('invalid EXIF orientation dimensions');
    return orientation >= 5 ? { width: height, height: width } : { width, height };
  }

  return {
    COORDINATE_SYSTEM,
    DEFAULT_INSTRUCTION,
    assertValidPayload,
    createPayload,
    encodeMaskPng,
    maskFileName,
    orientationDimensions,
    pointInOrOnPolygon,
    rasterizeMask,
    round5,
    validateSharedPayload,
    validatePayload
  };
});
