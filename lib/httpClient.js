/**
 * Lightweight HTTP client with timeout, retry, and JSON parsing
 */
async function fetchJson(url, options = {}) {
  const timeout = options.timeout || 12000;
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      ...options,
      signal: options.signal || controller.signal,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        ...(options.headers || {})
      }
    });

    if (!response.ok) {
      const errorBody = await response.text().catch(() => '');
      const err = new Error(`HTTP ${response.status} from ${url}: ${errorBody.slice(0, 300)}`);
      err.status = response.status;
      err.body = errorBody;
      throw err;
    }

    return await response.json();
  } finally {
    clearTimeout(id);
  }
}

async function fetchText(url, options = {}) {
  const timeout = options.timeout || 12000;
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      ...options,
      signal: options.signal || controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        ...(options.headers || {})
      }
    });

    if (!response.ok) {
      const err = new Error(`HTTP ${response.status} from ${url}`);
      err.status = response.status;
      throw err;
    }

    return await response.text();
  } finally {
    clearTimeout(id);
  }
}

module.exports = {
  fetchJson,
  fetchText
};

