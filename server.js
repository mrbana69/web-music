const express = require('express');
const path = require('path');
const config = require('./config/env');
const corsMiddleware = require('./middleware/cors');
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
app.use(corsMiddleware);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(requestLogger);
app.use(extractAuth);

// Mount API routes
app.use('/api', apiRoutes);
app.use('/health', healthRoutes);

// Static assets (PWA frontend)
app.use(express.static(__dirname));

// SPA Fallback: serve index.html for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Error handling middleware
app.use(errorHandler);

if (require.main === module && !process.env.VERCEL && process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    const fs = require('fs');
    const logLine = `[${new Date().toISOString()}] [Server] Preluded Music API listening on http://localhost:${PORT}\n`;
    try { fs.appendFileSync(path.join(__dirname, 'server.log'), logLine, 'utf8'); } catch(_) {}
    console.log(`====================================================`);
    console.log(`  Preluded Music API running at http://localhost:${PORT}`);
    console.log(`  Environment: ${config.nodeEnv}`);
    console.log(`  Spotify Auth: ${config.spotify.clientId ? 'Configured' : 'Demo/Catalog Mode'}`);
    console.log(`  Google Auth:  ${config.google.clientId ? 'Configured' : 'Demo/Catalog Mode'}`);
    console.log(`====================================================`);
  });
}

module.exports = app;
