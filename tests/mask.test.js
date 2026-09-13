const test = require('node:test');
const assert = require('node:assert/strict');
const zlib = require('node:zlib');
const contract = require('../src/flash-mask-contract.js');

function source(width, height) {
  return { file_name: 'scene.v2.jpg', width, height };
}

function payload(width, height, regions) {
  return contract.createPayload({ platform: 'web', sourceImage: source(width, height), regions });
}

function pointOnOracleEdge([x, y], [ax, ay], [bx, by]) {
  const cross = (x - ax) * (by - ay) - (y - ay) * (bx - ax);
  return Math.abs(cross) < 1e-9 && x >= Math.min(ax, bx) && x <= Math.max(ax, bx) && y >= Math.min(ay, by) && y <= Math.max(ay, by);
}

function oracleContains(point, polygon) {
  let winding = 0;
  for (let index = 0; index < polygon.length; index++) {
    const start = polygon[index];
    const end = polygon[(index + 1) % polygon.length];
    if (pointOnOracleEdge(point, start, end)) return true;
    const left = (end[0] - start[0]) * (point[1] - start[1]) - (point[0] - start[0]) * (end[1] - start[1]);
    if (start[1] <= point[1] && end[1] > point[1] && left > 0) winding++;
    if (start[1] > point[1] && end[1] <= point[1] && left < 0) winding--;
  }
  return winding !== 0;
}

function oracleMask(width, height, regions) {
  const result = new Uint8Array(width * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const center = [x + 0.5, y + 0.5];
      result[y * width + x] = regions.some((polygon) => oracleContains(center, polygon)) ? 1 : 0;
    }
  }
  return result;
}

function readUInt32(bytes, offset) {
  return ((bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3]) >>> 0;
}

function uint32(value) {
  return new Uint8Array([(value >>> 24) & 255, (value >>> 16) & 255, (value >>> 8) & 255, value & 255]);
}

function concatBytes(parts) {
  const result = new Uint8Array(parts.reduce((length, part) => length + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    result.set(part, offset);
    offset += part.length;
  }
  return result;
}

function crc32(bytes) {
  let value = 0xffffffff;
  for (const byte of bytes) {
    value ^= byte;
    for (let bit = 0; bit < 8; bit++) value = value & 1 ? (value >>> 1) ^ 0xedb88320 : value >>> 1;
  }
  return (value ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const typeBytes = Buffer.from(type, 'ascii');
  const body = concatBytes([typeBytes, data]);
  return concatBytes([uint32(data.length), body, uint32(crc32(body))]);
}

function tinyPng({ colorType, bitDepth, scanlineFilter = 0, transparency = false }) {
  const header = new Uint8Array(13);
  header.set(uint32(1), 0);
  header.set(uint32(1), 4);
  header.set([bitDepth, colorType, 0, 0, 0], 8);
  const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colorType];
  const dataBytes = bitDepth < 8 ? 1 : channels * (bitDepth === 16 ? 2 : 1);
  const row = new Uint8Array(1 + dataBytes).fill(255);
  row[0] = scanlineFilter;
  if (colorType === 3 && bitDepth < 8) row[1] = 0x80;
  const chunks = [pngChunk('IHDR', header)];
  if (colorType === 3) chunks.push(pngChunk('PLTE', new Uint8Array([0, 0, 0, 255, 255, 255])));
  if (transparency) chunks.push(pngChunk('tRNS', new Uint8Array(colorType === 0 ? [0, 255] : colorType === 2 ? [0, 255, 0, 255, 0, 255] : [255])));
  chunks.push(pngChunk('IDAT', zlib.deflateSync(row)), pngChunk('IEND', new Uint8Array()));
  return concatBytes([new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]), ...chunks]);
}

function readPngChunks(png) {
  assert.deepEqual([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  const chunks = [];
  for (let offset = 8; offset < png.length;) {
    const length = readUInt32(png, offset);
    assert.ok(offset + length + 12 <= png.length, 'PNG chunk length exceeds its input');
    const type = Buffer.from(png.subarray(offset + 4, offset + 8)).toString('ascii');
    const data = png.subarray(offset + 8, offset + 8 + length);
    chunks.push({ type, data });
    offset += length + 12;
  }
  return chunks;
}

function inspectMaskPngStructure(png) {
  const chunks = readPngChunks(png);
  const ihdr = chunks.find((chunk) => chunk.type === 'IHDR')?.data;
  assert.ok(ihdr, 'IHDR is required');
  assert.equal(ihdr.length, 13, 'IHDR must have the PNG-specified size');
  assert.ok([0, 2, 3].includes(ihdr[9]), 'mask PNG must use grayscale, RGB, or indexed color without alpha');
  assert.equal(chunks.some((chunk) => chunk.type === 'tRNS'), false, 'PNG must not carry transparency');
  assert.equal(chunks.some((chunk) => chunk.type === 'IDAT'), true, 'PNG must include pixel data');
  assert.equal(chunks.some((chunk) => chunk.type === 'IEND'), true, 'PNG must end');
  return { width: readUInt32(ihdr, 0), height: readUInt32(ihdr, 4), bitDepth: ihdr[8], colorType: ihdr[9], chunks };
}

function paeth(left, up, upLeft) {
  const prediction = left + up - upLeft;
  const leftDistance = Math.abs(prediction - left);
  const upDistance = Math.abs(prediction - up);
  const upLeftDistance = Math.abs(prediction - upLeft);
  return leftDistance <= upDistance && leftDistance <= upLeftDistance ? left : upDistance <= upLeftDistance ? up : upLeft;
}

function unfilterRgbRows(raw, width, height) {
  const stride = width * 3;
  const pixels = new Uint8Array(stride * height);
  let offset = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[offset++];
    assert.ok(filter >= 0 && filter <= 4, 'PNG scanline filter must be defined');
    for (let x = 0; x < stride; x++) {
      const encoded = raw[offset++];
      const left = x >= 3 ? pixels[y * stride + x - 3] : 0;
      const up = y ? pixels[(y - 1) * stride + x] : 0;
      const upLeft = y && x >= 3 ? pixels[(y - 1) * stride + x - 3] : 0;
      const predictor = filter === 0 ? 0 : filter === 1 ? left : filter === 2 ? up : filter === 3 ? Math.floor((left + up) / 2) : paeth(left, up, upLeft);
      pixels[y * stride + x] = (encoded + predictor) & 255;
    }
  }
  assert.equal(offset, raw.length, 'PNG rows must consume the decoded data exactly');
  return pixels;
}

function decodeCurrentProductionPng(png) {
  const structure = inspectMaskPngStructure(png);
  assert.equal(structure.bitDepth, 8, 'current production encoder emits 8-bit channels');
  assert.equal(structure.colorType, 2, 'current production encoder emits RGB without alpha');
  const raw = zlib.inflateSync(Buffer.concat(structure.chunks.filter((chunk) => chunk.type === 'IDAT').map((chunk) => Buffer.from(chunk.data))));
  return { width: structure.width, height: structure.height, pixels: unfilterRgbRows(raw, structure.width, structure.height) };
}

function decodedMask({ width, height, pixels }) {
  const mask = new Uint8Array(width * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const [red, green, blue] = pixels.subarray((y * width + x) * 3, (y * width + x + 1) * 3);
      assert.equal(red, green, 'mask RGB channels must agree');
      assert.equal(green, blue, 'mask RGB channels must agree');
      assert.ok(red === 0 || red === 255, 'mask pixels must be pure black or white');
      mask[y * width + x] = red === 255 ? 1 : 0;
    }
  }
  return mask;
}

test('PNG contract structure allows 0/2/3, rejects alpha and tRNS, and does not lock bit depth or scanline filters', () => {
  for (const fixture of [
    tinyPng({ colorType: 0, bitDepth: 16 }),
    tinyPng({ colorType: 2, bitDepth: 8 }),
    tinyPng({ colorType: 3, bitDepth: 1 })
  ]) assert.doesNotThrow(() => inspectMaskPngStructure(fixture));
  for (const colorType of [4, 6]) assert.throws(() => inspectMaskPngStructure(tinyPng({ colorType, bitDepth: 8 })), /grayscale, RGB, or indexed/);
  for (const colorType of [0, 2, 3]) assert.throws(() => inspectMaskPngStructure(tinyPng({ colorType, bitDepth: colorType === 3 ? 1 : 8, transparency: true })), /must not carry transparency/);
  for (const filter of [0, 1, 2, 3, 4]) {
    const decoded = decodeCurrentProductionPng(tinyPng({ colorType: 2, bitDepth: 8, scanlineFilter: filter }));
    assert.deepEqual([...decodedMask(decoded)], [1]);
  }
});

test('The pixel-center rule matches an independent winding oracle on complex boundaries', () => {
  const regions = [
    [[0, 0], [6, 0], [6, 6], [4, 6], [4, 2], [2, 2], [2, 6], [0, 6]],
    [[1, 1], [5, 3], [2, 5]]
  ];
  const result = contract.rasterizeMask(payload(6, 6, regions));
  assert.deepEqual([...result], [...oracleMask(6, 6, regions)]);
  assert.equal(contract.pointInOrOnPolygon([0.5, 0.5], [[0, 0], [4, 4], [0, 4]]), true, 'pixel center on a 45-degree edge is included');
});

test('Bottom-right boundaries, horizontal/vertical/diagonal edges, concave polygons, and multi-region unions are stable', () => {
  const full = [[0, 0], [5, 0], [5, 4], [0, 4]];
  assert.deepEqual([...contract.rasterizeMask(payload(5, 4, [full]))], Array(20).fill(1));

  const first = [[0, 0], [4, 0], [2, 4]];
  const second = [[2, 0], [5, 0], [5, 4]];
  const forward = contract.rasterizeMask(payload(5, 4, [first, second]));
  const reverse = contract.rasterizeMask(payload(5, 4, [second, first]));
  assert.deepEqual([...forward], [...reverse]);
  assert.deepEqual([...forward], [...oracleMask(5, 4, [first, second])]);
});

test('The exported PNG matches the same JSON regions pixel by pixel, with no alpha or tRNS', () => {
  const regions = [
    [[0, 0], [5, 0], [5, 4], [0, 4]],
    [[1, 1], [4, 1], [2, 3]]
  ];
  const task = payload(5, 4, regions);
  const raster = contract.rasterizeMask(task);
  const png = contract.encodeMaskPng(task.source_image.width, task.source_image.height, raster);
  const decoded = decodeCurrentProductionPng(png);
  assert.deepEqual([decoded.width, decoded.height], [5, 4]);
  assert.deepEqual([...decodedMask(decoded)], [...oracleMask(5, 4, regions)]);
  assert.deepEqual([...png], [...contract.encodeMaskPng(5, 4, raster)], 'PNG output is deterministic');
});
