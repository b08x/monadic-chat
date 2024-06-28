const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electron', {
  receiveCommandOutput: (func) => {
    ipcRenderer.on('commandOutput', (_event, ...args) => func(...args));
  },
  sendCommand: (command) => {
    ipcRenderer.send('command', command);
  },
  updateControls: (func) => {
    ipcRenderer.on('updateControls', (_event, ...args) => func(...args));
  },
  onServerReady: (func) => {
    ipcRenderer.on('serverReady', func);
  }
});

ipcRenderer.on('updateVersion', (_event, version) => {
  document.getElementById('version').textContent = version;
});

ipcRenderer.on('updateStatusIndicator', (_event, status) => {
  const statusElement = document.getElementById('status');
  statusElement.textContent = status;

  if (status === 'Port in use') {
    statusElement.classList.remove('active');
    statusElement.classList.add('inactive');
    document.getElementById('start').disabled = true;
    document.getElementById('stop').disabled = true;
    document.getElementById('restart').disabled = true;
    document.getElementById('browser').disabled = true;
  } else if (status === 'Starting') {
    statusElement.classList.remove('active');
    statusElement.classList.add('inactive');
    document.getElementById('start').disabled = true;
    document.getElementById('stop').disabled = true;
    document.getElementById('restart').disabled = true;
    document.getElementById('browser').disabled = true;
  } else if (status === 'Running') {
    statusElement.classList.remove('inactive');
    statusElement.classList.add('active');
    document.getElementById('folder').disabled = false;
    document.getElementById('start').disabled = true;
    document.getElementById('stop').disabled = false;
    document.getElementById('restart').disabled = false;
    document.getElementById('browser').disabled = false;
  } else if (status === 'BrowserReady') {
    document.getElementById('browser').disabled = false;
    statusElement.textContent = "Running - Browser Ready";
  } else if (status === 'Stopping') {
    statusElement.classList.remove('active');
    statusElement.classList.add('inactive');
    document.getElementById('start').disabled = true;
    document.getElementById('stop').disabled = true;
    document.getElementById('restart').disabled = true;
    document.getElementById('browser').disabled = true;
  } else if (status === 'Stopped') {
    statusElement.classList.remove('active');
    statusElement.classList.add('inactive');
    document.getElementById('start').disabled = false;
    document.getElementById('stop').disabled = true;
    document.getElementById('restart').disabled = true;
    document.getElementById('browser').disabled = true;
  } else {
    statusElement.classList.remove('active');
    statusElement.classList.add('inactive');
    document.getElementById('start').disabled = true;
    document.getElementById('stop').disabled = true;
    document.getElementById('restart').disabled = true;
    document.getElementById('browser').disabled = true;
  }
});
