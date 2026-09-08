const spotifyService = require('../services/spotifyService');
const youtubeMusicService = require('../services/youtubeMusicService');
const trackResolverService = require('../services/trackResolverService');
const streamResolutionService = require('../services/streamResolutionService');
const cacheService = require('../services/cacheService');
const { createTrackManifest } = require('../lib/manifestGenerator');
const {
  DEMO_TRACKS,
  DEMO_ARTISTS,
  DEMO_ALBUMS,
  getTrackById,
  getArtistById,
  getAlbumById,
  getMixById
} = require('../lib/catalogData');

class MusicController {
  /**
   * GET /api/info - Track metadata & mix pointers
   */
  async info(req, res, next) {
    try {
      const { id } = req.query || {};
      if (!id) {
        return res.status(400).json({ error: 'Missing track id' });
      }

      let track = null;

      // 1. Check Spotify if configured
      if (spotifyService.isConfigured()) {
        track = await spotifyService.getTrack(id);
      }

      // 2. Check local catalog
      if (!track) {
        track = getTrackById(id);
      }

      // 3. Fallback track placeholder if query is arbitrary ID
      if (!track) {
        track = {
          id,
          title: 'Track ' + id,
          duration: 220,
          duration_ms: 220000,
          artist: { id: 'artist-1', name: 'Artist', picture: '/icons/192x192.png' },
          album: { id: 'album-1', title: 'Single', cover: '/icons/512x512.png' }
        };
      }

      return res.status(200).json({
        data: {
          track,
          mixes: { TRACK_MIX: `mix_${track.id}` },
          artists: [track.artist || { name: 'Unknown' }],
          albums: [track.album || { title: 'Unknown' }]
        }
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/track - Returns base64 stream manifest for audio player
   */
  async track(req, res, next) {
    try {
      const { id } = req.query || {};
      if (!id) {
        return res.status(400).json({ error: 'Missing track id' });
      }

      // 1. Fetch track metadata
      let track = null;
      if (spotifyService.isConfigured()) {
        track = await spotifyService.getTrack(id);
      }
      if (!track) {
        track = getTrackById(id);
      }

      // 2. Resolve to YouTube Music videoId
      const targetMetadata = track || { id, title: id, duration_ms: 220000 };
      const resolved = await trackResolverService.resolveTrack(targetMetadata);

      // 3. Resolve to direct audio stream URL
      const streamInfo = await streamResolutionService.resolveStreamUrl(resolved.videoId);

      // 4. Generate base64 manifest
      const manifestPayload = createTrackManifest([streamInfo.directUrl], {
        mimeType: streamInfo.mimeType,
        trackId: id,
        duration: targetMetadata.duration || 0
      });

      return res.status(200).json({
        ...manifestPayload,
        directUrl: streamInfo.directUrl,
        mimeType: streamInfo.mimeType,
        source: streamInfo.source || 'youtube',
        videoId: resolved.videoId,
        trackId: id
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/quick-picks - YouTube Music "Scelte rapide" / personalized heavy rotation
   */
  async quickPicks(req, res, next) {
    try {
      const authHeader = req.headers.authorization || '';
      const cookieHeader = req.headers['x-ytm-cookie'] || req.headers['x-youtube-cookie'] || req.headers['cookie'];
      const userCookie = req.query.ytm_cookie || req.query.cookie || cookieHeader || (authHeader.startsWith('Cookie ') ? authHeader.substring(7) : (authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null));
      const limit = parseInt(req.query.limit, 10) || 20;

      const quickPicksData = await youtubeMusicService.getQuickPicks(userCookie, limit);
      return res.status(200).json({
        ok: true,
        data: quickPicksData,
        ...quickPicksData
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/audio - Return stream URL for native background playback
   */
  async audio(req, res, next) {
    try {
      const { id, videoId } = req.query || {};
      const targetId = id || videoId;
      if (!targetId) {
        return res.status(400).json({ error: 'Missing id' });
      }

      let resolvedVideoId = targetId;
      try {
        const resolved = await trackResolverService.resolveTrack({ id: targetId, title: targetId });
        if (resolved && resolved.videoId) resolvedVideoId = resolved.videoId;
      } catch (_) {}

      // Fast stream proxy endpoint for native HTML5 audio with .mp4 extension for iOS AVPlayer
      const streamProxyUrl = `/api/stream.mp4?id=${encodeURIComponent(resolvedVideoId)}`;
      const payload = {
        url: streamProxyUrl,
        streamUrl: streamProxyUrl,
        directUrl: streamProxyUrl,
        mimeType: 'audio/mp4',
        source: 'stream-proxy',
        videoId: resolvedVideoId,
        trackId: targetId
      };
      return res.status(200).json(payload);
    } catch (err) {
      if (!res.headersSent) {
        const fallbackId = req.query?.id || req.query?.videoId || '';
        return res.status(200).json({ url: `/api/stream.mp4?id=${encodeURIComponent(fallbackId)}`, fallback: 'stream-proxy', videoId: fallbackId });
      }
      next(err);
    }
  }

  /**
   * GET /api/stream - Direct audio stream proxy with Range support for iOS Safari & Android background playback
   */
  async stream(req, res, next) {
    try {
      const { id, videoId } = req.query || {};
      const targetId = id || videoId;
      if (!targetId) {
        return res.status(400).json({ error: 'Missing track id' });
      }

      const authHeader = req.headers.authorization || '';
      const cookieHeader = req.headers['x-ytm-cookie'] || req.headers['x-youtube-cookie'] || req.headers['cookie'];
      const userCookie = req.query.ytm_cookie || req.query.cookie || cookieHeader || (authHeader.startsWith('Cookie ') ? authHeader.substring(7) : (authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null));

      let resolvedVideoId = targetId;
      try {
        const resolved = await trackResolverService.resolveTrack({ id: targetId, title: targetId });
        if (resolved && resolved.videoId) resolvedVideoId = resolved.videoId;
      } catch (_) {}

      const streamInfo = await streamResolutionService.resolveStreamUrl(resolvedVideoId, userCookie);

      if (streamInfo && streamInfo.directUrl && !streamInfo.directUrl.includes('youtube.com/watch')) {
        const range = req.headers.range;
        const upstreamHeaders = {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1',
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/'
        };
        if (range) {
          upstreamHeaders['Range'] = range;
        }

        const fetch = globalThis.fetch;
        const upstreamRes = await fetch(streamInfo.directUrl, { headers: upstreamHeaders });

        res.status(upstreamRes.status);
        res.setHeader('Content-Type', 'audio/mp4');
        res.setHeader('Accept-Ranges', 'bytes');
        res.setHeader('Cache-Control', 'public, max-age=3600');
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Headers', 'Range, Authorization, Content-Type');
        res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');

        if (upstreamRes.headers.get('content-range')) {
          res.setHeader('Content-Range', upstreamRes.headers.get('content-range'));
        }
        if (upstreamRes.headers.get('content-length')) {
          res.setHeader('Content-Length', upstreamRes.headers.get('content-length'));
        }

        const { Readable } = require('stream');
        return Readable.fromWeb(upstreamRes.body).pipe(res);
      }

      // If direct stream resolution did not find audio, return clean 404
      return res.status(404).json({
        ok: false,
        error: 'Direct stream not available',
        fallback: 'youtube-embed',
        videoId: resolvedVideoId,
        trackId: targetId
      });

    } catch (err) {
      if (!res.headersSent) {
        return res.status(500).json({ error: err.message, fallback: 'youtube-embed' });
      }
      next(err);
    }
  }

  /**
   * GET /api/mix - Dynamic recommendations / track radio
   */
  async mix(req, res, next) {
    try {
      const { id, title, artist } = req.query || {};
      let cleanId = String(id || '').replace(/^mix_/, '');
      if (!cleanId && title) {
        cleanId = `${title} ${artist || ''}`.trim();
      }

      let recTracks = [];

      // 1. Try Spotify recommendations if configured
      if (spotifyService.isConfigured() && cleanId) {
        recTracks = await spotifyService.getRecommendations(cleanId, 15);
      }

      // 2. Try YouTube Music recommendations (official RDAMVM automix queue)
      if ((!recTracks || recTracks.length === 0) && cleanId) {
        recTracks = await youtubeMusicService.getRecommendations(cleanId, 15);
      }

      // 3. Fallback to catalog mix
      if (!recTracks || recTracks.length === 0) {
        const catalogMix = getMixById(id);
        return res.status(200).json(catalogMix);
      }

      return res.status(200).json({
        id: id || 'rec_mix',
        title: 'Recommendations',
        items: recTracks.map((t) => ({ item: t }))
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/home - Official YouTube Music Home Feed (Quick Picks, Mixes, New Releases)
   */
  async home(req, res, next) {
    try {
      const authHeader = req.headers.authorization || '';
      const cookieHeader = req.headers['x-ytm-cookie'] || req.headers['x-youtube-cookie'] || req.headers['cookie'];
      const userCookie = req.query.ytm_cookie || req.query.cookie || cookieHeader || (authHeader.startsWith('Cookie ') ? authHeader.substring(7) : null);
      const homeFeed = await youtubeMusicService.getHome(userCookie);
      return res.status(200).json(homeFeed);
    } catch (err) {
      next(err);
    }
  }

  /**
    * GET /api/artist - Artist metadata, top tracks, and discography
   */
  async artist(req, res, next) {
    try {
      const { id, f, name, q } = req.query || {};
      const artistQuery = name || q || id || f;

      if (!artistQuery) {
        return res.status(400).json({ error: 'Missing artist query' });
      }

      let artist = null;
      let tracks = [];
      let albums = [];

      // 1. Try Spotify if configured
      if (spotifyService.isConfigured()) {
        artist = await spotifyService.getArtist(artistQuery);
        if (artist) {
          tracks = await spotifyService.getArtistTopTracks(artistQuery);
          albums = await spotifyService.getArtistAlbums(artistQuery);
        }
      }

      // 2. Try YouTube Music artist search
      if (!artist) {
        const ytArtistData = await youtubeMusicService.getArtist(artistQuery);
        if (ytArtistData && ytArtistData.artist) {
          artist = ytArtistData.artist;
          tracks = ytArtistData.tracks || [];
          albums = ytArtistData.albums || [];
        }
      }

      // 3. Fallback to local catalog
      if (!artist) {
        artist = getArtistById(artistQuery) || DEMO_ARTISTS[0];
        tracks = DEMO_TRACKS.filter((t) => t.artist.id === artist.id);
        albums = DEMO_ALBUMS.filter((al) => al.artist.id === artist.id);
      }

      return res.status(200).json({
        data: {
          artist,
          tracks,
          albums: { items: albums }
        },
        artist,
        tracks,
        albums: { items: albums }
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/artist/similar - Similar / related artists
   */
  async artistSimilar(req, res, next) {
    try {
      const { id, name, q } = req.query || {};
      const artistQuery = name || q || id;
      if (!artistQuery) {
        return res.status(400).json({ error: 'Missing artist query' });
      }

      let similar = [];

      if (spotifyService.isConfigured()) {
        similar = await spotifyService.getArtistSimilar(artistQuery);
      }

      if (!similar || similar.length === 0) {
        similar = await youtubeMusicService.getSimilarArtists(artistQuery);
      }

      if (!similar || similar.length === 0) {
        similar = DEMO_ARTISTS.filter((a) => a.id !== artistQuery);
      }

      return res.status(200).json({
        data: { artists: similar },
        artists: similar
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/album - Album details and track list
   */
  async album(req, res, next) {
    try {
      const { id, title, name, artist } = req.query || {};
      const albumQuery = title || name || id;
      if (!albumQuery) {
        return res.status(400).json({ error: 'Missing album query' });
      }

      let albumData = null;

      // 1. Try Spotify if configured
      if (spotifyService.isConfigured()) {
        albumData = await spotifyService.getAlbum(albumQuery);
      }

      // 2. Try YouTube Music Album resolution
      if (!albumData) {
        albumData = await youtubeMusicService.getAlbum(albumQuery, artist || '');
      }

      // 3. Fallback to local catalog
      if (!albumData) {
        const localAlbum = getAlbumById(albumQuery) || DEMO_ALBUMS[0];
        const albumTracks = DEMO_TRACKS.filter((t) => t.album.id === localAlbum.id);
        albumData = {
          album: localAlbum,
          tracks: albumTracks,
          items: albumTracks.map((t) => ({ item: t }))
        };
      }

      return res.status(200).json({
        data: albumData,
        album: albumData.album,
        tracks: albumData.tracks,
        items: albumData.items
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/playlist - Fetch YouTube / YouTube Music playlist tracks
   */
  async playlist(req, res, next) {
    try {
      const { id, url, list } = req.query || {};
      const targetId = id || url || list;
      if (!targetId) {
        return res.status(400).json({ error: 'Missing playlist id or url' });
      }

      const playlistData = await youtubeMusicService.getPlaylist(targetId);
      return res.status(200).json(playlistData);
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new MusicController();
