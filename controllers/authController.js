const authService = require('../services/authService');
const config = require('../config/env');

class AuthController {
  // ==========================================
  // Spotify 1-Click Login & Callback
  // ==========================================
  spotifyLogin(req, res, next) {
    try {
      const { redirect } = req.query || {};
      const authUrl = authService.getSpotifyAuthUrl(req.query?.state || '');

      if (!authUrl) {
        return res.status(200).json({
          configured: false,
          message: 'Spotify Client ID is not configured in .env. Running in demo mode.',
          demoLoginUrl: '/api/auth/spotify/callback?code=demo_code'
        });
      }

      if (redirect === 'true' || redirect === '1') {
        return res.redirect(authUrl);
      }

      return res.status(200).json({ url: authUrl, configured: true });
    } catch (err) {
      next(err);
    }
  }

  async spotifyCallback(req, res, next) {
    try {
      const { code, error } = req.query || {};
      if (error) {
        return res.status(400).json({ error: `Spotify login failed: ${error}` });
      }

      if (!code) {
        return res.status(400).json({ error: 'Missing authorization code' });
      }

      const tokenData = await authService.exchangeSpotifyCode(code);

      // If requested directly from browser address bar, redirect back to root with auth query
      const acceptHeader = req.headers.accept || '';
      if (acceptHeader.includes('text/html')) {
        const tokenParams = new URLSearchParams({
          provider: 'spotify',
          access_token: tokenData.access_token || '',
          user_name: tokenData.user?.display_name || ''
        });
        return res.redirect(`/?${tokenParams.toString()}`);
      }

      return res.status(200).json(tokenData);
    } catch (err) {
      next(err);
    }
  }

  async spotifyRefresh(req, res, next) {
    try {
      const { refresh_token } = req.body || req.query || {};
      if (!refresh_token) {
        return res.status(400).json({ error: 'Missing refresh_token' });
      }

      const refreshed = await authService.refreshSpotifyToken(refresh_token);
      return res.status(200).json(refreshed);
    } catch (err) {
      next(err);
    }
  }

  // ==========================================
  // Google 1-Click Login & Callback
  // ==========================================
  googleLogin(req, res, next) {
    try {
      const { redirect } = req.query || {};
      const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
      const host = req.headers['x-forwarded-host'] || req.get('host') || 'localhost:3000';
      const dynamicRedirectUri = config.google.redirectUri && !config.google.redirectUri.includes('localhost')
        ? config.google.redirectUri
        : `${protocol}://${host}/api/auth/google/callback`;

      const authUrl = authService.getGoogleAuthUrl(req.query?.state || '', dynamicRedirectUri);

      if (!authUrl) {
        return res.status(200).json({
          configured: false,
          message: 'Google Client ID is not configured in .env. Running in demo mode.',
          demoLoginUrl: '/api/auth/google/callback?code=demo_code'
        });
      }

      if (redirect === 'true' || redirect === '1') {
        return res.redirect(authUrl);
      }

      return res.status(200).json({ url: authUrl, configured: true });
    } catch (err) {
      next(err);
    }
  }

  async googleCallback(req, res, next) {
    try {
      const { code, error } = req.query || {};
      if (error) {
        return res.status(400).json({ error: `Google login failed: ${error}` });
      }

      if (!code) {
        return res.status(400).json({ error: 'Missing authorization code' });
      }

      const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
      const host = req.headers['x-forwarded-host'] || req.get('host') || 'localhost:3000';
      const dynamicRedirectUri = config.google.redirectUri && !config.google.redirectUri.includes('localhost')
        ? config.google.redirectUri
        : `${protocol}://${host}/api/auth/google/callback`;

      const tokenData = await authService.exchangeGoogleCode(code, dynamicRedirectUri);

      const acceptHeader = req.headers.accept || '';
      if (acceptHeader.includes('text/html')) {
        const tokenParams = new URLSearchParams({
          provider: 'google',
          access_token: tokenData.access_token || '',
          user_name: tokenData.user?.name || ''
        });
        return res.redirect(`/?${tokenParams.toString()}`);
      }

      return res.status(200).json(tokenData);
    } catch (err) {
      next(err);
    }
  }

  async googleLibrary(req, res, next) {
    try {
      const authHeader = req.headers.authorization || '';
      const token = authHeader.replace(/^Bearer\s+/i, '') || req.query.token || req.query.access_token;

      if (!token) {
        return res.status(200).json({ playlists: [], likedSongs: [] });
      }

      const library = await authService.getUserLibrary(token);
      return res.status(200).json(library);
    } catch (err) {
      next(err);
    }
  }

  // ==========================================
  // YouTube Device Code Flow (TV / CLI Fallback)
  // ==========================================
  ytGetCode(req, res, next) {
    try {
      const codeInfo = authService.getDeviceCode();
      return res.status(200).json(codeInfo);
    } catch (err) {
      next(err);
    }
  }

  ytVerifyCode(req, res, next) {
    try {
      const { deviceCode, code } = req.query || req.body || {};
      const targetCode = deviceCode || code;

      if (!targetCode) {
        return res.status(400).json({ error: 'Missing deviceCode parameter' });
      }

      const result = authService.verifyDeviceCode(targetCode);
      return res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  }

  // ==========================================
  // Session / Providers Status
  // ==========================================
  session(req, res, next) {
    try {
      return res.status(200).json({
        providers: {
          spotify: {
            configured: Boolean(config.spotify.clientId && config.spotify.clientSecret),
            clientId: config.spotify.clientId ? `${config.spotify.clientId.substring(0, 6)}...` : null
          },
          google: {
            configured: Boolean(config.google.clientId && config.google.clientSecret),
            clientId: config.google.clientId ? `${config.google.clientId.substring(0, 6)}...` : null
          },
          youtubeMusic: {
            configured: true,
            hasCookie: Boolean(config.youtubeMusic.cookie)
          }
        },
        user: req.userToken ? { authenticated: true } : { authenticated: false, guest: true }
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new AuthController();

