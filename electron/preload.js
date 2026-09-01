const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopAPI', {
  isElectron: true,
  platform: process.platform,
  
  // Window controls
  minimize: () => ipcRenderer.send('window-minimize'),
  maximize: () => ipcRenderer.send('window-maximize'),
  close: () => ipcRenderer.send('window-close'),
  
  // SimpMusic Google Auth
  openSimpMusicLogin: () => ipcRenderer.send('open-simpmusic-login'),
  onSimpMusicAuthSuccess: (callback) => {
    ipcRenderer.on('simpmusic-auth-success', (event, data) => callback(data));
  },
  onSimpMusicAuthError: (callback) => {
    ipcRenderer.on('simpmusic-auth-error', (event, data) => callback(data));
  },

  // Real-time live log stream
  onLiveLog: (callback) => {
    ipcRenderer.on('live-log-message', (event, log) => callback(log));
  },
  sendLiveLog: (message, type = 'info') => {
    ipcRenderer.send('renderer-log', { message, type, time: new Date().toLocaleTimeString() });
  },

  // Media state communication
  sendPlaybackState: (state) => ipcRenderer.send('playback-state-update', state)
});
