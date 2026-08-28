const config = require('../config/env');
const cacheService = require('./cacheService');
const { fetchJson, fetchText } = require('../lib/httpClient');

class YouTubeMusicService {
  constructor() {
    this.cookie = config.youtubeMusic.cookie;
    this.innertubeEndpoint = 'https://music.youtube.com/youtubei/v1';
  }

  parseDuration(durationStr = '') {
    if (!durationStr || typeof durationStr !== 'string') return 0;
    const parts = durationStr.split(':').map((p) => parseInt(p.trim(), 10));
    if (parts.some(isNaN)) return 0;

    if (parts.length === 2) {
      return (parts[0] * 60 + parts[1]) * 1000;
    } else if (parts.length === 3) {
      return (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000;
    }
    return 0;
  }

  /**
   * Search YouTube Music using Innertube WEB_REMIX client
   */
  async searchInnertube(query, filterType = 'songs') {
    // Parameter filter: songs vs albums vs artists
    let params = 'EgWKAQIIAWoQEAMQBBAJEAoQCxAEEAkQChAA'; // default songs
    if (filterType === 'artists') {
      params = 'EgWKAQIIAmoQEAMQBBAJEAoQCxAEEAkQChAA';
    } else if (filterType === 'albums') {
      params = 'EgWKAQIBAmoQEAMQBBAJEAoQCxAEEAkQChAA';
    }

    const payload = {
      context: {
        client: {
          clientName: 'WEB_REMIX',
          clientVersion: '1.20240101.01.00',
          hl: 'en',
          gl: 'US'
        }
      },
      query,
      params
    };

    const headers = {
      'Content-Type': 'application/json',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/'
    };

    if (this.cookie) {
      headers['Cookie'] = this.cookie;
    }

    try {
      const data = await fetchJson(`${this.innertubeEndpoint}/search`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload)
      });

      return this.parseInnertubeResults(data, filterType);
    } catch (err) {
      console.warn('[YouTubeMusicService] Innertube search failed, trying web fallback:', err.message);
      return [];
    }
  }

  parseInnertubeResults(data, filterType = 'songs') {
    const results = [];
    if (!data) return results;

    const traverse = (node) => {
      if (!node || typeof node !== 'object') return;

      if (node.musicResponsiveListItemRenderer) {
        const item = node.musicResponsiveListItemRenderer;
        const flexColumns = item.flexColumns || [];

        // Title
        const titleText = flexColumns[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || '';

        // Subtitle runs (Artist, Album, Duration)
        const subRuns = flexColumns[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
        const artist = subRuns[0]?.text || 'Unknown Artist';
        const durationStr = subRuns[subRuns.length - 1]?.text || '';
        const durationMs = this.parseDuration(durationStr);

        // Video / Browse ID
        const videoId =
          item.playlistItemData?.videoId ||
          item.doubleTapCommand?.watchEndpoint?.videoId ||
          item.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint?.watchEndpoint?.videoId ||
          '';

        const browseId =
          item.navigationEndpoint?.browseEndpoint?.browseId ||
          flexColumns[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.browseEndpoint?.browseId ||
          '';

        const rawThumb = item.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url || '';
        // High quality thumbnail
        const thumb = rawThumb.replace(/=w\d+-h\d+/, '=w544-h544');

        const finalId = videoId || browseId || `yt_${Buffer.from(titleText + artist).toString('hex').substring(0, 12)}`;

        if (titleText) {
          results.push({
            id: finalId,
            videoId: videoId || finalId,
            browseId,
            title: titleText,
            name: titleText,
            artist: typeof artist === 'string' ? { id: `art_${finalId}`, name: artist, picture: thumb } : artist,
            artists: [{ id: `art_${finalId}`, name: typeof artist === 'string' ? artist : artist?.name || 'Artist' }],
            album: { id: `alb_${finalId}`, title: titleText, cover: thumb },
            picture: thumb,
            cover: thumb,
            duration: Math.round(durationMs / 1000) || 210,
            duration_ms: durationMs || 210000,
            thumbnail: thumb,
            source: 'ytmusic'
          });
        }
      }

      for (const key of Object.keys(node)) {
        traverse(node[key]);
      }
    };

    traverse(data);
    return results;
  }

  /**
   * Search YouTube Web client (HTML / InitialData scrape) fallback
   */
  async searchWeb(query) {
    const cacheKey = `yt_web_search_${encodeURIComponent(query)}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    try {
      const url = `https://www.youtube.com/results?search_query=${encodeURIComponent(query)}&sp=EgIQAQ%253D%253D`;
      const html = await fetchText(url);

      const jsonMatch = html.match(/ytInitialData\s*=\s*({.+?});<\/script>/);
      if (!jsonMatch || !jsonMatch[1]) return [];

      const data = JSON.parse(jsonMatch[1]);
      const results = [];

      const traverse = (node) => {
        if (!node || typeof node !== 'object') return;

        if (node.videoRenderer) {
          const v = node.videoRenderer;
          const videoId = v.videoId;
          const title = v.title?.runs?.[0]?.text || '';
          const artist = v.ownerText?.runs?.[0]?.text || 'Unknown Artist';
          const durationStr = v.lengthText?.simpleText || '';
          const durationMs = this.parseDuration(durationStr);
          const rawThumb = v.thumbnail?.thumbnails?.[0]?.url || '';
          const thumb = rawThumb.replace(/hqdefault/, 'maxresdefault');

          if (videoId && title) {
            results.push({
              id: videoId,
              videoId,
              title,
              name: title,
              artist: { id: `art_${videoId}`, name: artist, picture: thumb },
              artists: [{ id: `art_${videoId}`, name: artist }],
              album: { id: `alb_${videoId}`, title, cover: thumb },
              picture: thumb,
              cover: thumb,
              duration: Math.round(durationMs / 1000) || 210,
              duration_ms: durationMs || 210000,
              thumbnail: thumb,
              source: 'youtube-web'
            });
          }
        }

        for (const key of Object.keys(node)) {
          traverse(node[key]);
        }
      };

      traverse(data);
      cacheService.set(cacheKey, results, 1800);
      return results;
    } catch (err) {
      console.warn('[YouTubeMusicService] Web search fallback failed:', err.message);
      return [];
    }
  }

  /**
   * Search YouTube Music for tracks, artists, and albums
   */
  async search(query, type = 'track', limit = 25) {
    if (!query) return null;

    const cacheKey = `yt_full_search_${type}_${encodeURIComponent(query)}_${limit}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const filter = type === 'artist' ? 'artists' : type === 'album' ? 'albums' : 'songs';
    let items = await this.searchInnertube(query, filter);

    if (!items || items.length === 0) {
      items = await this.searchWeb(query);
    }

    const tracks = items.map((item) => ({
      id: item.videoId || item.id,
      title: item.title,
      duration: item.duration,
      duration_ms: item.duration_ms,
      artist: typeof item.artist === 'string' ? { id: `art_${item.id}`, name: item.artist, picture: item.thumbnail } : item.artist,
      artists: item.artists || [{ name: typeof item.artist === 'string' ? item.artist : item.artist?.name || 'Artist' }],
      album: item.album || { id: `alb_${item.id}`, title: item.title, cover: item.thumbnail },
      source: 'youtube'
    }));

    const artists = [
      ...new Set(items.map((i) => (typeof i.artist === 'string' ? i.artist : i.artist?.name || '')).filter(Boolean))
    ].map((name, idx) => ({
      id: `art_yt_${idx}_${Buffer.from(name).toString('hex').substring(0, 8)}`,
      name,
      picture: items.find((i) => (typeof i.artist === 'string' ? i.artist : i.artist?.name) === name)?.thumbnail || '',
      popularity: 85,
      source: 'youtube'
    }));

    const albums = items.slice(0, 10).map((i, idx) => ({
      id: `alb_yt_${idx}_${i.id}`,
      title: i.title,
      cover: i.thumbnail || i.cover,
      artist: typeof i.artist === 'string' ? { name: i.artist } : i.artist,
      artists: i.artists || [{ name: typeof i.artist === 'string' ? i.artist : i.artist?.name }],
      releaseDate: '2024',
      year: '2024',
      type: 'ALBUM',
      source: 'youtube'
    }));

    const resultItems = type === 'artist' ? artists : type === 'album' ? albums : tracks;

    const searchResult = {
      items: resultItems.slice(0, limit),
      tracks: { items: tracks.slice(0, limit) },
      artists: { items: artists.slice(0, limit) },
      albums: { items: albums.slice(0, limit) }
    };

    cacheService.set(cacheKey, searchResult, 1800);
    return searchResult;
  }

  /**
   * Search candidate songs for fuzzy matching
   */
  async searchCandidates(query) {
    const res = await this.search(query, 'track', 15);
    return res?.tracks?.items || [];
  }

  /**
   * Get artist discography and top tracks from YouTube Music
   */
  async getArtist(artistNameOrId) {
    if (!artistNameOrId) return null;
    let cleanName = String(artistNameOrId).trim();
    cleanName = cleanName.replace(/^art_yt_\d+_/, '');
    if (cleanName.startsWith('art_')) {
      cleanName = cleanName.replace(/^art_/, '');
    }

    // If cleanName is a video ID, extract artist name from track info
    if (/^[a-zA-Z0-9_-]{11}$/.test(cleanName)) {
      const info = await this.getTrackInfo(cleanName);
      if (info && info.artist && info.artist.name) {
        cleanName = info.artist.name;
      }
    }

    const cacheKey = `yt_artist_v2_${encodeURIComponent(cleanName)}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    // 1. Search for the artist profile directly
    let artistPic = '';
    try {
      const artistSearch = await this.search(cleanName, 'artist', 5);
      const matchedArtist = artistSearch?.artists?.items?.[0];
      if (matchedArtist) {
        cleanName = matchedArtist.name || cleanName;
        artistPic = matchedArtist.picture || '';
      }
    } catch (e) {}

    // 2. Search top songs of this artist
    const songResults = await this.search(`${cleanName}`, 'track', 25);
    let tracks = songResults?.tracks?.items || [];
    
    // Filter tracks by artist similarity
    tracks = tracks.filter(t => {
      const tArtist = (t.artist?.name || '').toLowerCase();
      const target = cleanName.toLowerCase();
      return tArtist.includes(target) || target.includes(tArtist) || t.title.toLowerCase().includes(target);
    });

    if (tracks.length === 0) {
      tracks = songResults?.tracks?.items || [];
    }

    if (!artistPic) {
      artistPic = tracks[0]?.album?.cover || tracks[0]?.artist?.picture || '';
    }

    const artist = {
      id: `art_${encodeURIComponent(cleanName)}`,
      name: cleanName,
      picture: artistPic,
      genres: ['Pop', 'Music'],
      popularity: 90,
      source: 'youtube'
    };

    // 3. Search albums of this artist
    let albums = [];
    try {
      const albumSearch = await this.search(`${cleanName}`, 'album', 10);
      albums = albumSearch?.albums?.items || [];
    } catch (e) {}

    if (albums.length === 0) {
      albums = tracks.slice(0, 8).map((t, idx) => ({
        id: `alb_${t.id}`,
        title: t.title,
        cover: t.album?.cover || artistPic,
        artist,
        releaseDate: '2024',
        type: idx % 2 === 0 ? 'ALBUM' : 'SINGLE',
        source: 'youtube'
      }));
    }

    const result = {
      artist,
      tracks,
      albums
    };

    cacheService.set(cacheKey, result, 3600);
    return result;
  }

  /**
   * Get album details and full tracklist from YouTube Music
   */
  async getAlbum(albumQuery, artistName = '') {
    if (!albumQuery) return null;
    let cleanTitle = String(albumQuery).trim().replace(/^alb_/, '');

    // If cleanTitle is an 11-char video ID, resolve track info first
    if (/^[a-zA-Z0-9_-]{11}$/.test(cleanTitle) && !cleanTitle.startsWith('MPREb_') && !cleanTitle.startsWith('OLAK5uy_')) {
      const info = await this.getTrackInfo(cleanTitle);
      if (info) {
        cleanTitle = info.album?.title || info.title;
        if (!artistName && info.artist?.name) artistName = info.artist.name;
      }
    }

    const cacheKey = `yt_album_v2_${encodeURIComponent(cleanTitle)}_${encodeURIComponent(artistName || '')}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    let browseId = cleanTitle.startsWith('MPREb_') || cleanTitle.startsWith('OLAK5uy_') ? cleanTitle : null;
    let albumCover = '';
    let resolvedTitle = cleanTitle;
    let resolvedArtist = artistName || 'Artist';

    // If we don't have a direct browseId, search for the album
    if (!browseId) {
      try {
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
          params: 'EgWKAQIYAWoMEAMQBBAJEA4QChAF'
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

        if (candidates.length > 0) {
          const targetTitle = cleanTitle.toLowerCase();
          let best = candidates.find(c => c.title.toLowerCase() === targetTitle);
          if (!best) {
            best = candidates.find(c => c.title.toLowerCase().includes(targetTitle) || targetTitle.includes(c.title.toLowerCase()));
          }
          if (!best) {
            best = candidates[0];
          }

          if (best) {
            browseId = best.browseId;
            resolvedTitle = best.title;
            if (best.artist && best.artist !== 'Album' && best.artist !== 'Singolo') {
              resolvedArtist = best.artist;
            }
            if (best.thumb) {
              albumCover = best.thumb.replace(/=w\d+-h\d+/, '=w544-h544');
            }
          }
        }
      } catch (e) {
        console.warn('[YouTubeMusicService] Album search failed:', e.message);
      }
    }

    let tracks = [];

    // If we found a browseId, fetch the full official tracklist
    if (browseId) {
      try {
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
          body: JSON.stringify(browsePayload),
          timeout: 5000
        });

        const traverseHeader = (node) => {
          if (!node || typeof node !== 'object') return;
          if (node.musicDetailHeaderRenderer) {
            const h = node.musicDetailHeaderRenderer;
            const title = h.title?.runs?.[0]?.text;
            const artist = h.subtitle?.runs?.[0]?.text;
            const rawThumb = h.thumbnail?.croppedSquareThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url;
            if (title) resolvedTitle = title;
            if (artist) resolvedArtist = artist;
            if (rawThumb) albumCover = rawThumb.replace(/=w\d+-h\d+/, '=w544-h544');
          }
          for (const k of Object.keys(node)) traverseHeader(node[k]);
        };
        traverseHeader(browseRes);

        const traverseTracks = (node) => {
          if (!node || typeof node !== 'object') return;
          if (node.musicResponsiveListItemRenderer) {
            const item = node.musicResponsiveListItemRenderer;
            const flex = item.flexColumns || [];
            const tTitle = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
            const tArtist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || resolvedArtist;
            const vId = item.playlistItemData?.videoId || flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId;
            if (tTitle && vId) {
              tracks.push({
                id: vId,
                videoId: vId,
                title: tTitle,
                artist: { id: `art_${encodeURIComponent(tArtist)}`, name: tArtist, picture: albumCover },
                artists: [{ id: `art_${encodeURIComponent(tArtist)}`, name: tArtist }],
                album: { id: browseId, title: resolvedTitle, cover: albumCover },
                duration: 210,
                duration_ms: 210000,
                source: 'youtube-album'
              });
            }
          }
          for (const k of Object.keys(node)) traverseTracks(node[k]);
        };
        traverseTracks(browseRes);
      } catch (e) {
        console.warn('[YouTubeMusicService] Browse album failed:', e.message);
      }
    }

    // Fallback to track search if browse had 0 tracks
    if (tracks.length === 0) {
      const searchRes = await this.search(`${resolvedTitle} ${resolvedArtist}`, 'track', 15);
      tracks = searchRes?.tracks?.items || [];
      if (!albumCover && tracks[0]?.album?.cover) {
        albumCover = tracks[0].album.cover;
      }
    }

    const album = {
      id: browseId || `alb_${encodeURIComponent(resolvedTitle)}`,
      browseId,
      title: resolvedTitle,
      name: resolvedTitle,
      cover: albumCover,
      releaseDate: '2024',
      artist: { id: `art_${encodeURIComponent(resolvedArtist)}`, name: resolvedArtist, picture: albumCover },
      artists: [{ id: `art_${encodeURIComponent(resolvedArtist)}`, name: resolvedArtist }],
      itemCount: tracks.length,
      source: 'youtube'
    };

    const result = {
      album,
      tracks,
      items: tracks.map(t => ({ item: t }))
    };

    cacheService.set(cacheKey, result, 3600);
    return result;
  }

  /**
   * Get real similar artists based on YouTube Music recommendations
   */
  async getSimilarArtists(artistNameOrId) {
    if (!artistNameOrId) return [];
    let cleanName = String(artistNameOrId).trim().replace(/^art_/, '');
    if (/^[a-zA-Z0-9_-]{11}$/.test(cleanName)) {
      const info = await this.getTrackInfo(cleanName);
      if (info?.artist?.name) cleanName = info.artist.name;
    }

    const cacheKey = `yt_similar_${encodeURIComponent(cleanName)}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const radioTracks = await this.getRecommendations(cleanName, 30);
    const seen = new Set([cleanName.toLowerCase()]);
    const similar = [];

    for (const t of radioTracks) {
      const aName = t.artist?.name;
      if (aName && !seen.has(aName.toLowerCase())) {
        seen.add(aName.toLowerCase());
        similar.push({
          id: `art_${encodeURIComponent(aName)}`,
          name: aName,
          picture: t.artist?.picture || t.album?.cover || '',
          genres: ['Pop', 'Music']
        });
      }
    }

    const result = similar.slice(0, 10);
    cacheService.set(cacheKey, result, 3600);
    return result;
  }

  /**
   * Get related tracks / recommendations from YouTube Music using official RDAMVM Automix
   */
  async getRecommendations(seedIdOrQuery, limit = 15) {
    if (!seedIdOrQuery) return [];
    let videoId = null;
    let cleanId = String(seedIdOrQuery).trim().replace(/^mix_/, '').replace(/^track_/, '');

    // 1. If cleanId is an 11-char video ID
    if (/^[a-zA-Z0-9_-]{11}$/.test(cleanId)) {
      videoId = cleanId;
    } else {
      // 2. Resolve query to real video ID
      try {
        const searchRes = await this.search(cleanId, 'track', 1);
        videoId = searchRes?.tracks?.items?.[0]?.videoId || searchRes?.tracks?.items?.[0]?.id;
      } catch (e) {}
    }

    if (!videoId) {
      const searchRes = await this.search(cleanId || 'top hits', 'track', limit);
      return searchRes?.tracks?.items || [];
    }

    const cacheKey = `yt_rec_automix_${videoId}_${limit}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    // 3. Fetch official YouTube Music Automix / Radio queue (RDAMVM)
    try {
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

      const data = await fetchJson('https://music.youtube.com/youtubei/v1/next', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/'
        },
        body: JSON.stringify(payload),
        timeout: 6000
      });

      const radioTracks = [];
      const traverse = (node) => {
        if (!node || typeof node !== 'object') return;
        if (node.playlistPanelVideoRenderer) {
          const item = node.playlistPanelVideoRenderer;
          const title = item.title?.runs?.[0]?.text;
          const artistName = item.longBylineText?.runs?.[0]?.text || item.shortBylineText?.runs?.[0]?.text || 'Artist';
          const vId = item.videoId;
          const thumb = item.thumbnail?.thumbnails?.[0]?.url;
          if (title && vId && vId !== videoId) {
            radioTracks.push({
              id: vId,
              videoId: vId,
              title,
              artist: {
                id: `art_${encodeURIComponent(artistName)}`,
                name: artistName,
                picture: thumb
              },
              artists: [{
                id: `art_${encodeURIComponent(artistName)}`,
                name: artistName
              }],
              album: {
                id: `alb_${vId}`,
                title,
                cover: thumb
              },
              duration: 210,
              duration_ms: 210000,
              source: 'youtube-radio'
            });
          }
        }
        for (const k of Object.keys(node)) traverse(node[k]);
      };

      traverse(data);

      if (radioTracks.length > 0) {
        const result = radioTracks.slice(0, limit);
        cacheService.set(cacheKey, result, 3600);
        return result;
      }
    } catch (err) {
      console.warn('[YouTubeMusicService] RDAMVM radio failed:', err.message);
    }

    // Fallback: search similar tracks
    const searchRes = await this.search(cleanId || 'top hits', 'track', limit);
    return searchRes?.tracks?.items || [];
  }
}

const youtubeMusicService = new YouTubeMusicService();
module.exports = youtubeMusicService;
