/**
 * Comprehensive API Verification Test Suite
 * Tests all required endpoints and response payload contracts.
 */
const http = require('http');
process.env.NODE_ENV = 'test';
process.env.PORT = '3001';

const app = require('../server');

function request(urlPath) {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:3001${urlPath}`, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, headers: res.headers, body: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, raw: data });
        }
      });
    }).on('error', reject);
  });
}

async function runTests() {
  const server = app.listen(3001);
  console.log('--- Starting API Contract & Endpoint Verification Tests ---\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, testName, details = '') {
    if (condition) {
      console.log(`  [PASS] ${testName}`);
      passed++;
    } else {
      console.error(`  [FAIL] ${testName} - ${details}`);
      failed++;
    }
  }

  try {
    // 1. Health Endpoint
    const healthRes = await request('/health');
    assert(healthRes.status === 200 && healthRes.body.ok === true, 'GET /health returns ok:true');

    // 2. Search Endpoint (Tracks)
    const searchTracks = await request('/api/search?s=Midnight');
    assert(
      searchTracks.status === 200 &&
      searchTracks.body.data &&
      Array.isArray(searchTracks.body.data.items),
      'GET /api/search?s=Midnight returns data.items array'
    );

    // 3. Search Endpoint (Artists)
    const searchArtists = await request('/api/search?a=Nova');
    assert(
      searchArtists.status === 200 &&
      searchArtists.body.data &&
      Array.isArray(searchArtists.body.data.artists?.items || searchArtists.body.data.items),
      'GET /api/search?a=Nova returns artist results'
    );

    // 4. Search Endpoint (Albums)
    const searchAlbums = await request('/api/search?al=Afterglow');
    assert(
      searchAlbums.status === 200 &&
      searchAlbums.body.data &&
      Array.isArray(searchAlbums.body.data.albums?.items || searchAlbums.body.data.items),
      'GET /api/search?al=Afterglow returns album results'
    );

    // 5. Info Endpoint
    const infoRes = await request('/api/info?id=demo-track-1');
    assert(
      infoRes.status === 200 &&
      infoRes.body.data &&
      infoRes.body.data.track &&
      infoRes.body.data.mixes?.TRACK_MIX,
      'GET /api/info?id=demo-track-1 returns track metadata and TRACK_MIX'
    );

    // 6. Track Playback Endpoint (Manifest generation)
    const trackRes = await request('/api/track?id=demo-track-1&quality=LOSSLESS');
    let decodedManifest = null;
    if (trackRes.body.data?.manifest) {
      try {
        decodedManifest = JSON.parse(Buffer.from(trackRes.body.data.manifest, 'base64').toString('utf8'));
      } catch (e) {}
    }
    assert(
      trackRes.status === 200 &&
      decodedManifest &&
      Array.isArray(decodedManifest.urls) &&
      decodedManifest.urls.length > 0,
      'GET /api/track?id=demo-track-1 returns decodable base64 manifest with stream URLs'
    );

    // 7. Mix Endpoint
    const mixRes = await request('/api/mix?id=demo-mix-1');
    assert(
      mixRes.status === 200 &&
      Array.isArray(mixRes.body.items) &&
      mixRes.body.items[0]?.item?.title,
      'GET /api/mix?id=demo-mix-1 returns items array with song objects'
    );

    // 8. Artist Endpoint
    const artistRes = await request('/api/artist?id=artist-1');
    assert(
      artistRes.status === 200 &&
      (artistRes.body.artist?.name || artistRes.body.data?.artist?.name) &&
      Array.isArray(artistRes.body.tracks || artistRes.body.data?.tracks),
      'GET /api/artist?id=artist-1 returns artist and tracks'
    );

    // 9. Artist Similar Endpoint
    const artistSimilarRes = await request('/api/artist/similar?id=artist-1');
    assert(
      artistSimilarRes.status === 200 &&
      Array.isArray(artistSimilarRes.body.artists || artistSimilarRes.body.data?.artists),
      'GET /api/artist/similar?id=artist-1 returns similar artists array'
    );

    // 10. Album Endpoint
    const albumRes = await request('/api/album?id=album-1');
    assert(
      albumRes.status === 200 &&
      (albumRes.body.album?.title || albumRes.body.data?.album?.title) &&
      Array.isArray(albumRes.body.items || albumRes.body.data?.items),
      'GET /api/album?id=album-1 returns album details and track items'
    );

    // 11. Resolve Endpoint
    const resolveRes = await request('/api/resolve?title=Midnight+Echo&artist=Nova+Harbor&duration_ms=222000');
    assert(
      resolveRes.status === 200 &&
      resolveRes.body.videoId &&
      typeof resolveRes.body.score === 'number',
      'GET /api/resolve returns videoId with match score'
    );

    // 12. Stream URL Endpoint
    const streamRes = await request('/api/stream-url?videoId=demo-track-1');
    assert(
      streamRes.status === 200 &&
      streamRes.body.videoId &&
      streamRes.body.directUrl &&
      streamRes.body.directUrl.startsWith('http'),
      'GET /api/stream-url?videoId=demo-track-1 returns playable directUrl'
    );

    // 13. Auth Spotify Login Endpoint
    const authSpotifyLogin = await request('/api/auth/spotify/login');
    assert(
      authSpotifyLogin.status === 200 &&
      authSpotifyLogin.body.configured !== undefined,
      'GET /api/auth/spotify/login returns login configuration'
    );

    // 14. Auth Google Login Endpoint
    const authGoogleLogin = await request('/api/auth/google/login');
    assert(
      authGoogleLogin.status === 200 &&
      authGoogleLogin.body.configured !== undefined,
      'GET /api/auth/google/login returns Google OAuth configuration'
    );

    // 15. Auth YT Device Code Endpoint
    const authYtCode = await request('/api/auth/yt/get-code');
    assert(
      authYtCode.status === 200 &&
      authYtCode.body.userCode &&
      authYtCode.body.verificationUrl,
      'GET /api/auth/yt/get-code returns TV userCode and verificationUrl'
    );

    // 16. Auth Session / Status Endpoint
    const authSession = await request('/api/auth/session');
    assert(
      authSession.status === 200 &&
      authSession.body.providers &&
      authSession.body.providers.spotify &&
      authSession.body.providers.google,
      'GET /api/auth/session returns provider connection state'
    );

    // 17. Quick Picks (Scelte rapide) Endpoint
    const quickPicksRes = await request('/api/quick-picks?limit=10');
    assert(
      quickPicksRes.status === 200 &&
      quickPicksRes.body.ok === true &&
      Array.isArray(quickPicksRes.body.items || quickPicksRes.body.data?.items),
      'GET /api/quick-picks returns items array for YouTube Music quick picks'
    );

    // 18. Google Auth Quick Picks Alias Endpoint
    const googleQuickPicksRes = await request('/api/auth/google/quick-picks?limit=5');
    assert(
      googleQuickPicksRes.status === 200 &&
      googleQuickPicksRes.body.ok === true &&
      Array.isArray(googleQuickPicksRes.body.items || googleQuickPicksRes.body.data?.items),
      'GET /api/auth/google/quick-picks returns items array'
    );

  } finally {
    server.close();
  }

  console.log(`\n--- Verification Summary: ${passed} passed, ${failed} failed ---`);
  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Test run failed:', err);
  process.exit(1);
});

