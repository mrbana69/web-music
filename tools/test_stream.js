const streamResolutionService = require('../services/streamResolutionService');

async function testStreamProxy(videoId) {
  console.log(`\n=== Testing Stream Resolution for videoId: ${videoId} ===`);
  const streamInfo = await streamResolutionService.resolveStreamUrl(videoId);
  console.log('Resolved Stream:', {
    source: streamInfo.source,
    mimeType: streamInfo.mimeType,
    hasUrl: Boolean(streamInfo.directUrl),
    urlPreview: streamInfo.directUrl ? streamInfo.directUrl.slice(0, 80) + '...' : null
  });

  if (streamInfo.directUrl && streamInfo.directUrl.startsWith('http')) {
    console.log('Testing Range chunk fetch from Google CDN...');
    const res = await fetch(streamInfo.directUrl, {
      headers: {
        'Range': 'bytes=0-1024',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/'
      }
    });
    console.log('Google CDN Response Status:', res.status);
    console.log('Content-Type:', res.headers.get('content-type'));
    console.log('Content-Range:', res.headers.get('content-range'));
    const chunk = await res.arrayBuffer();
    console.log(`Successfully received chunk of ${chunk.byteLength} bytes!`);
  }
}

async function run() {
  await testStreamProxy('4NRXx6U8ABQ'); // Blinding Lights
  await testStreamProxy('WTsmRAfW8w0'); // Sfera Ebbasta VDLC
}
run();
