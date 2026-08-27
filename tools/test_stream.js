const { fetchJson } = require('../lib/httpClient');

async function testInnertubeAndroid(videoId) {
  try {
    const payload = {
      context: {
        client: {
          clientName: 'ANDROID',
          clientVersion: '19.09.37',
          androidSdkVersion: 30,
          hl: 'en',
          gl: 'US'
        }
      },
      videoId
    };

    const data = await fetchJson('https://www.youtube.com/youtubei/v1/player', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'com.google.android.youtube/19.09.37 (Linux; U; Android 11; US) gzip'
      },
      body: JSON.stringify(payload),
      timeout: 6000
    });

    const formats = data?.streamingData?.adaptiveFormats || [];
    const audioFormats = formats.filter(f => f.mimeType && f.mimeType.startsWith('audio/'));
    console.log('Innertube Android audio formats found:', audioFormats.length);
    if (audioFormats.length > 0) {
      console.log('Sample format URL exists:', Boolean(audioFormats[0].url));
      if (audioFormats[0].url) {
        console.log('URL domain:', new URL(audioFormats[0].url).hostname);
      }
    }
  } catch (err) {
    console.error('Innertube android test failed:', err.message);
  }
}

async function testInvidious(videoId) {
  const instances = [
    'https://inv.tux.pizza',
    'https://invidious.nerdvpn.de',
    'https://vid.puffyan.us',
    'https://invidious.flokinet.to',
    'https://invidious.projectsegfau.lt'
  ];

  for (const inst of instances) {
    try {
      console.log(`Trying Invidious instance: ${inst}`);
      const data = await fetchJson(`${inst}/api/v1/videos/${videoId}`, { timeout: 4000 });
      const audioStreams = data?.adaptiveFormats?.filter(f => f.type && f.type.startsWith('audio/')) || [];
      console.log(`Found ${audioStreams.length} audio formats on ${inst}`);
      if (audioStreams.length > 0 && audioStreams[0].url) {
        console.log('Invidious stream URL success!');
        return;
      }
    } catch (e) {
      console.log(`Failed on ${inst}: ${e.message}`);
    }
  }
}

async function run() {
  const videoId = 'dQw4w9WgXcQ';
  console.log('Testing Innertube Android...');
  await testInnertubeAndroid(videoId);
  console.log('Testing Invidious...');
  await testInvidious(videoId);
}

run();

