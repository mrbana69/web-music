const { fetchJson } = require('../lib/httpClient');

async function testAlbumSearch(albumTitle, artistName = '') {
  console.log(`\n=== Testing Album Resolution for "${albumTitle}" by "${artistName}" ===`);
  const query = `${albumTitle} ${artistName}`.trim();
  
  // 1. Search album on Innertube WEB_REMIX
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

  const data = await fetchJson('https://music.youtube.com/youtubei/v1/search', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/'
    },
    body: JSON.stringify(payload)
  });

  const albumsFound = [];
  const traverse = (node) => {
    if (!node || typeof node !== 'object') return;
    if (node.musicResponsiveListItemRenderer) {
      const item = node.musicResponsiveListItemRenderer;
      const flex = item.flexColumns || [];
      const title = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const artist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
      const browseId = item.navigationEndpoint?.browseEndpoint?.browseId;
      const thumb = item.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url;
      if (title && browseId) {
        albumsFound.push({ title, artist, browseId, thumb });
      }
    }
    for (const k of Object.keys(node)) traverse(node[k]);
  };

  traverse(data);
  console.log(`Found ${albumsFound.length} albums:`, albumsFound.slice(0, 3));

  if (albumsFound.length > 0) {
    const browseId = albumsFound[0].browseId;
    console.log(`\nFetching full tracklist for album browseId: ${browseId}`);
    const browsePayload = {
      context: {
        client: {
          clientName: 'WEB_REMIX',
          clientVersion: '1.20240101.01.00',
          hl: 'it',
          gl: 'IT'
        }
      },
      browseId
    };

    const browseRes = await fetchJson('https://music.youtube.com/youtubei/v1/browse', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/'
      },
      body: JSON.stringify(browsePayload)
    });

    const tracks = [];
    const traverseTracks = (node) => {
      if (!node || typeof node !== 'object') return;
      if (node.musicResponsiveListItemRenderer) {
        const item = node.musicResponsiveListItemRenderer;
        const flex = item.flexColumns || [];
        const tTitle = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const tArtist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
        const vId = item.playlistItemData?.videoId || flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId;
        if (tTitle) {
          tracks.push({ title: tTitle, artist: tArtist, videoId: vId });
        }
      }
      for (const k of Object.keys(node)) traverseTracks(node[k]);
    };

    traverseTracks(browseRes);
    console.log(`Album tracklist extracted (${tracks.length} tracks):`);
    tracks.forEach((t, i) => console.log(`  ${i+1}. ${t.title} - ${t.artist} (${t.videoId || 'no-id'})`));
  }
}

async function run() {
  await testAlbumSearch('After Hours', 'The Weeknd');
  await testAlbumSearch('X2VR', 'Sfera Ebbasta');
}
run();
