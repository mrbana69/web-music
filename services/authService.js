const config = require('../config/env');
const { fetchJson } = require('../lib/httpClient');
const cacheService = require('./cacheService');

function cleanArtistName(raw) {
  if (!raw || typeof raw !== 'string') return 'Artist';
  let clean = raw.trim();
  clean = clean.replace(/\s*-\s*Topic\b/gi, '');
  clean = clean.replace(/Topic$/i, '');
  clean = clean.replace(/\s*VEVO\b/gi, '');
  clean = clean.replace(/VEVO$/i, '');
  clean = clean.replace(/\s*Official(?:\s*Channel|\s*Artist\s*Channel)?\b/gi, '');
  clean = clean.replace(/\s*-\s*Official$/gi, '');
  clean = clean.replace(/\s*Records\b/gi, '');
  clean = clean.replace(/\s+/g, ' ').trim();
  return clean || 'Artist';
}

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
  getGoogleAuthUrl(state = '', customRedirectUri = '') {
    if (!config.google.clientId) {
      return null;
    }

    const redirectUri = customRedirectUri || config.google.redirectUri;

    const params = new URLSearchParams({
      client_id: config.google.clientId,
      redirect_uri: redirectUri,
      response_type: 'code',
      scope: config.google.scopes.join(' '),
      access_type: 'offline',
      prompt: 'consent select_account',
      include_granted_scopes: 'true',
      state: state || 'google_login'
    });

    return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
  }

  async exchangeGoogleCode(code, customRedirectUri = '') {
    if (!config.google.clientId || !config.google.clientSecret) {
      return {
        access_token: 'demo_google_access_token',
        refresh_token: 'demo_google_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer',
        user: { name: 'Google User (Demo)', email: 'user@example.com' }
      };
    }

    const redirectUri = customRedirectUri || config.google.redirectUri;

    const body = new URLSearchParams({
      code,
      client_id: config.google.clientId,
      client_secret: config.google.clientSecret,
      redirect_uri: redirectUri,
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

  async getUserLibrary(accessToken) {
    if (!accessToken || accessToken === 'demo_google_access_token') {
      return {
        playlists: [],
        likedSongs: []
      };
    }

    const headers = {
      'Authorization': `Bearer ${accessToken}`,
      'Accept': 'application/json'
    };

    let playlists = [];
    let likedSongs = [];
    let requiresReauth = false;

    // 1. Fetch user's YouTube playlists
    try {
      const plData = await fetchJson('https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&mine=true&maxResults=50', { headers, timeout: 5000 });
      if (plData && plData.items) {
        playlists = await Promise.all(plData.items.map(async (p) => {
          let songs = [];
          try {
            const itemsData = await fetchJson(`https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=${p.id}&maxResults=50`, { headers, timeout: 4000 });
            if (itemsData && itemsData.items) {
              songs = itemsData.items.map(item => {
                const title = item.snippet?.title || '';
                const channelTitle = cleanArtistName(item.snippet?.videoOwnerChannelTitle || item.snippet?.channelTitle || 'Artist');
                const vId = item.contentDetails?.videoId || item.snippet?.resourceId?.videoId;
                const rawThumb = item.snippet?.thumbnails?.high?.url || item.snippet?.thumbnails?.medium?.url || '';
                const thumb = rawThumb.includes('googleusercontent.com') ? rawThumb.replace(/=[ws]\d+.*$/, '=w500-h500-l90-rj') : (rawThumb.replace(/\/hqdefault\.jpg/, '/maxresdefault.jpg'));
                return {
                  id: vId,
                  videoId: vId,
                  title,
                  artist: { id: `art_${vId}`, name: channelTitle, picture: thumb },
                  artists: [{ name: channelTitle }],
                  album: { id: `alb_${vId}`, title, cover: thumb },
                  duration: 210,
                  duration_ms: 210000,
                  source: 'youtube-playlist'
                };
              }).filter(s => s.id && s.title && s.title !== 'Deleted video' && s.title !== 'Private video');
            }
          } catch (e) {}

          const rawThumb = p.snippet?.thumbnails?.high?.url || p.snippet?.thumbnails?.medium?.url || (songs[0]?.album?.cover) || '';
          const cover = rawThumb.includes('googleusercontent.com') ? rawThumb.replace(/=[ws]\d+.*$/, '=w500-h500-l90-rj') : (rawThumb.replace(/\/hqdefault\.jpg/, '/maxresdefault.jpg'));
          return {
            id: p.id,
            name: p.snippet?.title || 'Playlist',
            title: p.snippet?.title || 'Playlist',
            cover,
            itemCount: songs.length || p.contentDetails?.itemCount || 0,
            songs
          };
        }));
      }
    } catch (e) {
      console.warn('[AuthService] Fetching YouTube playlists failed:', e.message);
      if (e.message && (e.message.includes('401') || e.message.includes('403') || e.message.includes('insufficient'))) {
        requiresReauth = true;
      }
    }

    // 2. Fetch user's Liked videos (Try videos?myRating=like, then fallback to LL/LM playlists)
    try {
      const likedData = await fetchJson('https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&myRating=like&maxResults=50', { headers, timeout: 5000 });
      if (likedData && likedData.items) {
        likedSongs = likedData.items.map(v => {
          const title = v.snippet?.title || '';
          const channelTitle = cleanArtistName(v.snippet?.channelTitle || 'Artist');
          const rawThumb = v.snippet?.thumbnails?.high?.url || v.snippet?.thumbnails?.medium?.url || '';
          const thumb = rawThumb.includes('googleusercontent.com') ? rawThumb.replace(/=[ws]\d+.*$/, '=w500-h500-l90-rj') : (rawThumb.replace(/\/hqdefault\.jpg/, '/maxresdefault.jpg'));
          return {
            id: v.id,
            videoId: v.id,
            title,
            artist: { id: `art_${v.id}`, name: channelTitle, picture: thumb },
            artists: [{ name: channelTitle }],
            album: { id: `alb_${v.id}`, title, cover: thumb },
            duration: 210,
            duration_ms: 210000,
            source: 'youtube-liked'
          };
        }).filter(s => s.id && s.title);
      }
    } catch (e) {
      console.warn('[AuthService] Fetching YouTube liked videos failed, trying LL playlist:', e.message);
      if (e.message && (e.message.includes('401') || e.message.includes('403') || e.message.includes('insufficient'))) {
        requiresReauth = true;
      }
    }

    // Fallback for liked songs: fetch "LL" (Liked List) or "LM" (Liked Music) playlist
    if (likedSongs.length === 0) {
      for (const plId of ['LL', 'LM']) {
        try {
          const llData = await fetchJson(`https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=${plId}&maxResults=50`, { headers, timeout: 4000 });
          if (llData && llData.items && llData.items.length > 0) {
            likedSongs = llData.items.map(item => {
              const title = item.snippet?.title || '';
              const channelTitle = cleanArtistName(item.snippet?.videoOwnerChannelTitle || item.snippet?.channelTitle || 'Artist');
              const vId = item.contentDetails?.videoId || item.snippet?.resourceId?.videoId;
              const rawThumb = item.snippet?.thumbnails?.high?.url || item.snippet?.thumbnails?.medium?.url || '';
              const thumb = rawThumb.includes('googleusercontent.com') ? rawThumb.replace(/=[ws]\d+.*$/, '=w500-h500-l90-rj') : (rawThumb.replace(/\/hqdefault\.jpg/, '/maxresdefault.jpg'));
              return {
                id: vId,
                videoId: vId,
                title,
                artist: { id: `art_${vId}`, name: channelTitle, picture: thumb },
                artists: [{ name: channelTitle }],
                album: { id: `alb_${vId}`, title, cover: thumb },
                duration: 210,
                duration_ms: 210000,
                source: 'youtube-liked'
              };
            }).filter(s => s.id && s.title && s.title !== 'Deleted video' && s.title !== 'Private video');
            break;
          }
        } catch (err) {}
      }
    }

    return {
      playlists,
      likedSongs,
      requiresReauth: requiresReauth && playlists.length === 0 && likedSongs.length === 0
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

