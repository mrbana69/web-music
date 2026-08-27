const express = require('express');
const router = express.Router();
const config = require('../config/env');
const cacheService = require('../services/cacheService');

router.get('/', (req, res) => {
  res.status(200).json({
    ok: true,
    service: 'preluded-api',
    version: '2.0.0',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    cacheItems: cacheService.size(),
    spotifyConfigured: Boolean(config.spotify.clientId && config.spotify.clientSecret),
    googleConfigured: Boolean(config.google.clientId && config.google.clientSecret)
  });
});

module.exports = router;

