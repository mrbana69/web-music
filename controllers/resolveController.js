const trackResolverService = require('../services/trackResolverService');

class ResolveController {
  async resolve(req, res, next) {
    try {
      const { title, artist, duration_ms, duration, id } = req.query || {};

      if (!title && !artist && !id) {
        return res.status(400).json({ error: 'Missing title, artist, or id query parameters' });
      }

      const match = await trackResolverService.resolveTrack({
        id,
        title,
        artist,
        duration_ms: duration_ms ? Number(duration_ms) : undefined,
        duration: duration ? Number(duration) : undefined
      });

      return res.status(200).json({
        videoId: match.videoId,
        title: match.title,
        artist: match.artist,
        duration_ms: match.duration_ms,
        score: match.score,
        source: match.source,
        thumbnail: match.thumbnail || ''
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new ResolveController();

