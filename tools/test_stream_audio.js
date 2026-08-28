const { fetchJson } = require('../lib/httpClient');

async function testAudioStreamSources(videoId) {
  console.log(`\n=== Testing Audio Stream Sources for videoId: ${videoId} ===`);

  // Source 1: Direct YouTube Innertube with TVHTML5 / Android clients
  const innertubeEndpoint = 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';
  
  const clients = [
    {
      name: 'WEB_REMIX',
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20240801.01.00',
        hl: 'it',
        gl: 'IT'
      }
    },
    {
      name: 'TV_EMBEDDED',
      client: {
        clientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
        clientVersion: '2.0',
        hl: 'it',
        gl: 'IT'
      }
    }
  ];

  for (const c of clients) {
    try {
      const payload = {
        context: { client: c.client },
        videoId
      };
      const res = await fetchJson(innertubeEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/'
        },
        body: JSON.stringify(payload),
        timeout: 5000
      });
      const formats = res?.streamingData?.adaptiveFormats || res?.streamingData?.formats || [];
      const audioFormats = formats.filter(f => f.mimeType && f.mimeType.startsWith('audio/'));
      console.log(`Innertube [${c.name}]: ${audioFormats.length} audio formats found.`);
    } catch (e) {
      console.log(`Innertube [${c.name}] failed:`, e.message);
    }
  }

  // Source 2: Piped API audio instances
  const pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://api.piped.private.coffee',
    'https://piped-api.garudalinux.org'
  ];

  for (const inst of pipedInstances) {
    try {
      const pRes = await fetchJson(`${inst}/streams/${videoId}`, { timeout: 4000 });
      const audioStreams = pRes?.audioStreams || [];
      console.log(`Piped [${inst}]: ${audioStreams.length} audio streams available.`);
      if (audioStreams.length > 0) {
        console.log(`  Top stream URL: ${audioStreams[0].url.slice(0, 70)}... (${audioStreams[0].mimeType}, bitrate: ${audioStreams[0].bitrate})`);
      }
    } catch (e) {
      console.log(`Piped [${inst}] failed:`, e.message);
    }
  }
}

testAudioStreamSources('4NRXx6U8ABQ');

