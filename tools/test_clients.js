const { fetchJson } = require('../lib/httpClient');

async function testClients(videoId) {
  const clients = [
    {
      name: 'IOS',
      client: {
        clientName: 'IOS',
        clientVersion: '19.29.1',
        deviceMake: 'Apple',
        deviceModel: 'iPhone16,2',
        hl: 'en',
        gl: 'US'
      }
    },
    {
      name: 'ANDROID',
      client: {
        clientName: 'ANDROID',
        clientVersion: '19.29.35',
        androidSdkVersion: 34,
        hl: 'en',
        gl: 'US'
      }
    },
    {
      name: 'TV_EMBEDDED',
      client: {
        clientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
        clientVersion: '2.0',
        hl: 'en',
        gl: 'US'
      }
    },
    {
      name: 'WEB_EMBEDDED',
      client: {
        clientName: 'WEB_EMBEDDED_PLAYER',
        clientVersion: '1.20240801.01.00',
        hl: 'en',
        gl: 'US'
      }
    },
    {
      name: 'WEB_REMIX',
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20240801.01.00',
        hl: 'en',
        gl: 'US'
      }
    }
  ];

  for (const c of clients) {
    try {
      const payload = {
        context: { client: c.client },
        videoId
      };
      const res = await fetchJson('https://www.youtube.com/youtubei/v1/player?prettyPrint=false', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15',
          'Origin': 'https://www.youtube.com'
        },
        body: JSON.stringify(payload),
        timeout: 5000
      });

      const formats = res?.streamingData?.adaptiveFormats || res?.streamingData?.formats || [];
      const audioFormats = formats.filter(f => f.mimeType && f.mimeType.startsWith('audio/'));
      const directAudio = audioFormats.find(f => Boolean(f.url));
      console.log(`Client [${c.name}]: total formats=${formats.length}, audio formats=${audioFormats.length}, with direct url=${Boolean(directAudio)}`);
      if (directAudio) {
        console.log(`  -> Found direct audio URL (${directAudio.mimeType}, bitrate: ${directAudio.bitrate})!`);
      }
    } catch (e) {
      console.log(`Client [${c.name}] failed:`, e.message);
    }
  }
}

testClients('4NRXx6U8ABQ');

