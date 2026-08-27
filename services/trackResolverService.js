const config = require('../config/env');
const cacheService = require('./cacheService');
const youtubeMusicService = require('./youtubeMusicService');
const { scoreTrackMatch, findBestCandidate, cleanText } = require('../lib/fuzzyMatcher');
const { DEMO_TRACKS, getTrackById } = require('../lib/catalogData');

class TrackResolverService {
  /**
   * Resolve a track (title + artist + duration_ms) into a YouTube videoId with confidence score
   */
  async resolveTrack(metadata = {}) {
    const { id, title, artist, duration_ms, duration } = metadata;
    const cleanT = cleanText(title || '');
    const cleanA = cleanText(typeof artist === 'string' ? artist : artist?.name || '');
    const targetDurationMs = Number(duration_ms || (duration ? duration * 1000 : 0));

    const queryKey = id ? `resolve_id_${id}` : `resolve_q_${cleanT}_${cleanA}_${targetDurationMs}`;
    const cached = cacheService.get(queryKey);
    if (cached) {
      return cached;
    }

    const target = {
      title: title || '',
      artist: typeof artist === 'string' ? artist : artist?.name || '',
      duration_ms: targetDurationMs
    };

    // If id itself is a valid 11-character YouTube video ID (e.g. dQw4w9WgXcQ)
    if (id && /^[a-zA-Z0-9_-]{11}$/.test(id)) {
      const result = {
        videoId: id,
        title: title || 'Track',
        artist: typeof artist === 'string' ? artist : artist?.name || 'Artist',
        duration_ms: targetDurationMs || 220000,
        score: 100,
        source: 'youtube-direct'
      };
      cacheService.set(queryKey, result, config.cache.resolverTtl);
      return result;
    }

    // If it's a known demo track ID
    const demoMatch = getTrackById(id);
    if (demoMatch && (!title || demoMatch.title.toLowerCase() === title.toLowerCase())) {
      const result = {
        videoId: demoMatch.id,
        title: demoMatch.title,
        artist: demoMatch.artist.name,
        duration_ms: demoMatch.duration_ms,
        score: 100,
        source: 'local-catalog',
        track: demoMatch
      };
      cacheService.set(queryKey, result, config.cache.resolverTtl);
      return result;
    }

    // 1. Search YouTube Music candidates
    const searchQuery = `${target.title} ${target.artist}`.trim();
    let candidates = [];
    if (searchQuery) {
      candidates = await youtubeMusicService.searchCandidates(searchQuery);
    }

    let bestMatch = null;

    // 2. Score and pick best candidate
    if (candidates && candidates.length > 0) {
      bestMatch = findBestCandidate(target, candidates);
    }

    // 3. Fallback to catalog if no candidates found
    if (!bestMatch || bestMatch.score < 20) {
      const catalogCandidate = findBestCandidate(target, DEMO_TRACKS);
      if (catalogCandidate) {
        bestMatch = {
          ...catalogCandidate,
          videoId: catalogCandidate.id,
          source: 'catalog-fallback'
        };
      }
    }

    if (!bestMatch) {
      bestMatch = {
        videoId: id || 'demo-track-1',
        title: target.title || 'Unknown Track',
        artist: target.artist || 'Unknown Artist',
        duration_ms: target.duration_ms || 220000,
        score: 50,
        source: 'default-fallback'
      };
    }

    const result = {
      videoId: bestMatch.videoId || bestMatch.id,
      title: bestMatch.title,
      artist: typeof bestMatch.artist === 'string' ? bestMatch.artist : bestMatch.artist?.name || '',
      duration_ms: bestMatch.duration_ms || targetDurationMs,
      score: bestMatch.score !== undefined ? bestMatch.score : 80,
      source: bestMatch.source || 'youtube-music',
      thumbnail: bestMatch.thumbnail || ''
    };

    cacheService.set(queryKey, result, config.cache.resolverTtl);
    return result;
  }
}

const trackResolverService = new TrackResolverService();
module.exports = trackResolverService;

