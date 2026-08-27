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
    const cleanName = String(artistNameOrId).replace(/^art_yt_\d+_/, '');

    const cacheKey = `yt_artist_${encodeURIComponent(cleanName)}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    // Search top songs of this artist
    const songResults = await this.search(`${cleanName} top songs`, 'track', 20);
    const tracks = songResults?.tracks?.items || [];

    const artistPic = tracks[0]?.album?.cover || tracks[0]?.artist?.picture || '';

    const artist = {
      id: artistNameOrId,
      name: cleanName,
      picture: artistPic,
      genres: ['Pop', 'Music'],
      popularity: 88,
      source: 'youtube'
    };

    const albums = tracks.slice(0, 8).map((t, idx) => ({
      id: `alb_${t.id}`,
      title: t.title,
      cover: t.album?.cover || artistPic,
      artist,
      releaseDate: '2024',
      type: idx % 2 === 0 ? 'ALBUM' : 'SINGLE',
      source: 'youtube'
    }));

    const result = {
      artist,
      tracks,
      albums
    };

    cacheService.set(cacheKey, result, 3600);
    return result;
  }

  /**
   * Get related tracks / recommendations from YouTube Music
   */
  async getRecommendations(seedIdOrQuery, limit = 15) {
    const query = seedIdOrQuery || 'top hits';
    const searchRes = await this.search(query, 'track', limit);
    return searchRes?.tracks?.items || [];
  }
}

const youtubeMusicService = new YouTubeMusicService();
module.exports = youtubeMusicService;
