const crypto = require('crypto');

/**
 * SimpMusic & InnerTune SAPISID Authentication Engine
 * Generates the authentic SAPISIDHASH Authorization header used by YouTube Music.
 */
class SapisidAuth {
  /**
   * Extract SAPISID or __Secure-3PAPISID from a raw cookie string
   * @param {string} cookieString
   * @returns {string}
   */
  static extractSapisid(cookieString) {
    if (!cookieString || typeof cookieString !== 'string') return '';
    const match = cookieString.match(/(?:^|;\s*)(?:SAPISID|__Secure-3PAPISID|__Secure-1PAPISID)=([^;]+)/);
    return match ? match[1] : '';
  }

  /**
   * Generate the SAPISIDHASH string
   * Formula: SHA-1(timestamp + ' ' + sapisid + ' ' + origin)
   * Header value: SAPISIDHASH <timestamp>_<sha1_hex>
   * @param {string} sapisid
   * @param {string} origin
   * @returns {string}
   */
  static generateHash(sapisid, origin = 'https://music.youtube.com') {
    if (!sapisid) return '';
    const timestamp = Math.floor(Date.now() / 1000);
    const payload = `${timestamp} ${sapisid} ${origin}`;
    const sha1 = crypto.createHash('sha1').update(payload).digest('hex');
    return `SAPISIDHASH ${timestamp}_${sha1}`;
  }

  /**
   * Build complete authentic Innertube request headers
   * @param {string} cookieString
   * @param {Object} extraHeaders
   * @returns {Object}
   */
  static getHeaders(cookieString = '', extraHeaders = {}) {
    const origin = 'https://music.youtube.com';
    const sapisid = this.extractSapisid(cookieString);
    const authHeader = sapisid ? this.generateHash(sapisid, origin) : '';

    const headers = {
      'Content-Type': 'application/json',
      'Origin': origin,
      'Referer': `${origin}/`,
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'X-YouTube-Client-Name': '67',
      'X-YouTube-Client-Version': '1.20240401.01.00',
      'X-Origin': origin,
      ...extraHeaders
    };

    if (authHeader) {
      headers['Authorization'] = authHeader;
    }
    if (cookieString) {
      headers['Cookie'] = cookieString;
    }

    return headers;
  }
}

module.exports = SapisidAuth;
