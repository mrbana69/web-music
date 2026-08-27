const spotifyService = require('../services/spotifyService');
const youtubeMusicService = require('../services/youtubeMusicService');
const { DEMO_TRACKS, DEMO_ARTISTS, DEMO_ALBUMS } = require('../lib/catalogData');
const { cleanText } = require('../lib/fuzzyMatcher');

class SearchController {
  async search(req, res, next) {
    try {
      const { s, a, al, q } = req.query || {};
      const query = (s || a || al || q || '').trim();
      const type = a ? 'artist' : al ? 'album' : 'track';

      if (!query) {
        return res.status(200).json({
          data: {
            items: [],
            tracks: { items: [] },
            artists: { items: [] },
            albums: { items: [] }
          }
        });
      }

      // 1. Try Spotify search if configured
      if (spotifyService.isConfigured()) {
        const spotifyResults = await spotifyService.search(query, type, 25);
        if (spotifyResults && spotifyResults.items && spotifyResults.items.length > 0) {
          return res.status(200).json({
            data: spotifyResults
          });
        }
      }

      // 2. Try YouTube Music search
      const ytCandidates = await youtubeMusicService.searchCandidates(query);
      if (ytCandidates && ytCandidates.length > 0) {
        const tracks = ytCandidates.map((c) => ({
          id: c.videoId || c.id,
          title: c.title,
          duration: c.duration,
          duration_ms: c.duration_ms,
          artist: { id: 'yt_artist', name: c.artist, picture: c.thumbnail },
          artists: [{ id: 'yt_artist', name: c.artist }],
          album: { id: 'yt_album', title: c.title, cover: c.thumbnail },
          source: 'youtube'
        }));

        const artists = [
          ...new Set(ytCandidates.map((c) => c.artist).filter(Boolean))
        ].map((name, i) => ({
          id: `yt_art_${i}`,
          name,
          picture: ytCandidates.find((c) => c.artist === name)?.thumbnail || '',
          source: 'youtube'
        }));

        const items = type === 'artist' ? artists : tracks;

        return res.status(200).json({
          data: {
            items,
            tracks: { items: tracks },
            artists: { items: artists },
            albums: { items: [] }
          }
        });
      }

      // 3. Fallback to rich catalog search
      const qNorm = cleanText(query);
      const trackMatches = DEMO_TRACKS.filter((t) => {
        const haystack = `${cleanText(t.title)} ${cleanText(t.artist.name)} ${cleanText(t.album.title)}`;
        return haystack.includes(qNorm);
      });

      const artistMatches = DEMO_ARTISTS.filter((art) => cleanText(art.name).includes(qNorm));
      const albumMatches = DEMO_ALBUMS.filter((alb) => cleanText(alb.title).includes(qNorm));

      const items = type === 'artist' ? artistMatches : type === 'album' ? albumMatches : trackMatches;

      return res.status(200).json({
        data: {
          items,
          tracks: { items: trackMatches },
          artists: { items: artistMatches },
          albums: { items: albumMatches }
        }
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new SearchController();

