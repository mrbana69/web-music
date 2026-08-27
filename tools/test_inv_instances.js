const { fetchJson } = require('../lib/httpClient');

async function testInvidiousInstances(videoId) {
  const instances = [
    'https://invidious.flokinet.to',
    'https://invidious.projectsegfau.lt',
    'https://inv.vern.cc',
    'https://invidious.drgns.space',
    'https://invidious.lunar.icu',
    'https://yt.artemislena.eu',
    'https://invidious.privacydev.net'
  ];

  for (const inst of instances) {
    try {
      console.log(`Checking ${inst}...`);
      const data = await fetchJson(`${inst}/api/v1/videos/${videoId}`, { timeout: 4000 });
      const formats = data?.adaptiveFormats?.filter(f => f.type && f.type.startsWith('audio/')) || [];
      console.log(`[${inst}] Found audio formats:`, formats.length);
      if (formats.length > 0) {
        console.log(`[${inst}] Format 0:`, formats[0].url ? formats[0].url.substring(0, 70) : 'No url');
        return formats[0].url;
      }
    } catch (e) {
      console.log(`[${inst}] Error:`, e.message);
    }
  }
}

async function run() {
  await testInvidiousInstances('fHI8X4OXluQ');
}

run();
