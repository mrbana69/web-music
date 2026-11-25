/**
 * Lightweight request logger middleware with query secret redaction
 */
const SENSITIVE_PARAMS = ['ytm_cookie', 'cookie', 'access_token', 'refresh_token', 'token', 'code', 'state'];

function redactUrl(rawUrl) {
  if (!rawUrl || !rawUrl.includes('?')) return rawUrl;
  try {
    const u = new URL(rawUrl, 'http://localhost');
    for (const key of SENSITIVE_PARAMS) {
      if (u.searchParams.has(key)) u.searchParams.set(key, '[REDACTED]');
    }
    return `${u.pathname}${u.search}`;
  } catch {
    return rawUrl.split('?')[0];
  }
}

function requestLogger(req, res, next) {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (process.env.NODE_ENV !== 'test') {
      console.log(`[API] ${req.method} ${redactUrl(req.originalUrl || req.url)} - ${res.statusCode} (${duration}ms)`);
    }
  });
  next();
}

module.exports = requestLogger;
