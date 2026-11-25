/**
 * Lightweight zero-dependency sliding-window rate limiter middleware
 */
function createRateLimiter({ windowMs = 60_000, max = 180 } = {}) {
  const hits = new Map();

  // Periodically prune expired IP buckets so memory stays bounded
  const cleanup = setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of hits.entries()) {
      if (entry.resetAt <= now) hits.delete(key);
    }
  }, windowMs);
  if (typeof cleanup.unref === 'function') cleanup.unref();

  return function rateLimit(req, res, next) {
    const ip = req.ip || req.socket?.remoteAddress || 'unknown';
    const now = Date.now();
    let entry = hits.get(ip);

    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(ip, entry);
    }

    entry.count += 1;
    if (entry.count > max) {
      res.setHeader('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return res.status(429).json({ error: 'Too many requests, please try again shortly.' });
    }

    next();
  };
}

module.exports = { createRateLimiter };
