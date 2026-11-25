const crypto = require('crypto');
const authService = require('../services/authService');
const config = require('../config/env');

const OAUTH_STATE_COOKIE = 'preluded_oauth_state';
const STATE_TTL_MS = 10 * 60 * 1000;

function parseCookies(cookieHeader = '') {
  const out = {};
  for (const part of String(cookieHeader).split(';')) {
    const idx = part.indexOf('=');
    if (idx > 0) {
      out[part.slice(0, idx).trim()] = decodeURIComponent(part.slice(idx + 1).trim());
    }
  }
  return out;
}

function createSignedState(provider) {
  const payload = `${provider}.${Date.now()}.${crypto.randomBytes(16).toString('hex')}`;
  const sig = crypto.createHmac('sha256', config.sessionSecret).update(payload).digest('hex');
  return `${payload}.${sig}`;
}

function verifySignedState(state, cookieState, expectedProvider) {
  if (!state || !cookieState || state !== cookieState) return false;
  const parts = String(state).split('.');
  if (parts.length !== 4 || parts[0] !== expectedProvider) return false;
  const ts = parseInt(parts[1], 10);
  if (!Number.isFinite(ts) || Date.now() - ts > STATE_TTL_MS) return false;
  const payload = `${parts[0]}.${parts[1]}.${parts[2]}`;
  const expectedSig = crypto.createHmac('sha256', config.sessionSecret).update(payload).digest('hex');
  try {
    return crypto.timingSafeEqual(Buffer.from(parts[3], 'hex'), Buffer.from(expectedSig, 'hex'));
  } catch {
    return false;
  }
}

function setStateCookie(res, state, req) {
  const isHttps = req.secure || req.headers['x-forwarded-proto'] === 'https';
  res.setHeader(
    'Set-Cookie',
    `${OAUTH_STATE_COOKIE}=${encodeURIComponent(state)}; Path=/api/auth; HttpOnly; SameSite=Lax; Max-Age=600${isHttps ? '; Secure' : ''}`
  );
}

function isAllowedHost(rawHost = '') {
  const host = String(rawHost).split(':')[0].toLowerCase().trim();
  if (!host || !/^[a-z0-9.-]+$/.test(host)) return false;
  if (host === 'localhost' || host === '127.0.0.1' || host.endsWith('.vercel.app')) return true;
  return config.allowedHosts.includes(host);
}

function resolveGoogleRedirectUri(req) {
  if (config.google.redirectUri && !config.google.redirectUri.includes('localhost')) {
    return config.google.redirectUri;
  }
  const forwardedHost = req.headers['x-forwarded-host'] || req.get('host');
  if (isAllowedHost(forwardedHost)) {
    const protocol = req.headers['x-forwarded-proto'] === 'https' ? 'https' : (req.protocol || 'http');
    return `${protocol}://${forwardedHost}/api/auth/google/callback`;
  }
  return config.google.redirectUri || 'http://localhost:3000/api/auth/google/callback';
}

class AuthController {
  // ==========================================
  // Spotify 1-Click Login & Callback
  // ==========================================
  spotifyLogin(req, res, next) {
    try {
      const { redirect } = req.query || {};
      const state = createSignedState('spotify');
      const authUrl = authService.getSpotifyAuthUrl(state);

      if (!authUrl) {
        return res.status(200).json({
          configured: false,
          message: 'Spotify Client ID is not configured in .env. Running in demo mode.',
          demoLoginUrl: '/api/auth/spotify/callback?code=demo_code'
        });
      }

      setStateCookie(res, state, req);
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
      const { code, error, state } = req.query || {};
      if (error) {
        return res.status(400).json({ error: 'Spotify login failed' });
      }

      if (!code) {
        return res.status(400).json({ error: 'Missing authorization code' });
      }

      if (config.spotify.clientId && config.spotify.clientSecret) {
        const cookies = parseCookies(req.headers.cookie);
        if (!verifySignedState(state, cookies[OAUTH_STATE_COOKIE], 'spotify')) {
          return res.status(403).json({ error: 'Invalid or expired OAuth state parameter' });
        }
      }

      const tokenData = await authService.exchangeSpotifyCode(code);

      // Deliver tokens via URL fragment so they are never sent in HTTP requests, Referer, or server logs
      const acceptHeader = req.headers.accept || '';
      if (acceptHeader.includes('text/html')) {
        const tokenParams = new URLSearchParams({
          provider: 'spotify',
          access_token: tokenData.access_token || '',
          user_name: tokenData.user?.display_name || ''
        });
        return res.redirect(`/#${tokenParams.toString()}`);
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
      const dynamicRedirectUri = resolveGoogleRedirectUri(req);
      const state = createSignedState('google');
      const authUrl = authService.getGoogleAuthUrl(state, dynamicRedirectUri);

      if (!authUrl) {
        return res.status(200).json({
          configured: false,
          message: 'Google Client ID is not configured in .env. Running in demo mode.',
          demoLoginUrl: '/api/auth/google/callback?code=demo_code'
        });
      }

      setStateCookie(res, state, req);
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
      const { code, error, state } = req.query || {};
      if (error) {
        return res.status(400).json({ error: 'Google login failed' });
      }

      if (!code) {
        return res.status(400).json({ error: 'Missing authorization code' });
      }

      if (config.google.clientId && config.google.clientSecret) {
        const cookies = parseCookies(req.headers.cookie);
        if (!verifySignedState(state, cookies[OAUTH_STATE_COOKIE], 'google')) {
          return res.status(403).json({ error: 'Invalid or expired OAuth state parameter' });
        }
      }

      const dynamicRedirectUri = resolveGoogleRedirectUri(req);
      const tokenData = await authService.exchangeGoogleCode(code, dynamicRedirectUri);

      const tokenParams = new URLSearchParams({
        provider: 'google',
        access_token: tokenData.access_token || '',
        refresh_token: tokenData.refresh_token || '',
        user_name: tokenData.user?.name || ''
      });

      const format = req.query.format || '';
      if (format === 'json') {
        return res.status(200).json(tokenData);
      }

      return res.redirect(`/app#${tokenParams.toString()}`);
    } catch (err) {
      next(err);
    }
  }

  async googleRefresh(req, res, next) {
    try {
      const { refresh_token } = req.body || req.query || {};
      if (!refresh_token) {
        return res.status(400).json({ error: 'Missing refresh_token' });
      }

      const refreshed = await authService.refreshGoogleToken(refresh_token);
      return res.status(200).json(refreshed);
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

  async googleQuickPicks(req, res, next) {
    try {
      const authHeader = req.headers.authorization || '';
      const token = authHeader.replace(/^Bearer\s+/i, '') || req.query.token || req.query.access_token || null;
      const limit = parseInt(req.query.limit, 10) || 20;

      const youtubeMusicService = require('../services/youtubeMusicService');
      const quickPicksData = await youtubeMusicService.getQuickPicks(token, limit);
      return res.status(200).json({
        ok: true,
        data: quickPicksData,
        ...quickPicksData
      });
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

