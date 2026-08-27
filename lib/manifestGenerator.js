/**
 * Generates base64 encoded manifests matching the frontend API contract in index.html
 */

function createTrackManifest(urls = [], options = {}) {
  const urlList = Array.isArray(urls) ? urls : [urls].filter(Boolean);
  
  const manifest = {
    mimeType: options.mimeType || 'audio/mp4',
    codecs: options.codecs || 'mp4a.40.2',
    urls: urlList,
    bitrate: options.bitrate || 320000,
    sampleRate: options.sampleRate || 44100,
    duration: options.duration || 0,
    trackId: options.trackId || null,
    expiresAt: options.expiresAt || Math.floor(Date.now() / 1000) + 21600
  };

  const jsonStr = JSON.stringify(manifest);
  const base64Str = Buffer.from(jsonStr, 'utf8').toString('base64');

  return {
    data: {
      manifest: base64Str,
      trackId: options.trackId || null
    }
  };
}

function decodeTrackManifest(base64Str) {
  try {
    const jsonStr = Buffer.from(base64Str, 'base64').toString('utf8');
    return JSON.parse(jsonStr);
  } catch (err) {
    return null;
  }
}

module.exports = {
  createTrackManifest,
  decodeTrackManifest
};

