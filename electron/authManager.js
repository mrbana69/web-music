const { BrowserWindow, session } = require('electron');

/**
 * SimpMusic-style Automated YouTube Music Authentication Engine
 * Opens an authentic Google / YouTube Music login window, intercepts
 * the SAPISID and session cookies transparently, and passes them to the app.
 */
class AuthManager {
  constructor(mainWindow, logFn = console.log) {
    this.mainWindow = mainWindow;
    this.log = logFn;
    this.loginWindow = null;
  }

  openGoogleLogin(onSuccess, onError) {
    if (this.loginWindow) {
      this.loginWindow.focus();
      return;
    }

    this.log('[AuthManager] Opening Google/YouTube Music login window...');

    const customSession = session.fromPartition('persist:ytm_auth', { cache: true });

    this.loginWindow = new BrowserWindow({
      width: 620,
      height: 740,
      title: 'Accedi con Google - Preluded Desktop',
      backgroundColor: '#030305',
      parent: this.mainWindow,
      modal: true,
      autoHideMenuBar: true,
      webPreferences: {
        session: customSession,
        nodeIntegration: false,
        contextIsolation: true,
        sandbox: true
      }
    });

    const targetLoginUrl = 'https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F';
    this.loginWindow.loadURL(targetLoginUrl, {
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    });

    let intercepted = false;

    const checkCookies = async (url = '') => {
      if (intercepted) return;
      try {
        const cookies = await customSession.cookies.get({ domain: '.youtube.com' });
        const musicCookies = await customSession.cookies.get({ domain: 'music.youtube.com' });
        const googleCookies = await customSession.cookies.get({ domain: '.google.com' });

        const all = [...cookies, ...musicCookies, ...googleCookies];
        const sapisidCookie = all.find(c => c.name === 'SAPISID' || c.name === '__Secure-3PAPISID');

        if (sapisidCookie || (url && url.includes('music.youtube.com'))) {
          const map = new Map();
          for (const c of all) {
            if (!map.has(c.name)) map.set(c.name, c.value);
          }

          if (map.has('SAPISID') || map.has('__Secure-3PAPISID') || map.has('SID')) {
            intercepted = true;
            this.log('[AuthManager] Intercepted authentic YouTube Music session successfully!');

            const cookieString = Array.from(map.entries())
              .map(([k, v]) => `${k}=${v}`)
              .join('; ');

            if (this.loginWindow) {
              this.loginWindow.close();
              this.loginWindow = null;
            }

            if (onSuccess) {
              onSuccess({
                cookieString,
                sapisid: map.get('SAPISID') || map.get('__Secure-3PAPISID') || ''
              });
            }
          }
        }
      } catch (err) {
        this.log('[AuthManager] Cookie check error:', err.message);
      }
    };

    this.loginWindow.webContents.on('did-navigate', (event, url) => {
      this.log(`[AuthManager] Navigated to: ${url}`);
      checkCookies(url);
    });

    this.loginWindow.webContents.on('did-navigate-in-page', (event, url) => {
      checkCookies(url);
    });

    this.loginWindow.on('closed', () => {
      this.loginWindow = null;
      if (!intercepted && onError) {
        onError(new Error('Finestra di login chiusa'));
      }
    });
  }
}

module.exports = AuthManager;
