const musicController = require('../controllers/musicController');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,HEAD');
  res.setHeader('Access-Control-Allow-Headers', 'Range, Authorization, X-Requested-With, Content-Type, Accept');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    await musicController.stream(req, res, (err) => {
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

