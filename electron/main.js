const { app, BrowserWindow, ipcMain, globalShortcut, Tray, Menu, nativeImage } = require('electron');
const path = require('path');
const http = require('http');
const AuthManager = require('./authManager');

// Start embedded local Express server
const expressApp = require('../server');

let mainWindow = null;
let logWindow = null;
let tray = null;
let authManager = null;
let localPort = process.env.PORT || 3000;
let isDev = process.argv.includes('--dev') || process.env.NODE_ENV === 'development';

const logBuffer = [];

function emitLog(message, type = 'info') {
  const timestamp = new Date().toLocaleTimeString();
  const entry = { timestamp, message: String(message), type };
  logBuffer.push(entry);
  if (logBuffer.length > 200) logBuffer.shift();
  
  console.log(`[${timestamp}] [${type.toUpperCase()}] ${message}`);
  
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('live-log-message', entry);
  }
  if (logWindow && !logWindow.isDestroyed()) {
    logWindow.webContents.send('live-log-message', entry);
  }
}

// Hook stdout and stderr for live logging
const originalStdout = process.stdout.write.bind(process.stdout);
process.stdout.write = (chunk, encoding, callback) => {
  const text = chunk.toString().trim();
  if (text) emitLog(text, 'stdout');
  return originalStdout(chunk, encoding, callback);
};

const originalStderr = process.stderr.write.bind(process.stderr);
process.stderr.write = (chunk, encoding, callback) => {
  const text = chunk.toString().trim();
  if (text) emitLog(text, 'stderr');
  return originalStderr(chunk, encoding, callback);
};

function createLiveLogWindow() {
  if (logWindow) {
    logWindow.focus();
    return;
  }

  logWindow = new BrowserWindow({
    width: 650,
    height: 480,
    title: 'Preluded Dev Live Logs [Realtime]',
    backgroundColor: '#0a0a0f',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  const logHtml = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Preluded Dev Live Logs</title>
  <style>
    body { background: #0a0a0f; color: #00ff88; font-family: 'Consolas', monospace; font-size: 13px; margin: 0; padding: 12px; }
    #header { position: sticky; top: 0; background: #12121a; padding: 8px; border-bottom: 1px solid #222; display: flex; justify-content: space-between; align-items: center; }
    #logs { padding-top: 8px; display: flex; flex-direction: column; gap: 4px; }
    .log-item { word-break: break-all; padding: 2px 0; border-bottom: 1px solid rgba(255,255,255,0.03); }
    .time { color: #888; margin-right: 8px; }
    .stdout { color: #70d6ff; }
    .stderr { color: #ff5964; }
    .info { color: #00ff88; }
    .auth { color: #ffd166; }
    button { background: #fa2d48; color: #fff; border: none; padding: 4px 10px; border-radius: 4px; cursor: pointer; }
  </style>
</head>
<body>
  <div id="header">
    <strong>⚡ Preluded Live Log Stream [Dev Mode]</strong>
    <button onclick="document.getElementById('logs').innerHTML = ''">Pulisci Log</button>
  </div>
  <div id="logs"></div>
  <script>
    const logsEl = document.getElementById('logs');
    function addLog(log) {
      const d = document.createElement('div');
      d.className = 'log-item ' + (log.type || 'info');
      d.innerHTML = '<span class="time">' + (log.timestamp || log.time || '') + '</span>' + (log.message || '');
      logsEl.appendChild(d);
      window.scrollTo(0, document.body.scrollHeight);
    }
    if (window.desktopAPI && window.desktopAPI.onLiveLog) {
      window.desktopAPI.onLiveLog(addLog);
    }
  </script>
</body>
</html>`;

  logWindow.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(logHtml));

  logWindow.on('closed', () => {
    logWindow = null;
  });
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 400,
    minHeight: 600,
    title: 'Preluded Music',
    backgroundColor: '#000000',
    icon: path.join(__dirname, '..', 'icons', '512x512.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: false,
      webSecurity: false
    }
  });

  authManager = new AuthManager(mainWindow, emitLog);

  const appUrl = `http://127.0.0.1:${localPort}/app`;
  emitLog(`[Electron] Loading application UI from: ${appUrl}`);

  // Retry loading until local Express server is ready
  let retries = 0;
  const loadWithRetry = () => {
    mainWindow.loadURL(appUrl).catch((err) => {
      retries++;
      if (retries < 15) {
        emitLog(`[Electron] Waiting for server on port ${localPort}... retry #${retries}`);
        setTimeout(loadWithRetry, 400);
      } else {
        emitLog(`[Electron] Failed to load URL: ${err.message}`, 'stderr');
      }
    });
  };

  loadWithRetry();

  // Create real-time log window in dev mode
  if (isDev) {
    createLiveLogWindow();
  }

  // Window IPC Controls
  ipcMain.on('window-minimize', () => mainWindow.minimize());
  ipcMain.on('window-maximize', () => {
    if (mainWindow.isMaximized()) mainWindow.unmaximize();
    else mainWindow.maximize();
  });
  ipcMain.on('window-close', () => mainWindow.close());

  // SimpMusic Google Auth IPC Handler
  ipcMain.on('open-simpmusic-login', () => {
    emitLog('[Electron] SimpMusic 1-Click Login triggered');
    authManager.openGoogleLogin(
      (data) => {
        emitLog('[Electron] Google authentication succeeded! Sending session to renderer.', 'auth');
        mainWindow.webContents.send('simpmusic-auth-success', data);
      },
      (err) => {
        emitLog(`[Electron] Google auth cancelled or failed: ${err.message}`, 'stderr');
        mainWindow.webContents.send('simpmusic-auth-error', { error: err.message });
      }
    );
  });

  ipcMain.on('renderer-log', (event, data) => {
    emitLog(data.message, data.type || 'info');
  });

  // Global Media Keys
  try {
    globalShortcut.register('MediaPlayPause', () => {
      if (mainWindow) mainWindow.webContents.executeJavaScript('if (typeof togglePlay === "function") togglePlay();');
    });
    globalShortcut.register('MediaNextTrack', () => {
      if (mainWindow) mainWindow.webContents.executeJavaScript('if (typeof nextTrack === "function") nextTrack();');
    });
    globalShortcut.register('MediaPreviousTrack', () => {
      if (mainWindow) mainWindow.webContents.executeJavaScript('if (typeof prevTrack === "function") prevTrack();');
    });
  } catch (e) {
    emitLog('Global shortcuts error: ' + e.message, 'stderr');
  }

  // System Tray
  try {
    const iconPath = path.join(__dirname, '..', 'icons', '192x192.png');
    tray = new Tray(iconPath);
    const contextMenu = Menu.buildFromTemplate([
      { label: 'Apri Preluded', click: () => { mainWindow.show(); mainWindow.focus(); } },
      { label: 'Play / Pausa', click: () => mainWindow.webContents.executeJavaScript('togglePlay()') },
      { label: 'Successivo', click: () => mainWindow.webContents.executeJavaScript('nextTrack()') },
      { label: 'Precedente', click: () => mainWindow.webContents.executeJavaScript('prevTrack()') },
      { type: 'separator' },
      { label: 'Mostra Log in Tempo Reale', click: () => createLiveLogWindow() },
      { type: 'separator' },
      { label: 'Esci da Preluded', click: () => { app.isQuiting = true; app.quit(); } }
    ]);
    tray.setToolTip('Preluded Music');
    tray.setContextMenu(contextMenu);
    tray.on('double-click', () => mainWindow.show());
  } catch(e) {}

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createMainWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});
