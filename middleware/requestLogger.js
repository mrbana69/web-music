/**
 * Lightweight request logger middleware
 */
function requestLogger(req, res, next) {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (process.env.NODE_ENV !== 'test') {
      console.log(`[API] ${req.method} ${req.originalUrl || req.url} - ${res.statusCode} (${duration}ms)`);
    }
  });
  next();
}

module.exports = requestLogger;

