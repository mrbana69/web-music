/**
 * Security HTTP Headers Middleware (CSP, framing, MIME sniffing, referrer, permissions)
 */
function securityHeaders(req, res, next) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader(
    'Content-Security-Policy',
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' https://www.youtube.com https://s.ytimg.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com data:",
      "img-src 'self' data: blob: https://*.mzstatic.com https://*.ytimg.com https://cdn-icons-png.flaticon.com https://lh3.googleusercontent.com https://*.scdn.co",
      "media-src 'self' blob: https://*.googlevideo.com",
      "frame-src https://www.youtube.com https://www.youtube-nocookie.com",
      "connect-src 'self' https://lrclib.net https://itunes.apple.com https://www.googleapis.com"
    ].join('; ')
  );
  next();
}

module.exports = securityHeaders;
