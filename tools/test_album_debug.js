const { fetchJson } = require('../lib/httpClient');

async function debugAlbum(albumName, artistName = '') {
  console.log(`\n======================================================`);
  console.log(`DEBUGGING ALBUM: "${albumName}" by "${artistName}"`);
  console.log(`======================================================`);

  // Step 1: Search album
  const payload = {
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20240101.01.00',
        hl: 'it',
        gl: 'IT'
      }
    },
    query: `${albumName} ${artistName}`.trim(),
    params: 'EgWKAQIYAWoMEAMQBBAJEA4QChAF' // filter: albums
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

  const albumsFound = [];
  const traverse = (node) => {
    if (!node || typeof node !== 'object') return;
    if (node.musicResponsiveListItemRenderer) {
      const item = node.musicResponsiveListItemRenderer;
      const flex = item.flexColumns || [];
      const title = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const artist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const browseId = item.navigationEndpoint?.browseEndpoint?.browseId ||
                       flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.browseEndpoint?.browseId;
      const rawThumb = item.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url;
      if (title && browseId) {
        albumsFound.push({ title, artist, browseId, rawThumb });
      }
    }
    for (const k of Object.keys(node)) traverse(node[k]);
  };

  traverse(searchData);
  console.log(`Search returned ${albumsFound.length} albums:`);
  albumsFound.slice(0, 5).forEach((a, i) => console.log(`  ${i+1}. "${a.title}" by ${a.artist} [browseId: ${a.browseId}]`));

  if (albumsFound.length === 0) return;

  const target = albumsFound[0];
  console.log(`\nBrowsing selected album: "${target.title}" (browseId: ${target.browseId})`);

  const browsePayload = {
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20240101.01.00',
        hl: 'it',
        gl: 'IT'
      }
    },
    browseId: target.browseId
  };

  const browseRes = await fetchJson('https://music.youtube.com/youtubei/v1/browse', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/'
    },
    body: JSON.stringify(browsePayload),
    timeout: 5000
  });

  const tracks = [];
  const traverseTracks = (node) => {
    if (!node || typeof node !== 'object') return;
    if (node.musicResponsiveListItemRenderer) {
      const item = node.musicResponsiveListItemRenderer;
      const flex = item.flexColumns || [];
      const tTitle = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const tArtist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const vId = item.playlistItemData?.videoId ||
                  flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId ||
                  item.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint?.watchEndpoint?.videoId;
      if (tTitle) {
        tracks.push({ title: tTitle, artist: tArtist, videoId: vId });
      }
    }
    for (const k of Object.keys(node)) traverseTracks(node[k]);
  };

  traverseTracks(browseRes);
  console.log(`Extracted ${tracks.length} tracks:`);
  tracks.slice(0, 15).forEach((t, i) => console.log(`  ${i+1}. "${t.title}" by ${t.artist || 'Unknown'} [id: ${t.videoId}]`));
}

async function run() {
  await debugAlbum('X2VR', 'Sfera Ebbasta');
  await debugAlbum('Rockstar', 'Sfera Ebbasta');
  await debugAlbum('After Hours', 'The Weeknd');
}
run();

