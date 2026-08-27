const { fetchJson } = require('../lib/httpClient');

async function testNativeInnertubeAudio(videoId) {
  try {
    const payload = {
      context: {
        client: {
          clientName: 'ANDROID_VR',
          clientVersion: '1.50.28',
          androidSdkVersion: 30,
          hl: 'en',
          gl: 'US'
        }
      },
      videoId
    };

    const res = await fetchJson('https://www.youtube.com/youtubei/v1/player?prettyPrint=false', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Origin': 'https://music.youtube.com'
      },
      body: JSON.stringify(payload),
      timeout: 6000
    });

    const formats = res?.streamingData?.adaptiveFormats || [];
    const audioFormats = formats.filter(f => f.mimeType && f.mimeType.startsWith('audio/'));
    
    // Sort by bitrate descending to get best quality audio
    const sorted = audioFormats.sort((a, b) => (Number(b.bitrate) || 0) - (Number(a.bitrate) || 0));
    const bestAudio = sorted[0];

    if (bestAudio && bestAudio.url) {
      console.log(`SUCCESS for ${videoId}:`, new URL(bestAudio.url).hostname, bestAudio.mimeType, bestAudio.bitrate);
      return bestAudio;
    } else {
      console.log(`No audio URL found for ${videoId}`);
    }
  } catch (err) {
    console.error(`Failed for ${videoId}:`, err.message);
  }
}

async function run() {
  await testNativeInnertubeAudio('dQw4w9WgXcQ');
  await testNativeInnertubeAudio('fHI8X4OXluQ');
  await testNativeInnertubeAudio('9bZkp7q19f0');
}

run();
