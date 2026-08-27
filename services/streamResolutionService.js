const config = require('../config/env');
const cacheService = require('./cacheService');
const { fetchJson } = require('../lib/httpClient');
const { getTrackById } = require('../lib/catalogData');

class StreamResolutionService {
  constructor() {
    this.innertubeEndpoint = 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';
  }

  /**
   * Extract direct YouTube audio stream directly from Google's YouTube CDN
   */
  async extractDirectYouTubeStream(videoId) {
    const clients = [
      {
        clientName: 'ANDROID_VR',
        clientVersion: '1.50.28',
        androidSdkVersion: 30,
        hl: 'en',
        gl: 'US'
      },
      {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20240101.01.00',
        hl: 'en',
        gl: 'US'
      }
    ];

    for (const client of clients) {
      try {
        const payload = {
          context: { client },
          videoId
        };

        const res = await fetchJson(this.innertubeEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Origin': 'https://music.youtube.com'
          },
          body: JSON.stringify(payload),
          timeout: 4500
        });

        const formats = res?.streamingData?.adaptiveFormats || [];
        const audioFormats = formats.filter((f) => f.mimeType && f.mimeType.startsWith('audio/'));

        // Sort by bitrate descending for highest audio quality
        const sorted = audioFormats.sort((a, b) => (Number(b.bitrate) || 0) - (Number(a.bitrate) || 0));
        const withUrl = sorted.find((f) => Boolean(f.url));

        if (withUrl && withUrl.url) {
          return {
            url: withUrl.url,
            mimeType: withUrl.mimeType ? withUrl.mimeType.split(';')[0] : 'audio/webm'
          };
        }
      } catch (err) {
        continue;
      }
    }

    return null;
  }

  /**
   * Resolve a videoId into a direct playable audio stream URL
   */
  async resolveStreamUrl(videoId) {
    if (!videoId) {
      throw new Error('Missing videoId for stream resolution');
    }

    const cacheKey = `stream_${videoId}`;
    const cached = cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }

    // 1. Check local catalog
    const demoTrack = getTrackById(videoId);
    if (demoTrack && demoTrack.streamUrl && !demoTrack.streamUrl.includes('soundhelix')) {
      const result = {
        videoId,
        directUrl: demoTrack.streamUrl,
        mimeType: 'audio/mp3',
        expiresInSeconds: config.cache.streamTtl,
        source: 'local-catalog'
      };
      cacheService.set(cacheKey, result, config.cache.streamTtl);
      return result;
    }

    // 2. Extract directly from YouTube Google CDN (zero third-party mirrors)
    const directStream = await this.extractDirectYouTubeStream(videoId);
    if (directStream && directStream.url) {
      const result = {
        videoId,
        directUrl: directStream.url,
        mimeType: directStream.mimeType,
        expiresInSeconds: config.cache.streamTtl,
        source: 'youtube-cdn'
      };
      cacheService.set(cacheKey, result, config.cache.streamTtl);
      return result;
    }

    // 3. If direct stream URL requires embedded player bridge, return clean videoId pointer
    const result = {
      videoId,
      directUrl: `https://www.youtube.com/watch?v=${videoId}`,
      mimeType: 'audio/mp4',
      expiresInSeconds: config.cache.streamTtl,
      source: 'youtube-embed-bridge'
    };

    cacheService.set(cacheKey, result, config.cache.streamTtl);
    return result;
  }
}

const streamResolutionService = new StreamResolutionService();
module.exports = streamResolutionService;
