const musicController = require('../controllers/musicController');

module.exports = async (req, res) => {
  try {
    await musicController.audio(req, res, (err) => {
      if (err && !res.headersSent) {
        res.status(err.status || 500).json({ error: err.message, fallback: 'youtube-embed' });
      }
    });
  } catch (err) {
    if (!res.headersSent) {
      res.status(500).json({ error: err.message, fallback: 'youtube-embed' });
    }
  }
};
