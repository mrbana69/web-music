const express = require('express');
const router = express.Router();
const musicController = require('../controllers/musicController');

// /api/info
router.get('/info', (req, res, next) => musicController.info(req, res, next));

// /api/track
router.get('/track', (req, res, next) => musicController.track(req, res, next));

// /api/stream and iOS-friendly aliases
router.get('/stream', (req, res, next) => musicController.stream(req, res, next));
router.get('/stream.mp4', (req, res, next) => musicController.stream(req, res, next));
router.get('/stream.m4a', (req, res, next) => musicController.stream(req, res, next));

// /api/audio
router.get('/audio', (req, res, next) => musicController.audio(req, res, next));

// /api/mix
router.get('/mix', (req, res, next) => musicController.mix(req, res, next));

// /api/home
router.get('/home', (req, res, next) => musicController.home(req, res, next));

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

