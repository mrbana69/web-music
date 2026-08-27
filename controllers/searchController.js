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

      // 1. Try Spotify if configured
      if (spotifyService.isConfigured()) {
        const spotifyResults = await spotifyService.search(query, type, 25);
        if (spotifyResults && spotifyResults.items && spotifyResults.items.length > 0) {
          return res.status(200).json({
            data: spotifyResults
          });
        }
      }

      // 2. Primary Engine: YouTube Music (Live & Free worldwide)
      const ytResults = await youtubeMusicService.search(query, type, 25);
      if (ytResults && ytResults.items && ytResults.items.length > 0) {
        return res.status(200).json({
          data: ytResults
        });
      }

      // 3. Fallback to rich local catalog search
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
