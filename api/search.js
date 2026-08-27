const searchController = require('../controllers/searchController');

module.exports = async (req, res) => {
  try {
    await searchController.search(req, res, (err) => {
      if (err) {
        res.status(err.status || 500).json({ error: err.message });
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
