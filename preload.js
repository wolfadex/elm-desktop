const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("elmDesktop", {
  setId(callback) {
    ipcRenderer.on("set-id", function (_, windowId) {
      callback(windowId);
    });
  },
  toWindow(callback) {
    ipcRenderer.on("to-window", function (_, data) {
      callback(data);
    });
  },
  fromWindow(data) {
    ipcRenderer.send("from-window", data);
  },
});
