const musicController = require('../controllers/musicController');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization, Cookie, x-ytm-cookie, x-youtube-cookie');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

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

