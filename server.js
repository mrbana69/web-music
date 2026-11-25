const express = require('express');
const path = require('path');
const config = require('./config/env');
const corsMiddleware = require('./middleware/cors');
const securityHeaders = require('./middleware/securityHeaders');
const { createRateLimiter } = require('./middleware/rateLimit');
const requestLogger = require('./middleware/requestLogger');
const { extractAuth } = require('./middleware/auth');
const errorHandler = require('./middleware/errorHandler');
const apiRoutes = require('./routes/index');
const healthRoutes = require('./routes/healthRoutes');

const app = express();
const PORT = config.port;

// Trust reverse proxies (Vercel, Nginx, Cloudflare)
app.set('trust proxy', 1);

// Middleware
app.use(securityHeaders);
app.use(corsMiddleware);
app.use(express.json({ limit: '256kb' }));
app.use(express.urlencoded({ extended: true, limit: '256kb' }));
app.use(requestLogger);
app.use(extractAuth);

// Rate limiting on auth and API routes
app.use('/api/auth', createRateLimiter({ windowMs: 60_000, max: 30 }));
app.use('/api', createRateLimiter({ windowMs: 60_000, max: 180 }));

// Mount API routes
app.use('/api', apiRoutes);
app.use('/health', healthRoutes);

// Static assets (PWA frontend)
app.use(express.static(__dirname));

// Route /app and /player directly to app.html
app.get('/app', (req, res) => {
  res.sendFile(path.join(__dirname, 'app.html'));
});
app.get('/player', (req, res) => {
  res.sendFile(path.join(__dirname, 'app.html'));
});
app.get('/privacy', (req, res) => {
  res.sendFile(path.join(__dirname, 'privacy.html'));
});
app.get('/tos', (req, res) => {
  res.sendFile(path.join(__dirname, 'tos.html'));
});
app.get('/terms', (req, res) => {
  res.sendFile(path.join(__dirname, 'tos.html'));
});

// SPA Fallback: serve index.html for root, 404 for unknown routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Unknown routes return 404 with branded error page
app.use((req, res) => {
  res.status(404).sendFile(path.join(__dirname, '404.html'));
});

// Error handling middleware
app.use(errorHandler);

if (require.main === module && !process.env.VERCEL && process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`====================================================`);
    console.log(`  Preluded Music API running at http://localhost:${PORT}`);
    console.log(`  Environment: ${config.nodeEnv}`);
    console.log(`  Spotify Auth: ${config.spotify.clientId ? 'Configured' : 'Demo/Catalog Mode'}`);
    console.log(`  Google Auth:  ${config.google.clientId ? 'Configured' : 'Demo/Catalog Mode'}`);
    console.log(`====================================================`);
  });
}

module.exports = app;
