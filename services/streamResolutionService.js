const config = require('../config/env');
const cacheService = require('./cacheService');
const { fetchJson } = require('../lib/httpClient');
const { getTrackById } = require('../lib/catalogData');

class StreamResolutionService {
  constructor() {
    this.invidiousInstances = [
      'https://invidious.flokinet.to',
      'https://invidious.projectsegfau.lt',
      'https://inv.tux.pizza',
      'https://invidious.nerdvpn.de',
      'https://vid.puffyan.us'
    ];

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

    let directUrl = null;
    let mimeType = 'audio/mp4';

    // 2. Try Invidious instances
    for (const instance of this.invidiousInstances) {
      try {
        const streamData = await fetchJson(`${instance}/api/v1/videos/${videoId}`, { timeout: 3500 });
        const audioFormats = streamData?.adaptiveFormats?.filter(f => f.type && f.type.startsWith('audio/')) || [];
        if (audioFormats.length > 0) {
          // Sort by bitrate descending
          const sorted = audioFormats.sort((a, b) => (Number(b.bitrate) || 0) - (Number(a.bitrate) || 0));
          const best = sorted[0];
          if (best && best.url) {
            directUrl = best.url;
            mimeType = best.type ? best.type.split(';')[0] : 'audio/mp4';
            break;
          }
        }
      } catch (err) {
        continue;
      }
    }

    // 3. Try Piped instances if Invidious didn't return
    if (!directUrl) {
      for (const instance of this.pipedInstances) {
        try {
          const streamData = await fetchJson(`${instance}/streams/${videoId}`, { timeout: 3500 });
          if (streamData && streamData.audioStreams && streamData.audioStreams.length > 0) {
            const sorted = streamData.audioStreams.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
            const bestAudio = sorted[0];
            if (bestAudio && bestAudio.url) {
              directUrl = bestAudio.url;
              mimeType = bestAudio.mimeType || 'audio/mp4';
              break;
            }
          }
        } catch (err) {
          continue;
        }
      }
    }

    // 4. Invidious direct fallback proxy stream
    if (!directUrl) {
      // Direct stream endpoint from reliable public invidious mirror
      directUrl = `https://invidious.flokinet.to/latest_version?id=${videoId}&itag=140`;
      mimeType = 'audio/mp4';
    }

    const result = {
      videoId,
      directUrl,
      mimeType,
      expiresInSeconds: config.cache.streamTtl,
      source: 'youtube-stream'
    };

    cacheService.set(cacheKey, result, config.cache.streamTtl);
    return result;
  }
}

const streamResolutionService = new StreamResolutionService();
module.exports = streamResolutionService;
