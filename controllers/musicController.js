const spotifyService = require('../services/spotifyService');
const youtubeMusicService = require('../services/youtubeMusicService');
const trackResolverService = require('../services/trackResolverService');
const streamResolutionService = require('../services/streamResolutionService');
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

      return res.status(200).json(manifestPayload);
    } catch (err) {
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
