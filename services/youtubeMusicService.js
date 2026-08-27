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
  async searchInnertube(query) {
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
      params: 'EgWKAQIIAWoQEAMQBBAJEAoQCxAEEAkQChAA' // Filter for songs
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

      return this.parseInnertubeResults(data);
    } catch (err) {
      console.warn('[YouTubeMusicService] Innertube search failed, trying web fallback:', err.message);
      return [];
    }
  }

  parseInnertubeResults(data) {
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

        // Video ID
        const videoId =
          item.playlistItemData?.videoId ||
          item.doubleTapCommand?.watchEndpoint?.videoId ||
          item.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint?.watchEndpoint?.videoId ||
          '';

        const thumb = item.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.[0]?.url || '';

        if (videoId && titleText) {
          results.push({
            id: videoId,
            videoId,
            title: titleText,
            artist,
            duration: Math.round(durationMs / 1000),
            duration_ms: durationMs,
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
          const artist = v.ownerText?.runs?.[0]?.text || '';
          const durationStr = v.lengthText?.simpleText || '';
          const durationMs = this.parseDuration(durationStr);
          const thumb = v.thumbnail?.thumbnails?.[0]?.url || '';

          if (videoId && title) {
            results.push({
              id: videoId,
              videoId,
              title,
              artist,
              duration: Math.round(durationMs / 1000),
              duration_ms: durationMs,
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
   * Search YouTube Music or YouTube candidates for a query
   */
  async searchCandidates(query) {
    if (!query) return [];

    const cacheKey = `yt_candidates_${encodeURIComponent(query)}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    let candidates = await this.searchInnertube(query);
    if (!candidates || candidates.length === 0) {
      candidates = await this.searchWeb(query);
    }

    if (candidates && candidates.length > 0) {
      cacheService.set(cacheKey, candidates, 3600);
    }

    return candidates;
  }
}

const youtubeMusicService = new YouTubeMusicService();
module.exports = youtubeMusicService;

