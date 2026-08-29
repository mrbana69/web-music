const express = require('express');
const router = express.Router();
const musicController = require('../controllers/musicController');

// /api/info
router.get('/info', (req, res, next) => musicController.info(req, res, next));

// /api/track
router.get('/track', (req, res, next) => musicController.track(req, res, next));

// /api/mix
router.get('/mix', (req, res, next) => musicController.mix(req, res, next));

// /api/artist and /api/artist/similar
router.get('/artist/similar', (req, res, next) => musicController.artistSimilar(req, res, next));
router.get('/artist', (req, res, next) => musicController.artist(req, res, next));

// /api/album
router.get('/album', (req, res, next) => musicController.album(req, res, next));

// /api/playlist
router.get('/playlist', (req, res, next) => musicController.playlist(req, res, next));

// /api/quick-picks (YouTube Music Scelte rapide)
router.get('/quick-picks', (req, res, next) => musicController.quickPicks(req, res, next));
router.get('/quickpicks', (req, res, next) => musicController.quickPicks(req, res, next));

module.exports = router;

