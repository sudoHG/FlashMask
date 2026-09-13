const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Ajv2020 = require('ajv/dist/2020');
const contract = require('../src/flash-mask-contract.js');

const fixture = (name) => JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', 'contracts', name), 'utf8'));
const validWeb = fixture('valid-web.json');
const validMac = fixture('valid-mac.json');
const loadSchema = (name) => JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'schemas', name), 'utf8'));

function compiledSchemas() {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  const base = loadSchema('flash-mask-1.0.schema.json');
  ajv.addSchema(base);
  return {
    base: ajv.getSchema(base.$id),
    web: ajv.compile(loadSchema('flash-mask-1.0-web.schema.json')),
    mac: ajv.compile(loadSchema('flash-mask-1.0-mac.schema.json'))
  };
}

const schemas = compiledSchemas();
const assertSchemaPasses = (validate, value) => assert.equal(validate(value), true, JSON.stringify(validate.errors));
const assertSchemaFails = (validate, value) => assert.equal(validate(value), false, 'Schema unexpectedly accepted an invalid producer payload');

function validateCompletePayload(profile, payload) {
  const schema = schemas[profile];
  const schemaPasses = schema(payload);
  const sharedValidatorErrors = contract.validateSharedPayload(payload);
  return {
    valid: schemaPasses && sharedValidatorErrors.length === 0,
    schemaPasses,
    schemaErrors: schemaPasses ? [] : structuredClone(schema.errors),
    sharedValidatorErrors
  };
}

function assertCompletePasses(profile, payload) {
  const result = validateCompletePayload(profile, payload);
  assert.equal(result.valid, true, JSON.stringify(result));
  return result;
}

function assertCompleteFails(profile, payload) {
  const result = validateCompletePayload(profile, payload);
  assert.equal(result.valid, false, 'Complete validation unexpectedly accepted an invalid producer payload');
  return result;
}

test('Shared schemas and platform profiles are machine-readable assets', () => {
  for (const name of ['flash-mask-1.0.schema.json', 'flash-mask-1.0-web.schema.json', 'flash-mask-1.0-mac.schema.json']) {
    const schema = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'schemas', name), 'utf8'));
    assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
    assert.ok(schema.$id.includes('flash-mask-1.0'));
  }
  const base = loadSchema('flash-mask-1.0.schema.json');
  assert.equal(base.additionalProperties, false);
  assert.equal(base.$defs.sourceImage.additionalProperties, false);
  assert.equal(base.$defs.coordinateSystem.additionalProperties, false);
  assert.equal(base.$defs.region.additionalProperties, false);
  assert.equal(base.$defs.pixelPoint.prefixItems[0].minimum, 0);
  assert.equal(base.$defs.pixelPoint.prefixItems[1].minimum, 0);
  assert.equal('const' in base.properties.instruction, false);
});

test('Ajv Draft 2020-12 executes the base schema, web profile, and Mac profile', () => {
  assertSchemaPasses(schemas.base, validWeb);
  assertSchemaPasses(schemas.base, validMac);
  assertSchemaPasses(schemas.web, validWeb);
  assertSchemaPasses(schemas.mac, validMac);

  assertSchemaFails(schemas.base, fixture('invalid-missing-instruction.json'));
  assertSchemaFails(schemas.web, fixture('invalid-web-file-path.json'));
  assertSchemaFails(schemas.mac, validWeb);
  assertSchemaFails(schemas.mac, fixture('invalid-mac-relative-path.json'));
  assertSchemaFails(schemas.web, fixture('invalid-whitespace-prompt.json'));
  assertSchemaFails(schemas.web, fixture('invalid-negative-coordinate.json'));

  const blankInstruction = structuredClone(validWeb);
  blankInstruction.instruction = ' \n\t ';
  const unknownTopLevel = structuredClone(validWeb);
  unknownTopLevel.extra = true;
  const unknownSource = structuredClone(validWeb);
  unknownSource.source_image.extra = true;
  const unknownCoordinateSystem = structuredClone(validWeb);
  unknownCoordinateSystem.coordinate_system.extra = true;
  const unknownRegion = structuredClone(validWeb);
  unknownRegion.regions[0].extra = true;
  for (const invalid of [blankInstruction, unknownTopLevel, unknownSource, unknownCoordinateSystem, unknownRegion]) assertSchemaFails(schemas.web, invalid);
});

test('Complete machine validation requires both the platform schema/profile and shared validator to pass', () => {
  assertCompletePasses('web', validWeb);
  assertCompletePasses('mac', validMac);

  const webAsMac = assertCompleteFails('mac', validWeb);
  assert.equal(webAsMac.schemaPasses, false);
  assert.deepEqual(webAsMac.sharedValidatorErrors, []);

  const macAsWeb = assertCompleteFails('web', validMac);
  assert.equal(macAsWeb.schemaPasses, false);
  assert.deepEqual(macAsWeb.sharedValidatorErrors, []);
});

test('Producers reject unknown public fields and malformed contracts', () => {
  const topLevel = structuredClone(validWeb);
  topLevel.extra = true;
  const source = structuredClone(validWeb);
  source.source_image.extra = true;
  const coordinate = structuredClone(validWeb);
  coordinate.coordinate_system.extra = true;
  const region = structuredClone(validWeb);
  region.regions[0].extra = true;
  const wrongNormalized = structuredClone(validWeb);
  wrongNormalized.regions[0].points_normalized[0] = [0.1, 0.1];
  const selfIntersecting = structuredClone(validWeb);
  selfIntersecting.regions[0].points_px = [[0, 0], [480, 432], [480, 0], [0, 432]];
  selfIntersecting.regions[0].points_normalized = [[0, 0], [0.25, 0.4], [0.25, 0], [0, 0.4]];
  for (const payload of [topLevel, source, coordinate, region, wrongNormalized, selfIntersecting]) assert.notDeepEqual(contract.validatePayload(payload, 'web'), []);
});

test('Complete machine validation distinguishes schema-local path rules from shared cross-field path consistency', () => {
  const differentFileName = structuredClone(validMac);
  differentFileName.source_image.file_path = '/tmp/flash-mask-contract/other.jpg';
  const differentFileNameResult = assertCompleteFails('mac', differentFileName);
  assert.equal(differentFileNameResult.schemaPasses, true);
  assert.ok(differentFileNameResult.sharedValidatorErrors.some((error) => error.includes('same file name')));

  const relativePathResult = assertCompleteFails('mac', fixture('invalid-mac-relative-path.json'));
  assert.equal(relativePathResult.schemaPasses, false);
  assert.deepEqual(relativePathResult.sharedValidatorErrors, []);

  const blankPromptResult = assertCompleteFails('web', fixture('invalid-whitespace-prompt.json'));
  assert.equal(blankPromptResult.schemaPasses, false);
  assert.deepEqual(blankPromptResult.sharedValidatorErrors, []);
});

test('Canonical geometry negatives are rejected by complete machine validation with the rejecting layer identified', () => {
  const cases = [
    {
      name: 'negative coordinate',
      file: 'invalid-negative-coordinate.json',
      schemaPasses: false,
      sharedError: null
    },
    {
      name: 'outside image dimensions',
      file: 'invalid-coordinate-outside-image.json',
      schemaPasses: true,
      sharedError: 'outside the image bounds'
    },
    {
      name: 'duplicate region id',
      file: 'invalid-duplicate-region-id.json',
      schemaPasses: true,
      sharedError: 'must be unique'
    },
    {
      name: 'incorrect points_normalized',
      file: 'invalid-wrong-normalized-points.json',
      schemaPasses: true,
      sharedError: 'does not match points_px'
    },
    {
      name: 'self-intersecting polygon',
      file: 'invalid-self-intersecting-region.json',
      schemaPasses: true,
      sharedError: 'self-intersects'
    }
  ];

  for (const invalid of cases) {
    const result = assertCompleteFails('web', fixture(invalid.file));
    assert.equal(result.schemaPasses, invalid.schemaPasses, invalid.name);
    if (invalid.sharedError) {
      assert.ok(result.sharedValidatorErrors.some((error) => error.includes(invalid.sharedError)), invalid.name);
    } else {
      assert.deepEqual(result.sharedValidatorErrors, [], invalid.name);
    }
  }
});

test('The generator fixes paired coordinates, platform paths, and prompt omission rules', () => {
  const sourceImage = { file_name: 'scene.v2.jpg', width: 3, height: 2, file_path: '/tmp/flash-mask-contract/scene.v2.jpg' };
  const regions = [[{ x: 0, y: 0 }, { x: 3, y: 0 }, { x: 3, y: 2 }, { x: 0, y: 2 }]];
  const web = contract.createPayload({ platform: 'web', sourceImage, regions, prompt: '  make it red  ' });
  const mac = contract.createPayload({ platform: 'mac', sourceImage, regions, prompt: '   ' });
  assert.equal(web.instruction, 'This JSON identifies areas the user selected in the source image. Each polygon marks one selected area; multiple polygons form a combined selection; the first and last points are connected automatically. Interpret the selected areas and any `prompt` in the context of the current conversation. If `prompt` is present, it expresses the user\'s intent regarding the image.');
  assert.equal(mac.instruction, web.instruction);
  assert.equal(web.source_image.file_path, undefined);
  assert.equal(mac.source_image.file_path, '/tmp/flash-mask-contract/scene.v2.jpg');
  assert.equal(web.prompt, '  make it red  ');
  assert.equal('prompt' in mac, false);
  const multiline = contract.createPayload({ platform: 'web', sourceImage, regions, prompt: 'make it red\nand keep the text' });
  const nextTask = contract.createPayload({ platform: 'web', sourceImage: { file_name: 'next.png', width: 3, height: 2 }, regions });
  assert.equal(multiline.prompt, 'make it red\nand keep the text');
  assert.equal('prompt' in nextTask, false);
  assert.deepEqual(web.regions[0].points_normalized, [[0, 0], [1, 0], [1, 1], [0, 1]]);
  assert.equal(contract.maskFileName('scene.v2.jpg'), 'scene.v2-蒙版.png');
  assert.equal(contract.maskFileName('untitled'), 'untitled-蒙版.png');
  assert.equal(JSON.stringify(web), JSON.stringify(contract.createPayload({ platform: 'web', sourceImage, regions, prompt: '  make it red  ' })));
  const changedInstruction = structuredClone(web);
  changedInstruction.instruction = 'A different non-empty human-readable instruction.';
  assert.deepEqual(contract.validatePayload(changedInstruction, 'web'), []);
});

test('Coordinate boundaries, five-decimal normalization, and invalid polygons are constrained by the contract', () => {
  const sourceImage = { file_name: 'edge.png', width: 6, height: 7 };
  const payload = contract.createPayload({
    platform: 'web',
    sourceImage,
    regions: [[[0, 0], [6, 0], [6, 7], [0, 7]]]
  });
  assert.deepEqual(payload.regions[0].points_normalized, [[0, 0], [1, 0], [1, 1], [0, 1]]);
  const duplicate = structuredClone(payload);
  duplicate.regions[0].points_px[3] = [0, 0];
  duplicate.regions[0].points_normalized[3] = [0, 0];
  assert.ok(contract.validatePayload(duplicate, 'web').some((error) => error.includes('duplicate')));
  const fraction = contract.createPayload({
    platform: 'web',
    sourceImage: { file_name: 'fraction.png', width: 3, height: 3 },
    regions: [[[1, 0], [3, 0], [3, 3], [1, 3]]]
  });
  assert.equal(fraction.regions[0].points_normalized[0][0], 0.33333);
});

test('EXIF orientations 1–8 use fixed forward dimension rules', () => {
  for (const orientation of [1, 2, 3, 4]) assert.deepEqual(contract.orientationDimensions(3, 2, orientation), { width: 3, height: 2 });
  for (const orientation of [5, 6, 7, 8]) assert.deepEqual(contract.orientationDimensions(3, 2, orientation), { width: 2, height: 3 });
});
