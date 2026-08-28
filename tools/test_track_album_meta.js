const { fetchJson } = require('../lib/httpClient');

async function testSongMetadata(query) {
  console.log(`\n=== Testing Song Metadata extraction for "${query}" ===`);
  const payload = {
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20240101.01.00',
        hl: 'it',
        gl: 'IT'
      }
    },
    query,
    params: 'EgWKAQIIAWoMEAMQBBAJEA4QChAF' // filter: songs
  };

  const data = await fetchJson('https://music.youtube.com/youtubei/v1/search', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/'
    },
    body: JSON.stringify(payload),
    timeout: 5000
  });

  const songs = [];
  const traverse = (node) => {
    if (!node || typeof node !== 'object') return;
    if (node.musicResponsiveListItemRenderer) {
      const item = node.musicResponsiveListItemRenderer;
      const flex = item.flexColumns || [];
      const title = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const vId = item.playlistItemData?.videoId || flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId;
      const runs = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
      const runTexts = runs.map(r => ({ text: r.text, browseId: r.navigationEndpoint?.browseEndpoint?.browseId }));
      if (title && vId) {
        songs.push({ title, vId, runTexts });
      }
    }
    for (const k of Object.keys(node)) traverse(node[k]);
  };

  traverse(data);
  console.log(`Found ${songs.length} songs:`);
  songs.slice(0, 3).forEach((s, i) => {
    console.log(`  ${i+1}. "${s.title}" (${s.vId})`);
    console.log('     Byline runs:', JSON.stringify(s.runTexts));
  });
}

async function run() {
  await testSongMetadata('Blinding Lights The Weeknd');
  await testSongMetadata('VDLC Sfera Ebbasta');
  await testSongMetadata('Starboy The Weeknd');
}
run();

