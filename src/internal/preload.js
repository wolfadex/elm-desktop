// See the Electron documentation for details on how to use preload scripts:
// https://www.electronjs.org/docs/latest/tutorial/process-model#preload-scripts
const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  sendToBackend: (data) => ipcRenderer.send("to-backend", data),
  onFromBackend: (callback) => {
    ipcRenderer.on("from-backend", (event, arrayBuffer) =>
      callback(arrayBuffer),
    );
  },
  onInitialize: (callback) => {
    ipcRenderer.on("initialize-window", (event, windowId) =>
      callback(windowId),
    );
  },
  clipboardWriteText: (text) => ipcRenderer.send("clipboard-writetext", text),
});
