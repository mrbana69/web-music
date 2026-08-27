const config = require('../config/env');
const cacheService = require('./cacheService');
const { fetchJson } = require('../lib/httpClient');

class SpotifyService {
  constructor() {
    this.clientId = config.spotify.clientId;
    this.clientSecret = config.spotify.clientSecret;
    this.tokenCacheKey = 'spotify_app_access_token';
  }

  isConfigured() {
    return Boolean(this.clientId && this.clientSecret);
  }

  /**
   * Get application-level access token via Client Credentials flow
   */
  async getClientCredentialsToken() {
    if (!this.isConfigured()) return null;

    const cachedToken = cacheService.get(this.tokenCacheKey);
    if (cachedToken) return cachedToken;

    const authHeader = Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64');
    
    try {
      const data = await fetchJson('https://accounts.spotify.com/api/token', {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${authHeader}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({ grant_type: 'client_credentials' }).toString()
      });

      if (data && data.access_token) {
        const expiresIn = Math.max(60, (data.expires_in || 3600) - 120);
        cacheService.set(this.tokenCacheKey, data.access_token, expiresIn);
        return data.access_token;
      }
    } catch (err) {
      console.warn('[SpotifyService] Failed to obtain client credentials token:', err.message);
    }
    return null;
  }

  async request(endpoint, query = {}) {
    const token = await this.getClientCredentialsToken();
    if (!token) return null;

    const queryString = new URLSearchParams(query).toString();
    const url = `https://api.spotify.com/v1${endpoint}${queryString ? `?${queryString}` : ''}`;

    try {
      return await fetchJson(url, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
    } catch (err) {
      console.warn(`[SpotifyService] Request to ${endpoint} failed:`, err.message);
      return null;
    }
  }

  // Normalization Helpers
  normalizeTrack(item) {
    if (!item) return null;
    const albumCover = item.album?.images?.[0]?.url || item.album?.cover || '';
    const artistPic = item.artists?.[0]?.images?.[0]?.url || '';
    const primaryArtist = item.artists?.[0] || { id: 'unknown', name: 'Unknown Artist' };

    return {
      id: item.id,
      title: item.name || item.title || '',
      duration: Math.round((item.duration_ms || 0) / 1000),
      duration_ms: item.duration_ms || 0,
      explicit: Boolean(item.explicit),
      popularity: item.popularity || 50,
      artist: {
        id: primaryArtist.id,
        name: primaryArtist.name,
        picture: artistPic
      },
      artists: (item.artists || []).map((a) => ({ id: a.id, name: a.name })),
      album: {
        id: item.album?.id || '',
        title: item.album?.name || item.album?.title || '',
        cover: albumCover,
        releaseDate: item.album?.release_date || ''
      },
      source: 'spotify'
    };
  }

  normalizeArtist(item) {
    if (!item) return null;
    return {
      id: item.id,
      name: item.name,
      picture: item.images?.[0]?.url || '',
      genres: item.genres || [],
      popularity: item.popularity || 50,
      source: 'spotify'
    };
  }

  normalizeAlbum(item) {
    if (!item) return null;
    const primaryArtist = item.artists?.[0] || { id: 'unknown', name: 'Unknown Artist' };
    return {
      id: item.id,
      title: item.name || item.title || '',
      cover: item.images?.[0]?.url || '',
      artist: {
        id: primaryArtist.id,
        name: primaryArtist.name
      },
      artists: (item.artists || []).map((a) => ({ id: a.id, name: a.name })),
      releaseDate: item.release_date || '',
      year: item.release_date ? item.release_date.split('-')[0] : '',
      type: (item.album_type || item.type || 'ALBUM').toUpperCase(),
      totalTracks: item.total_tracks || 0,
      source: 'spotify'
    };
  }

  /**
   * Search Spotify for tracks, artists, and albums
   */
  async search(query, type = 'track', limit = 20) {
    if (!this.isConfigured() || !query) return null;

    const cacheKey = `spotify_search_${type}_${query}_${limit}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    let spotifyTypes = 'track,artist,album';
    if (type === 'artist') spotifyTypes = 'artist';
    else if (type === 'album') spotifyTypes = 'album';
    else if (type === 'track') spotifyTypes = 'track';

    const data = await this.request('/search', {
      q: query,
      type: spotifyTypes,
      limit: String(limit)
    });

    if (!data) return null;

    const tracks = (data.tracks?.items || []).map((t) => this.normalizeTrack(t)).filter(Boolean);
    const artists = (data.artists?.items || []).map((a) => this.normalizeArtist(a)).filter(Boolean);
    const albums = (data.albums?.items || []).map((al) => this.normalizeAlbum(al)).filter(Boolean);

    let items = tracks;
    if (type === 'artist') items = artists;
    else if (type === 'album') items = albums;

    const result = {
      items,
      tracks: { items: tracks },
      artists: { items: artists },
      albums: { items: albums }
    };

    cacheService.set(cacheKey, result, config.cache.metadataTtl);
    return result;
  }

  async getTrack(id) {
    if (!this.isConfigured() || !id) return null;
    const cacheKey = `spotify_track_${id}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/tracks/${id}`);
    const track = this.normalizeTrack(data);
    if (track) {
      cacheService.set(cacheKey, track, config.cache.metadataTtl);
    }
    return track;
  }

  async getArtist(id) {
    if (!this.isConfigured() || !id) return null;
    const cacheKey = `spotify_artist_${id}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/artists/${id}`);
    const artist = this.normalizeArtist(data);
    if (artist) {
      cacheService.set(cacheKey, artist, config.cache.metadataTtl);
    }
    return artist;
  }

  async getArtistTopTracks(id) {
    if (!this.isConfigured() || !id) return [];
    const cacheKey = `spotify_artist_top_${id}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/artists/${id}/top-tracks`, { market: 'US' });
    const tracks = (data?.tracks || []).map((t) => this.normalizeTrack(t)).filter(Boolean);
    cacheService.set(cacheKey, tracks, config.cache.metadataTtl);
    return tracks;
  }

  async getArtistAlbums(id) {
    if (!this.isConfigured() || !id) return [];
    const cacheKey = `spotify_artist_albums_${id}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/artists/${id}/albums`, { limit: '30', include_groups: 'album,single,ep' });
    const albums = (data?.items || []).map((al) => this.normalizeAlbum(al)).filter(Boolean);
    cacheService.set(cacheKey, albums, config.cache.metadataTtl);
    return albums;
  }

  async getArtistSimilar(id) {
    if (!this.isConfigured() || !id) return [];
    const cacheKey = `spotify_artist_similar_${id}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/artists/${id}/related-artists`);
    const artists = (data?.artists || []).map((a) => this.normalizeArtist(a)).filter(Boolean);
    cacheService.set(cacheKey, artists, config.cache.metadataTtl);
    return artists;
  }

  async getAlbum(id) {
    if (!this.isConfigured() || !id) return null;
    const cacheKey = `spotify_album_${id}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/albums/${id}`);
    if (!data) return null;

    const album = this.normalizeAlbum(data);
    const tracks = (data.tracks?.items || []).map((t) => ({
      ...this.normalizeTrack({ ...t, album: data }),
      trackNumber: t.track_number
    })).filter(Boolean);

    const result = {
      album,
      tracks,
      items: tracks.map((track) => ({ item: track }))
    };

    cacheService.set(cacheKey, result, config.cache.metadataTtl);
    return result;
  }

  async getRecommendations(seedTrackId, limit = 15) {
    if (!this.isConfigured() || !seedTrackId) return [];
    const cacheKey = `spotify_rec_${seedTrackId}_${limit}`;
    const cached = cacheService.get(cacheKey);
    if (cached) return cached;

    const data = await this.request('/recommendations', {
      seed_tracks: seedTrackId,
      limit: String(limit)
    });

    const tracks = (data?.tracks || []).map((t) => this.normalizeTrack(t)).filter(Boolean);
    cacheService.set(cacheKey, tracks, config.cache.metadataTtl);
    return tracks;
  }
}

const spotifyService = new SpotifyService();
module.exports = spotifyService;

