const streamResolutionService = require('../services/streamResolutionService');

class StreamController {
  async streamUrl(req, res, next) {
    try {
      const { videoId, id } = req.query || {};
      const targetId = videoId || id;

      if (!targetId) {
        return res.status(400).json({ error: 'Missing videoId or id query parameter' });
      }

      const authHeader = req.headers.authorization || '';
      const cookieHeader = req.headers['x-ytm-cookie'] || req.headers['x-youtube-cookie'] || req.headers['cookie'];
      const userCookie = req.query.ytm_cookie || req.query.cookie || cookieHeader || (authHeader.startsWith('Cookie ') ? authHeader.substring(7) : (authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null));

      const streamInfo = await streamResolutionService.resolveStreamUrl(targetId, userCookie);

      return res.status(200).json({
        videoId: streamInfo.videoId,
        directUrl: streamInfo.directUrl,
        streamUrl: streamInfo.directUrl,
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

