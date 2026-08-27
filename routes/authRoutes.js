const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// Spotify Auth
router.get('/spotify/login', (req, res, next) => authController.spotifyLogin(req, res, next));
router.get('/spotify/callback', (req, res, next) => authController.spotifyCallback(req, res, next));
router.post('/spotify/refresh', (req, res, next) => authController.spotifyRefresh(req, res, next));
router.get('/spotify/refresh', (req, res, next) => authController.spotifyRefresh(req, res, next));

// Google Auth
router.get('/google/login', (req, res, next) => authController.googleLogin(req, res, next));
router.get('/google/callback', (req, res, next) => authController.googleCallback(req, res, next));

// YouTube TV Device Code Flow
router.get('/yt/get-code', (req, res, next) => authController.ytGetCode(req, res, next));
router.post('/yt/get-code', (req, res, next) => authController.ytGetCode(req, res, next));
router.get('/yt/verify-code', (req, res, next) => authController.ytVerifyCode(req, res, next));
router.post('/yt/verify-code', (req, res, next) => authController.ytVerifyCode(req, res, next));

// Session & providers state
router.get('/session', (req, res, next) => authController.session(req, res, next));

module.exports = router;

