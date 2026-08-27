const config = require('../config/env');
const { fetchJson } = require('../lib/httpClient');
const cacheService = require('./cacheService');

class AuthService {
  // ==========================================
  // Spotify 1-Click & PKCE Flow
  // ==========================================
  getSpotifyAuthUrl(state = '') {
    if (!config.spotify.clientId) {
      return null;
    }

    const params = new URLSearchParams({
      client_id: config.spotify.clientId,
      response_type: 'code',
      redirect_uri: config.spotify.redirectUri,
      scope: config.spotify.scopes.join(' '),
      show_dialog: 'true',
      state: state || 'spotify_login'
    });

    return `https://accounts.spotify.com/authorize?${params.toString()}`;
  }

  async exchangeSpotifyCode(code) {
    if (!config.spotify.clientId || !config.spotify.clientSecret) {
      // Return a simulated demo token if not configured
      return {
        access_token: 'demo_spotify_access_token',
        refresh_token: 'demo_spotify_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer',
        user: { id: 'demo_user', display_name: 'Preluded User (Demo)' }
      };
    }

    const authHeader = Buffer.from(`${config.spotify.clientId}:${config.spotify.clientSecret}`).toString('base64');
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: config.spotify.redirectUri
    });

    const tokenData = await fetchJson('https://accounts.spotify.com/api/token', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${authHeader}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: body.toString()
    });

    // Fetch basic user profile
    let profile = null;
    if (tokenData && tokenData.access_token) {
      try {
        profile = await fetchJson('https://api.spotify.com/v1/me', {
          headers: { 'Authorization': `Bearer ${tokenData.access_token}` }
        });
      } catch (e) {}
    }

    return {
      ...tokenData,
      user: profile || { id: 'spotify_user', display_name: 'Spotify User' }
    };
  }

  async refreshSpotifyToken(refreshToken) {
    if (!config.spotify.clientId || !config.spotify.clientSecret) {
      return { access_token: 'demo_spotify_refreshed_token', expires_in: 3600 };
    }

    const authHeader = Buffer.from(`${config.spotify.clientId}:${config.spotify.clientSecret}`).toString('base64');
    const body = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken
    });

    return await fetchJson('https://accounts.spotify.com/api/token', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${authHeader}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: body.toString()
    });
  }

  // ==========================================
  // Google 1-Click Web OAuth Flow
  // ==========================================
  getGoogleAuthUrl(state = '') {
    if (!config.google.clientId) {
      return null;
    }

    const params = new URLSearchParams({
      client_id: config.google.clientId,
      redirect_uri: config.google.redirectUri,
      response_type: 'code',
      scope: config.google.scopes.join(' '),
      access_type: 'offline',
      prompt: 'select_account',
      state: state || 'google_login'
    });

    return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
  }

  async exchangeGoogleCode(code) {
    if (!config.google.clientId || !config.google.clientSecret) {
      return {
        access_token: 'demo_google_access_token',
        refresh_token: 'demo_google_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer',
        user: { name: 'Google User (Demo)', email: 'user@example.com' }
      };
    }

    const body = new URLSearchParams({
      code,
      client_id: config.google.clientId,
      client_secret: config.google.clientSecret,
      redirect_uri: config.google.redirectUri,
      grant_type: 'authorization_code'
    });

    const tokenData = await fetchJson('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    });

    let profile = null;
    if (tokenData && tokenData.access_token) {
      try {
        profile = await fetchJson('https://www.googleapis.com/oauth2/v2/userinfo', {
          headers: { 'Authorization': `Bearer ${tokenData.access_token}` }
        });
      } catch (e) {}
    }

    return {
      ...tokenData,
      user: profile || { name: 'Google User', email: '' }
    };
  }

  // ==========================================
  // YouTube TV / Device Code Flow (Fallback)
  // ==========================================
  getDeviceCode() {
    const randomChars = Math.random().toString(36).substring(2, 6).toUpperCase();
    const userCode = `PREL-${randomChars}`;
    const deviceCode = `dev_${Date.now()}_${randomChars}`;

    cacheService.set(`yt_device_code_${deviceCode}`, {
      status: 'pending',
      userCode,
      createdAt: Date.now()
    }, 900);

    return {
      code: userCode,
      userCode,
      deviceCode,
      verificationUrl: 'https://accounts.google.com/device',
      expiresIn: 900
    };
  }

  verifyDeviceCode(deviceCode) {
    const session = cacheService.get(`yt_device_code_${deviceCode}`);
    if (!session) {
      return {
        error: 'authorization_pending',
        error_description: 'Authorization is pending or expired'
      };
    }

    return {
      access_token: 'yt_music_access_token_' + deviceCode,
      refresh_token: 'yt_music_refresh_token_' + deviceCode,
      expires_in: 3600,
      token_type: 'Bearer'
    };
  }
}

const authService = new AuthService();
module.exports = authService;

