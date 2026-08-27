const { fetchJson } = require('../lib/httpClient');

async function testCobalt(videoId) {
  const instances = [
    'https://api.cobalt.tools',
    'https://cobalt-api.kwiatekm.com',
    'https://co.wuk.sh'
  ];

  for (const inst of instances) {
    try {
      console.log(`Trying cobalt instance: ${inst}`);
      const res = await fetchJson(`${inst}/api/json`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          url: `https://www.youtube.com/watch?v=${videoId}`,
          downloadMode: 'audio',
          audioFormat: 'mp3',
          audioBitrate: '128'
        }),
        timeout: 5000
      });
      console.log(`Cobalt ${inst} response:`, res);
      if (res && res.url) {
        return res.url;
      }
    } catch (e) {
      console.log(`Cobalt ${inst} error:`, e.message);
    }
  }
}

async function run() {
  await testCobalt('fHI8X4OXluQ');
}

run();

