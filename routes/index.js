const express = require('express');
const router = express.Router();

const searchRoutes = require('./searchRoutes');
const musicRoutes = require('./musicRoutes');
const resolveRoutes = require('./resolveRoutes');
const streamRoutes = require('./streamRoutes');
const authRoutes = require('./authRoutes');
const healthRoutes = require('./healthRoutes');
const authController = require('../controllers/authController');

// Sub-routes mounted under /api
router.use('/search', searchRoutes);
router.use('/resolve', resolveRoutes);
router.use('/stream-url', streamRoutes);
router.use('/auth', authRoutes);
router.use('/health', healthRoutes);

// Music routes: /api/info, /api/track, /api/mix, /api/artist, /api/album
router.use('/', musicRoutes);

// Direct aliases for TV device flow compatibility
router.get('/yt/get-code', (req, res, next) => authController.ytGetCode(req, res, next));
router.post('/yt/get-code', (req, res, next) => authController.ytGetCode(req, res, next));
router.get('/yt/verify-code', (req, res, next) => authController.ytVerifyCode(req, res, next));
router.post('/yt/verify-code', (req, res, next) => authController.ytVerifyCode(req, res, next));

module.exports = router;

