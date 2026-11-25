const streamResolutionService = require('../services/streamResolutionService');

class StreamController {
  async streamUrl(req, res, next) {
    try {
      const { videoId } = req.query || {};

      if (!videoId) {
        return res.status(400).json({ error: 'Missing videoId query parameter' });
      }
      if (!/^[a-zA-Z0-9_-]{3,64}$/.test(String(videoId))) {
        return res.status(400).json({ error: 'Invalid videoId parameter format' });
      }

      const streamInfo = await streamResolutionService.resolveStreamUrl(videoId);

      return res.status(200).json({
        videoId: streamInfo.videoId,
        directUrl: streamInfo.directUrl,
        mimeType: streamInfo.mimeType,
        expiresInSeconds: streamInfo.expiresInSeconds,
        source: streamInfo.source
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new StreamController();

