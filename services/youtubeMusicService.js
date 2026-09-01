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
   * Format Google/YouTube CDN artwork URLs to crisp HD =w500-h500-l90-rj
   */
  formatThumb(rawUrl) {
    if (!rawUrl) return '';
    let str = String(rawUrl).trim();
    if (str.includes('googleusercontent.com') || str.includes('ggpht.com')) {
      str = str.replace(/=[ws]\d+.*$/, '=w500-h500-l90-rj');
      if (!str.includes('=w500-h500-l90-rj') && !str.includes('=')) {
        str += '=w500-h500-l90-rj';
      }
      return str;
    }
    if (str.includes('i.ytimg.com')) {
      return str.replace(/\/default\.jpg/, '/hqdefault.jpg').replace(/\/mqdefault\.jpg/, '/hqdefault.jpg').replace(/\/maxresdefault\.jpg/, '/hqdefault.jpg');
    }
    return str;
  }

  /**
   * Sanitize artist names by stripping YouTube metadata artifacts (- Topic, VEVO, Official Channel, etc.)
   */
  formatArtistName(rawName) {
    if (!rawName || typeof rawName !== 'string') return 'Unknown Artist';
    let clean = rawName.trim();
    clean = clean.replace(/\s*-\s*Topic\b/gi, '');
    clean = clean.replace(/Topic$/i, '');
    clean = clean.replace(/\s*VEVO\b/gi, '');
    clean = clean.replace(/VEVO$/i, '');
    clean = clean.replace(/\s*Official(?:\s*Channel|\s*Artist\s*Channel)?\b/gi, '');
    clean = clean.replace(/\s*-\s*Official$/gi, '');
    clean = clean.replace(/\s*Records\b/gi, '');
    clean = clean.replace(/\s+/g, ' ').trim();
    return clean || 'Artist';
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
        const rawArtist = subRuns[0]?.text || 'Unknown Artist';
        const artist = this.formatArtistName(rawArtist);
        const durationStr = subRuns[subRuns.length - 1]?.text || '';
        const durationMs = this.parseDuration(durationStr);

        // Extract real Album name and album browseId from byline runs
        let realAlbumTitle = titleText;
        let realAlbumBrowseId = '';
        const albumRun = subRuns.find((r) => r.navigationEndpoint?.browseEndpoint?.browseId?.startsWith('MPREb_') || r.navigationEndpoint?.browseEndpoint?.browseId?.startsWith('OLAK5uy_'));
        if (albumRun) {
          realAlbumTitle = albumRun.text;
          realAlbumBrowseId = albumRun.navigationEndpoint?.browseEndpoint?.browseId;
        } else if (subRuns.length >= 3) {
          const bulletIdx = subRuns.findIndex((r) => r.text && r.text.includes('•'));
          if (bulletIdx !== -1 && subRuns[bulletIdx + 1] && !subRuns[bulletIdx + 1].text.includes(':') && !subRuns[bulletIdx + 1].text.includes('•')) {
            realAlbumTitle = subRuns[bulletIdx + 1].text;
          }
        }

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
        const thumb = this.formatThumb(rawThumb);

        const navEndpoint = item.playlistItemData?.navigationEndpoint ||
          item.doubleTapCommand ||
          item.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint ||
          item.navigationEndpoint;
        const musicVideoType = navEndpoint?.watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType ||
          (realAlbumBrowseId ? 'MUSIC_VIDEO_TYPE_ATV' : 'MUSIC_VIDEO_TYPE_OMV');

        const isSong = musicVideoType === 'MUSIC_VIDEO_TYPE_ATV' || Boolean(realAlbumBrowseId);
        const isMusicVideo = musicVideoType === 'MUSIC_VIDEO_TYPE_OMV';

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
            album: {
              id: realAlbumBrowseId || `alb_${finalId}`,
              browseId: realAlbumBrowseId,
              title: realAlbumTitle,
              name: realAlbumTitle,
              cover: thumb
            },
            picture: thumb,
            cover: thumb,
            duration: Math.round(durationMs / 1000) || 210,
            duration_ms: durationMs || 210000,
            thumbnail: thumb,
            itemType: isSong ? 'song' : (isMusicVideo ? 'video' : 'song'),
            musicVideoType: musicVideoType || 'MUSIC_VIDEO_TYPE_ATV',
            isOfficial: isSong || isMusicVideo,
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
          const rawArtist = v.ownerText?.runs?.[0]?.text || 'Unknown Artist';
          const artist = this.formatArtistName(rawArtist);
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
   * Get track info (title, artist, real album, and cover) by videoId from YouTube Music
   */
  async getTrackInfo(videoId) {
    if (!videoId) return null;
    const cacheKey = `yt_track_info_${videoId}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

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
        videoId
      };

      const res = await fetchJson('https://music.youtube.com/youtubei/v1/player', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/'
        },
        body: JSON.stringify(payload),
        timeout: 4000
      });

      const details = res?.videoDetails;
      if (details) {
        const title = details.title || '';
        const author = this.formatArtistName(details.author || 'Artist');
        const rawThumb = details.thumbnail?.thumbnails?.[details.thumbnail.thumbnails.length - 1]?.url || '';
        const thumb = this.formatThumb(rawThumb);

        const trackInfo = {
          id: videoId,
          videoId,
          title,
          artist: { id: `art_${encodeURIComponent(author)}`, name: author, picture: thumb },
          artists: [{ id: `art_${encodeURIComponent(author)}`, name: author }],
          album: { id: `alb_${videoId}`, title, cover: thumb },
          duration: Number(details.lengthSeconds) || 210,
          duration_ms: (Number(details.lengthSeconds) || 210) * 1000,
          cover: thumb,
          picture: thumb
        };

        cacheService.set(cacheKey, trackInfo, 3600);
        return trackInfo;
      }
    } catch (e) {
      console.warn('[YouTubeMusicService] getTrackInfo failed:', e.message);
    }
    return null;
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
              albumCover = this.formatThumb(best.thumb);
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
            if (rawThumb) albumCover = this.formatThumb(rawThumb);
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
            const rawArtist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || resolvedArtist;
            const tArtist = this.formatArtistName(rawArtist);
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

  /**
   * Fetch any YouTube / YouTube Music playlist tracks by playlistId or link
   */
  async getPlaylist(playlistId) {
    let cleanId = String(playlistId || '').trim();
    const urlMatch = cleanId.match(/[?&]list=([a-zA-Z0-9_-]+)/);
    if (urlMatch) cleanId = urlMatch[1];
    cleanId = cleanId.replace(/^VL/, '');

    const browseId = cleanId.startsWith('VL') ? cleanId : `VL${cleanId}`;
    let playlistTitle = 'YouTube Playlist';
    let playlistCover = '';
    let tracks = [];

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
        if (node.musicDetailHeaderRenderer || node.musicEditablePlaylistDetailHeaderRenderer) {
          const h = node.musicDetailHeaderRenderer || node.musicEditablePlaylistDetailHeaderRenderer?.header?.musicDetailHeaderRenderer;
          if (h) {
            const title = h.title?.runs?.[0]?.text;
            const rawThumb = h.thumbnail?.croppedSquareThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url;
            if (title) playlistTitle = title;
            if (rawThumb) playlistCover = this.formatThumb(rawThumb);
          }
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
          const rawArtist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || 'Artist';
          const tArtist = this.formatArtistName(rawArtist);
          const vId = item.playlistItemData?.videoId || flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId;
          const rawThumb = item.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url || playlistCover;
          const thumb = this.formatThumb(rawThumb);
          if (tTitle && vId) {
            tracks.push({
              id: vId,
              videoId: vId,
              title: tTitle,
              artist: { id: `art_${encodeURIComponent(tArtist)}`, name: tArtist, picture: thumb },
              artists: [{ id: `art_${encodeURIComponent(tArtist)}`, name: tArtist }],
              album: { id: `pl_${cleanId}`, title: playlistTitle, cover: thumb },
              duration: 210,
              duration_ms: 210000,
              source: 'youtube-playlist'
            });
          }
        }
        for (const k of Object.keys(node)) traverseTracks(node[k]);
      };
      traverseTracks(browseRes);
    } catch (e) {
      console.warn('[YouTubeMusicService] Browse playlist failed:', e.message);
    }

    return {
      id: cleanId,
      name: playlistTitle,
      title: playlistTitle,
      cover: playlistCover || tracks[0]?.album?.cover || '',
      itemCount: tracks.length,
      songs: tracks
    };
  }

  /**
   * Get YouTube Music "Scelte rapide" (Quick Picks / Listen Again / Heavy Rotation)
   * If accessToken is provided, fetches the user's authentic personalized quick picks from their account
   */
  async getQuickPicks(accessToken = null, limit = 20) {
    const cacheKey = `yt_quick_picks_${accessToken ? accessToken.substring(0, 16) : 'guest'}_${limit}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const headers = {
      'Content-Type': 'application/json',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/'
    };

    if (accessToken && accessToken !== 'demo_google_access_token') {
      headers['Authorization'] = `Bearer ${accessToken}`;
    } else if (this.cookie) {
      headers['Cookie'] = this.cookie;
    }

    const payload = {
      context: {
        client: {
          clientName: 'WEB_REMIX',
          clientVersion: '1.20240101.01.00',
          hl: 'it',
          gl: 'IT'
        }
      },
      browseId: 'FEmusic_home'
    };

    let quickPicks = [];
    let isPersonalized = false;

    try {
      const homeRes = await fetchJson(`${this.innertubeEndpoint}/browse`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
        timeout: 6000
      });

      const traverse = (node) => {
        if (!node || typeof node !== 'object') return;
        if (node.musicCarouselShelfRenderer) {
          const headerText = node.musicCarouselShelfRenderer.header?.musicCarouselShelfBasicHeaderRenderer?.title?.runs?.[0]?.text || '';
          const lowerHeader = headerText.toLowerCase();

          // Strictly ignore any shelves for Shorts, Clips, or Samples
          if (lowerHeader.includes('shorts') || lowerHeader.includes('clip') || lowerHeader.includes('campionati') || lowerHeader.includes('momenti musicali') || lowerHeader.includes('brevi')) {
            return;
          }

          if (/scelte rapide|quick picks|listen again|di nuovo all'ascolto|i tuoi brani preferiti|spesso all'ascolto|raccolta|heavy rotation/i.test(headerText)) {
            if (/di nuovo all'ascolto|i tuoi brani preferiti|spesso all'ascolto|raccolta/i.test(headerText)) {
              isPersonalized = true;
            }
            const contents = node.musicCarouselShelfRenderer.contents || [];
            for (const item of contents) {
              const renderer = item.musicResponsiveListItemRenderer || item.musicTwoRowItemRenderer;
              if (renderer) {
                const flex = renderer.flexColumns || [];
                const tTitle = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || renderer.title?.runs?.[0]?.text;
                const rawArtist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || renderer.subtitle?.runs?.[0]?.text || 'Artist';
                const tArtist = this.formatArtistName(rawArtist);
                
                const navEndpoint = renderer.playlistItemData?.navigationEndpoint ||
                  renderer.navigationEndpoint ||
                  renderer.doubleTapCommand ||
                  renderer.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint;
                const musicVideoType = navEndpoint?.watchEndpoint?.watchEndpointMusicSupportedConfigs?.watchEndpointMusicConfig?.musicVideoType;

                if (musicVideoType === 'MUSIC_VIDEO_TYPE_UGC') {
                  continue;
                }

                const isSong = musicVideoType === 'MUSIC_VIDEO_TYPE_ATV' || !musicVideoType;
                const isMusicVideo = musicVideoType === 'MUSIC_VIDEO_TYPE_OMV';

                const vId = renderer.playlistItemData?.videoId ||
                  navEndpoint?.watchEndpoint?.videoId ||
                  renderer.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint?.watchEndpoint?.videoId;
                const rawThumb = renderer.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url ||
                  renderer.thumbnailRenderer?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url || '';
                const thumb = this.formatThumb(rawThumb);

                if (tTitle && vId && !quickPicks.some(p => p.id === vId || p.videoId === vId)) {
                  quickPicks.push({
                    id: vId,
                    videoId: vId,
                    title: tTitle,
                    artist: { id: `art_${encodeURIComponent(tArtist)}`, name: tArtist, picture: thumb },
                    artists: [{ id: `art_${encodeURIComponent(tArtist)}`, name: tArtist }],
                    album: { id: `alb_${vId}`, title: tTitle, cover: thumb },
                    duration: 210,
                    duration_ms: 210000,
                    thumbnail: thumb,
                    cover: thumb,
                    itemType: isSong ? 'song' : (isMusicVideo ? 'video' : 'song'),
                    musicVideoType: musicVideoType || 'MUSIC_VIDEO_TYPE_ATV',
                    isOfficial: true,
                    source: 'ytmusic-quick-picks'
                  });
                }
              }
            }
          }
        }
        for (const k of Object.keys(node)) traverse(node[k]);
      };

      traverse(homeRes);
    } catch (e) {
      console.warn('[YouTubeMusicService] getQuickPicks browse failed:', e.message);
    }

    // If authenticated user provided and we want to ensure their library liked music is present
    if (accessToken && accessToken !== 'demo_google_access_token' && quickPicks.length < limit) {
      try {
        const authService = require('./authService');
        const userLib = await authService.getUserLibrary(accessToken);
        if (userLib && userLib.likedSongs && userLib.likedSongs.length > 0) {
          isPersonalized = true;
          for (const s of userLib.likedSongs) {
            if (!quickPicks.some(p => p.id === s.id || p.videoId === s.id)) {
              quickPicks.unshift(s);
            }
          }
        }
      } catch (err) {}
    }

    // Fallback if still empty: search trending hits
    if (quickPicks.length === 0) {
      const topHits = await this.search('Top Hits 2025', 'track', limit);
      quickPicks = topHits?.tracks?.items || [];
    }

    const result = {
      items: quickPicks.slice(0, limit),
      total: Math.min(quickPicks.length, limit),
      personalized: Boolean(accessToken && isPersonalized),
      source: 'ytmusic'
    };

    cacheService.set(cacheKey, result, 1200);
    return result;
  }

  /**
   * Fetch live Home feed from YouTube Music (FEmusic_home)
   */
  async getHome() {
    const cacheKey = 'ytm_home_feed';
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

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
        browseId: 'FEmusic_home'
      };

      const browseRes = await fetchJson('https://music.youtube.com/youtubei/v1/browse', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/'
        },
        body: JSON.stringify(browsePayload),
        timeout: 6000
      });

      const sections = [];
      const traverse = (node) => {
        if (!node || typeof node !== 'object') return;
        if (node.musicCarouselShelfRenderer) {
          const header = node.musicCarouselShelfRenderer.header?.musicCarouselShelfBasicHeaderRenderer?.title?.runs?.[0]?.text || 'Consigliati';
          const items = [];
          const itemNodes = node.musicCarouselShelfRenderer.contents || [];
          for (const it of itemNodes) {
            if (it.musicResponsiveListItemRenderer) {
              const item = it.musicResponsiveListItemRenderer;
              const flex = item.flexColumns || [];
              const title = flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text;
              const rawArtist = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.text || 'Artist';
              const artist = this.formatArtistName(rawArtist);
              const videoId = item.playlistItemData?.videoId || flex[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId;
              const rawThumb = item.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url || '';
              const thumb = this.formatThumb(rawThumb);
              if (title && videoId) {
                items.push({
                  id: videoId,
                  videoId,
                  title,
                  artist: { id: `art_${encodeURIComponent(artist)}`, name: artist, picture: thumb },
                  artists: [{ id: `art_${encodeURIComponent(artist)}`, name: artist }],
                  album: { id: `alb_${videoId}`, title, cover: thumb },
                  duration: 210,
                  duration_ms: 210000,
                  source: 'youtube-home'
                });
              }
            } else if (it.musicTwoRowItemRenderer) {
              const item = it.musicTwoRowItemRenderer;
              const title = item.title?.runs?.[0]?.text;
              const rawArtist = item.subtitle?.runs?.[0]?.text || 'Artist';
              const artist = this.formatArtistName(rawArtist);
              const videoId = item.navigationEndpoint?.watchEndpoint?.videoId;
              const browseId = item.navigationEndpoint?.browseEndpoint?.browseId;
              const rawThumb = item.thumbnailRenderer?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url || '';
              const thumb = this.formatThumb(rawThumb);
              const finalId = videoId || browseId;
              if (title && finalId) {
                items.push({
                  id: finalId,
                  videoId: videoId || finalId,
                  browseId,
                  title,
                  artist: { id: `art_${encodeURIComponent(artist)}`, name: artist, picture: thumb },
                  artists: [{ id: `art_${encodeURIComponent(artist)}`, name: artist }],
                  album: { id: `alb_${finalId}`, title, cover: thumb },
                  duration: 210,
                  duration_ms: 210000,
                  source: 'youtube-home'
                });
              }
            }
          }
          if (items.length > 0) {
            sections.push({ header, items });
          }
        }
        for (const k of Object.keys(node)) traverse(node[k]);
      };

      traverse(browseRes);

      const result = { sections };
      cacheService.set(cacheKey, result, 1800);
      return result;
    } catch (e) {
      console.warn('[YouTubeMusicService] Fetch home feed failed:', e.message);
      return { sections: [] };
    }
  }
}

const youtubeMusicService = new YouTubeMusicService();
module.exports = youtubeMusicService;
