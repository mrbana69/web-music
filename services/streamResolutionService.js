const crypto = require('crypto');
const config = require('../config/env');
const cacheService = require('./cacheService');
const { fetchJson } = require('../lib/httpClient');
const { getTrackById } = require('../lib/catalogData');

class StreamResolutionService {
  constructor() {
    this.innertubeEndpoint = 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';
    this.ytmEndpoint = 'https://music.youtube.com/youtubei/v1/player';
  }

  /**
   * Generates authentic SAPISIDHASH for YouTube Music
   */
  generateSapisidHash(cookieString, origin = 'https://music.youtube.com') {
    if (!cookieString || typeof cookieString !== 'string') return null;
    let sapisid = '';
    const match1 = cookieString.match(/(?:__Secure-3PAPISID|SAPISID|__Secure-1PAPISID)=([^;]+)/i);
    if (match1 && match1[1]) {
      sapisid = match1[1].trim();
    } else if (cookieString.length >= 20 && !cookieString.includes('=')) {
      sapisid = cookieString.trim();
    }
    if (!sapisid) return null;

    const timestamp = Math.floor(Date.now() / 1000);
    const sha1 = crypto.createHash('sha1');
    sha1.update(`${timestamp} ${sapisid} ${origin}`);
    const hash = sha1.digest('hex');
    return `SAPISIDHASH ${timestamp}_${hash}`;
  }

  /**
   * Extract direct YouTube audio stream directly from Google's YouTube CDN with ultra-fast parallel requests
   */
  async extractDirectYouTubeStream(videoId, userCookie = null) {
    const activeCookie = userCookie || config.youtubeMusic.cookie || '';
    const sapisidHash = this.generateSapisidHash(activeCookie);

    const clients = [
      ...(activeCookie ? [
        {
          name: 'YTM_AUTHENTICATED',
          endpoint: this.ytmEndpoint,
          client: {
            clientName: 'WEB_REMIX',
            clientVersion: '1.20241101.01.00',
            hl: 'en',
            gl: 'US'
          },
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
            'Origin': 'https://music.youtube.com',
            'Referer': 'https://music.youtube.com/',
            'Cookie': activeCookie,
            ...(sapisidHash ? { 'Authorization': sapisidHash } : {})
          }
        },
        {
          name: 'IOS_AUTHENTICATED',
          endpoint: this.innertubeEndpoint,
          client: {
            clientName: 'IOS',
            clientVersion: '19.45.4',
            deviceModel: 'iPhone16,2',
            hl: 'en',
            gl: 'US'
          },
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1 like Mac OS X; en_US)',
            'Cookie': activeCookie,
            ...(sapisidHash ? { 'Authorization': sapisidHash } : {})
          }
        }
      ] : []),
      {
        name: 'ANDROID_VR',
        endpoint: this.innertubeEndpoint,
        client: {
          clientName: 'ANDROID_VR',
          clientVersion: '1.50.28',
          androidSdkVersion: 30,
          hl: 'en',
          gl: 'US'
        },
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Origin': 'https://music.youtube.com'
        }
      },
      {
        name: 'ANDROID_MUSIC',
        endpoint: this.innertubeEndpoint,
        client: {
          clientName: 'ANDROID_MUSIC',
          clientVersion: '6.43.52',
          androidSdkVersion: 34,
          hl: 'en',
          gl: 'US'
        },
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Origin': 'https://music.youtube.com'
        }
      },
      {
        name: 'TV_EMBEDDED',
        endpoint: this.innertubeEndpoint,
        client: {
          clientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
          clientVersion: '2.0',
          hl: 'en',
          gl: 'US'
        },
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 5.0) AppleWebKit/538.1',
          'Origin': 'https://music.youtube.com'
        }
      }
    ];

    const fetchClient = async (entry) => {
      try {
        const payload = {
          context: { client: entry.client },
          videoId
        };

        const res = await fetchJson(entry.endpoint || this.innertubeEndpoint, {
          method: 'POST',
          headers: entry.headers || {
            'Content-Type': 'application/json',
            'Origin': 'https://music.youtube.com'
          },
          body: JSON.stringify(payload),
          timeout: 2500
        });

        const formats = [
          ...(res?.streamingData?.adaptiveFormats || []),
          ...(res?.streamingData?.formats || [])
        ];
        const audioFormats = formats.filter((f) => f.mimeType && f.mimeType.startsWith('audio/') && Boolean(f.url));
        
        // Prioritize audio/mp4 (AAC / itag 140) for 100% universal iOS Safari & Android mobile background playback
        const mp4Formats = audioFormats.filter(f => f.mimeType.includes('audio/mp4') || f.mimeType.includes('mp4a'));
        const sortedMp4 = mp4Formats.sort((a, b) => (Number(b.bitrate) || 0) - (Number(a.bitrate) || 0));
        const sortedAll = audioFormats.sort((a, b) => (Number(b.bitrate) || 0) - (Number(a.bitrate) || 0));

        const chosen = sortedMp4[0] || sortedAll[0];

        if (chosen && chosen.url) {
          return {
            url: chosen.url,
            mimeType: chosen.mimeType ? chosen.mimeType.split(';')[0] : 'audio/mp4'
          };
        }
        return null;
      } catch (err) {
        return null;
      }
    };

    // Run in parallel with fast timeout
    const results = await Promise.allSettled(clients.map(c => fetchClient(c)));
    for (const r of results) {
      if (r.status === 'fulfilled' && r.value) {
        return r.value;
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

    const cacheKey = `stream_${videoId}`;
    const cached = cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }

    // 1. Check local catalog
    const demoTrack = getTrackById(videoId);
    if (demoTrack && demoTrack.streamUrl) {
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
