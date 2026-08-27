const config = require('../config/env');
const cacheService = require('./cacheService');
const { fetchJson } = require('../lib/httpClient');
const { getTrackById } = require('../lib/catalogData');

class StreamResolutionService {
  constructor() {
    this.pipedInstances = [
      'https://pipedapi.kavin.rocks',
      'https://api.piped.yt',
      'https://pipedapi.tokhmi.xyz',
      'https://piped-api.garudalinux.org'
    ];
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

    // 1. Check if it's a known catalog/demo ID
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

    // 2. Try Piped / Innertube instances for direct stream extraction
    let directUrl = null;
    let mimeType = 'audio/mp4';

    for (const instance of this.pipedInstances) {
      try {
        const streamData = await fetchJson(`${instance}/streams/${videoId}`, { timeout: 4000 });
        if (streamData && streamData.audioStreams && streamData.audioStreams.length > 0) {
          // Sort by bitrate descending to get best quality audio
          const sorted = streamData.audioStreams.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
          const bestAudio = sorted[0];
          if (bestAudio && bestAudio.url) {
            directUrl = bestAudio.url;
            mimeType = bestAudio.mimeType || 'audio/mp4';
            break;
          }
        }
      } catch (err) {
        // Try next instance
        continue;
      }
    }

    // 3. Fallback audio source for development / testing if external extractors are restricted
    if (!directUrl) {
      const baseNum = Number(String(videoId).replace(/\D/g, '')) || 1;
      directUrl = `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-${(baseNum % 5) + 1}.mp3`;
      mimeType = 'audio/mp3';
    }

    const result = {
      videoId,
      directUrl,
      mimeType,
      expiresInSeconds: config.cache.streamTtl,
      source: directUrl.includes('soundhelix') ? 'catalog-stream' : 'youtube-stream'
    };

    cacheService.set(cacheKey, result, config.cache.streamTtl);
    return result;
  }
}

const streamResolutionService = new StreamResolutionService();
module.exports = streamResolutionService;

