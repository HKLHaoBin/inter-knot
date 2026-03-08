const path = require('path');
const { app, BrowserWindow, shell } = require('electron');

function createWindow() {
  const win = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1100,
    minHeight: 720,
    autoHideMenuBar: true,
    backgroundColor: '#111111',
    webPreferences: {
      contextIsolation: true,
      sandbox: true
    }
  });

  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  win.webContents.on('will-navigate', (event, url) => {
    const localIndex = `file://${path.join(__dirname, 'web', 'index.html')}`;
    if (!url.startsWith(localIndex)) {
      event.preventDefault();
      shell.openExternal(url);
    }
  });

  win.loadFile(path.join(__dirname, 'web', 'index.html'));
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
