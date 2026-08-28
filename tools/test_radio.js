const { fetchJson } = require('../lib/httpClient');

async function testRadio(videoId, trackTitle = '', artistName = '') {
  console.log(`\n=== Testing Official YouTube Music Radio for ${videoId} (${trackTitle} - ${artistName}) ===`);

  // 1. Official YouTube Music Automix / Radio endpoint: POST /youtubei/v1/next
  const payload = {
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20240101.01.00',
        hl: 'it',
        gl: 'IT'
      }
    },
    videoId,
    playlistId: `RDAMVM${videoId}`,
    isAudioOnly: true
  };

  try {
    const data = await fetchJson('https://music.youtube.com/youtubei/v1/next', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/'
      },
      body: JSON.stringify(payload),
      timeout: 8000
    });

    const radioTracks = [];
    const traverse = (node) => {
      if (!node || typeof node !== 'object') return;
      if (node.playlistPanelVideoRenderer) {
        const item = node.playlistPanelVideoRenderer;
        const title = item.title?.runs?.[0]?.text;
        const artist = item.longBylineText?.runs?.[0]?.text || item.shortBylineText?.runs?.[0]?.text;
        const vId = item.videoId;
        const thumb = item.thumbnail?.thumbnails?.[0]?.url;
        if (title && vId && vId !== videoId) {
          radioTracks.push({ title, artist, videoId: vId, thumb });
        }
      }
      for (const k of Object.keys(node)) traverse(node[k]);
    };

    traverse(data);
    console.log(`Official RDAMVM Radio returned ${radioTracks.length} coherent songs:`);
    radioTracks.slice(0, 10).forEach((t, i) => {
      console.log(`  ${i + 1}. "${t.title}" by ${t.artist} [id: ${t.videoId}]`);
    });
  } catch (err) {
    console.error('Radio fetch failed:', err.message);
  }
}

async function run() {
  // Test 1: The Weeknd - Blinding Lights (4NRXx6U8ABQ or rTuxUAu312Y or 4NRXx6U8ABQ)
  await testRadio('4NRXx6U8ABQ', 'Blinding Lights', 'The Weeknd');

  // Test 2: Sfera Ebbasta - VDLC (WTsmRAfW8w0)
  await testRadio('WTsmRAfW8w0', 'VDLC', 'Sfera Ebbasta');
}
run();

