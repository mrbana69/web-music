const { fetchJson } = require('../lib/httpClient');

async function testAlbumMatch(cleanTitle, artistName = '') {
  console.log(`\n=== Testing Album Match for "${cleanTitle}" by "${artistName}" ===`);
  const query = `${cleanTitle} ${artistName}`.trim();
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
    params: 'EgWKAQIYAWoMEAMQBBAJEA4QChAF' // filter for albums
  };

  const searchData = await fetchJson('https://music.youtube.com/youtubei/v1/search', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/'
    },
    body: JSON.stringify(payload),
    timeout: 5000
  });

  const candidates = [];
  const traverse = (node) => {
    if (!node || typeof node !== 'object') return;
    if (node.musicResponsiveListItemRenderer) {
      const item = node.musicResponsiveListItemRenderer;
      const flex = item.flexColumns || [];
      const t = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const a = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const bId = item.navigationEndpoint?.browseEndpoint?.browseId;
      const rawThumb = item.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url;
      if (t && bId) {
        candidates.push({ title: t, artist: a, browseId: bId, thumb: rawThumb });
      }
    }
    for (const k of Object.keys(node)) traverse(node[k]);
  };

  traverse(searchData);
  console.log(`Found ${candidates.length} candidate albums:`);
  candidates.slice(0, 5).forEach((c, i) => console.log(`  ${i+1}. "${c.title}" by ${c.artist} (browseId: ${c.browseId})`));

  // Find exact or closest match
  const targetTitle = cleanTitle.toLowerCase();
  let best = candidates.find(c => c.title.toLowerCase() === targetTitle);
  if (!best) {
    best = candidates.find(c => c.title.toLowerCase().includes(targetTitle) || targetTitle.includes(c.title.toLowerCase()));
  }
  if (!best && candidates.length > 0) {
    best = candidates[0];
  }

  console.log('BEST MATCH SELECTED:', best ? `"${best.title}" by ${best.artist} (${best.browseId})` : 'None');
}

async function run() {
  await testAlbumMatch('Rockstar', 'Sfera Ebbasta');
  await testAlbumMatch('Famoso', 'Sfera Ebbasta');
  await testAlbumMatch('Sirio', 'Lazza');
  await testAlbumMatch('Starboy', 'The Weeknd');
}
run();

