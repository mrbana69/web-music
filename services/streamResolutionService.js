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
  async extractDirectYouTubeStream(videoId, userCookie = null) {
    const { buildInnertubeAuthHeaders } = require('../lib/sapisid');
    const authHeaders = userCookie ? buildInnertubeAuthHeaders(userCookie) : {};

    const clients = [
      {
        name: 'ANDROID_VR',
        endpoint: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
        origin: 'https://www.youtube.com',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        },
        payload: {
          context: {
            client: {
              clientName: 'ANDROID_VR',
              clientVersion: '1.50.28',
              deviceModel: 'Quest 3',
              osName: 'Android',
              osVersion: '12',
              androidSdkVersion: 32,
              hl: 'en',
              gl: 'US'
            }
          },
          videoId,
          contentCheckOk: true,
          racyCheckOk: true
        }
      },
      {
        name: 'WEB_REMIX',
        endpoint: 'https://music.youtube.com/youtubei/v1/player?prettyPrint=false',
        origin: 'https://music.youtube.com',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          ...authHeaders
        },
        payload: {
          context: {
            client: {
              clientName: 'WEB_REMIX',
              clientVersion: '1.20240101.01.00',
              hl: 'en',
              gl: 'US'
            }
          },
          videoId,
          contentCheckOk: true,
          racyCheckOk: true
        }
      }
    ];

    for (const c of clients) {
      try {
        const res = await fetchJson(c.endpoint, {
          method: 'POST',
          headers: c.headers,
          body: JSON.stringify(c.payload),
          timeout: 4500
        });

        const formats = [
          ...(res?.streamingData?.adaptiveFormats || []),
          ...(res?.streamingData?.formats || [])
        ];
        const audioFormats = formats.filter((f) => f.mimeType && f.mimeType.startsWith('audio/'));
        const withDirectUrl = audioFormats.filter((f) => Boolean(f.url));

        if (withDirectUrl.length > 0) {
          // Prioritize M4A / AAC for maximum iOS & Android native audio background support
          const m4aFormats = withDirectUrl.filter(f => f.mimeType.includes('mp4') || f.mimeType.includes('m4a'));
          const best = m4aFormats.length > 0
            ? m4aFormats.reduce((a, b) => ((b.bitrate || 0) > (a.bitrate || 0) ? b : a))
            : withDirectUrl.reduce((a, b) => ((b.bitrate || 0) > (a.bitrate || 0) ? b : a));

          return {
            url: best.url,
            mimeType: best.mimeType ? best.mimeType.split(';')[0] : 'audio/mp4',
            bitrate: best.bitrate || 128000
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
  async resolveStreamUrl(videoId, userCookie = null) {
    if (!videoId) {
      throw new Error('Missing videoId for stream resolution');
    }

    const cookieHash = userCookie ? `_u_${userCookie.length}` : '';
    const cacheKey = `stream_${videoId}${cookieHash}`;
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
    const directStream = await this.extractDirectYouTubeStream(videoId, userCookie);
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
