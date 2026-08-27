const streamController = require('../controllers/streamController');

module.exports = async (req, res) => {
  try {
    await streamController.streamUrl(req, res, (err) => {
      if (err) {
        res.status(err.status || 500).json({ error: err.message });
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
