const cors = require('cors');
const config = require('../config/env');

const allowedOrigins = config.corsOrigin === '*'
  ? []
  : config.corsOrigin.split(',').map((o) => o.trim()).filter(Boolean);

const corsOptions = {
  origin(origin, callback) {
    // Allow non-browser / same-origin requests with no Origin header
    if (!origin) return callback(null, false);
    if (allowedOrigins.includes(origin)) return callback(null, origin);
    // When CORS_ORIGIN=*, allow public non-credentialed read access only
    if (config.corsOrigin === '*') return callback(null, '*');
    return callback(null, false);
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'X-YTM-Cookie', 'X-YouTube-Cookie'],
  credentials: allowedOrigins.length > 0
};

module.exports = cors(corsOptions);
