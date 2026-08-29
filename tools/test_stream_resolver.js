/**
 * Stream Resolver & Audio Pipeline Test Suite
 * Validates direct audio extraction, track resolution, and API contracts.
 */
const assert = require('assert');
const streamResolutionService = require('../services/streamResolutionService');
const trackResolverService = require('../services/trackResolverService');
const { createTrackManifest, decodeTrackManifest } = require('../lib/manifestGenerator');

async function runTests() {
  console.log('--- Starting Stream Resolver & Audio Pipeline Tests ---\n');
  let passed = 0;
  let failed = 0;

  function test(name, fn) {
    try {
      fn();
      console.log(`  [PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`  [FAIL] ${name} - ${err.message}`);
      failed++;
    }
  }

  async function asyncTest(name, fn) {
    try {
      await fn();
      console.log(`  [PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`  [FAIL] ${name} - ${err.message}`);
      failed++;
    }
  }

  // 1. Test Manifest Generator
  test('Manifest generation and decoding creates valid payload', () => {
    const directUrl = 'https://example.com/audio.mp3';
    const payload = createTrackManifest([directUrl], { mimeType: 'audio/mp3', trackId: 'test-1' });
    assert(payload.data && payload.data.manifest, 'Must have data.manifest');
    const decoded = decodeTrackManifest(payload.data.manifest);
    assert(decoded && decoded.urls && decoded.urls[0] === directUrl, 'Decoded manifest must match directUrl');
    assert.strictEqual(decoded.mimeType, 'audio/mp3');
  });

  // 2. Test Demo Track Resolution
  await asyncTest('Resolving local demo track returns stream info', async () => {
    const resolved = await trackResolverService.resolveTrack({
      id: 'demo-track-1',
      title: 'Midnight Echo',
      artist: 'Nova Harbor'
    });
    assert(resolved.videoId, 'Must resolve to videoId');
    assert.strictEqual(resolved.title, 'Midnight Echo');

    const streamInfo = await streamResolutionService.resolveStreamUrl(resolved.videoId);
    assert(streamInfo.directUrl, 'Must return directUrl');
    assert(streamInfo.directUrl.startsWith('http'), 'directUrl must be a valid HTTP URL');
  });

  // 3. Test YouTube Direct ID Resolution
  await asyncTest('Resolving 11-char YouTube ID handles direct video pointer', async () => {
    const videoId = 'dQw4w9WgXcQ';
    const resolved = await trackResolverService.resolveTrack({
      id: videoId,
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley'
    });
    assert.strictEqual(resolved.videoId, videoId);
    assert.strictEqual(resolved.source, 'youtube-direct');
  });

  // 4. Test Stream Resolution Output Structure
  await asyncTest('Stream resolution output contains directUrl and mimeType', async () => {
    const streamInfo = await streamResolutionService.resolveStreamUrl('demo-track-2');
    assert(streamInfo.directUrl, 'Must have directUrl');
    assert(streamInfo.mimeType, 'Must have mimeType');
    assert(streamInfo.source, 'Must have source');
  });

  console.log(`\n--- Stream Resolver Summary: ${passed} passed, ${failed} failed ---`);
  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Test run failed:', err);
  process.exit(1);
});

