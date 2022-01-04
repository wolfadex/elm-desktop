// Modules to control application life and create native browser window
const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const crypto = require("crypto");
const Elm = require("./dist/elm.js");

const windows = {};

function createWindow(options) {
  const finalOptions = {
    ...options,
    ...(options.top ? { top: windows[options.top] } : {}),
    webPreferences: {
      ...(options.webPreferences || {}),
      preload: path.join(__dirname, "preload.js"),
    },
  };

  const window = new BrowserWindow(finalOptions);
  window.loadFile(path.join(__dirname, "dist", "public", "index.html"));
  // Open the DevTools.
  window.webContents.openDevTools();
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(() => {
  const elmApp = Elm.Desktop.Backend.init();
  elmApp.ports.createWindowInternal.subscribe(createWindow);

  app.on("activate", function () {
    // On macOS it's common to re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on("window-all-closed", function () {
  if (process.platform !== "darwin") app.quit();
});
