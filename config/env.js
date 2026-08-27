const path = require('path');
const dotenv = require('dotenv');

// Load .env file from project root
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  corsOrigin: process.env.CORS_ORIGIN || '*',

  // Spotify Configuration
  spotify: {
    clientId: process.env.SPOTIFY_CLIENT_ID || '',
    clientSecret: process.env.SPOTIFY_CLIENT_SECRET || '',
    redirectUri: process.env.SPOTIFY_REDIRECT_URI || 'http://localhost:3000/api/auth/spotify/callback',
    scopes: [
      'user-read-private',
      'user-read-email',
      'user-library-read',
      'playlist-read-private',
      'playlist-read-collaborative',
      'user-top-read'
    ]
  },

  // Google / YouTube Configuration (Standard non-sensitive scopes)
  google: {
    clientId: process.env.GOOGLE_CLIENT_ID || '',
    clientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
    redirectUri: process.env.GOOGLE_REDIRECT_URI || 'http://localhost:3000/api/auth/google/callback',
    scopes: [
      'openid',
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/userinfo.email'
    ]
  },

  // YouTube Music engine options
  youtubeMusic: {
    cookie: process.env.YTM_COOKIE || process.env.YT_COOKIES || '',
    authHeader: process.env.YTM_AUTH_HEADER || '',
    ytdlpPath: process.env.YTDLP_PATH || 'yt-dlp'
  },

  // Cache Configuration (in seconds)
  cache: {
    resolverTtl: parseInt(process.env.RESOLVER_CACHE_TTL || '86400', 10), // 24 hours
    streamTtl: parseInt(process.env.STREAM_CACHE_TTL || '21600', 10),     // 6 hours
    metadataTtl: parseInt(process.env.METADATA_CACHE_TTL || '3600', 10)  // 1 hour
  },

  sessionSecret: process.env.SESSION_SECRET || 'preluded_dev_secret_session_key'
};

module.exports = config;
