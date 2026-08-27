const musicController = require('../controllers/musicController');

module.exports = async (req, res) => {
  try {
    await musicController.artist(req, res, (err) => {
      if (err) {
        res.status(err.status || 500).json({ error: err.message });
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
