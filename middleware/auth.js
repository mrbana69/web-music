/**
 * Optional user authorization middleware
 */
function extractAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  if (authHeader.startsWith('Bearer ')) {
    req.userToken = authHeader.substring(7).trim();
  }
  next();
}

function requireAuth(req, res, next) {
  if (!req.userToken) {
    return res.status(401).json({ error: 'Unauthorized: Authentication required' });
  }
  next();
}

module.exports = {
  extractAuth,
  requireAuth
};

