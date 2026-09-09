const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("node:path");
require("./XMLHttpRequest.js");
const httpHijack = require("./http-hijack.js").default;

const { Elm } = require("../backend.js");

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require("electron-squirrel-startup")) {
  app.quit();
}

var elmApp;
var windows = {};
var nextWindowId = 0;

httpHijack("elm-desktop", globalThis, function (router) {
  router.post("open-window", function (req, res) {
    const windowOpts = req.body;
    const thisWindowId = nextWindowId;
    nextWindowId += 1;

    const window = new BrowserWindow({
      ...windowOpts,
      webPreferences: {
        preload: path.join(__dirname, "preload.js"),
        contextIsolation: true,
        nodeIntegration: false,
      },
    });
    window.webContents.on("did-finish-load", () => {
      window.webContents.send("initialize-window", thisWindowId);
    });

    window.loadFile(path.join(__dirname, "index.html"));
    window.webContents.openDevTools();
    windows[thisWindowId] = window;

    res.json(thisWindowId);
  });
});

function initializeElm() {
  elmApp = Elm.Backend.init();

  elmApp.ports.sendToFrontend.subscribe(function ([windowId, msg]) {
    const window = windows[windowId];

    if (window) {
      window.webContents.send("from-backend", msg);
    }
  });
}

ipcMain.on("to-backend", (event, [windowId, arrayBuffer]) => {
  elmApp.ports.toBackend.send([windowId, arrayBuffer]);
});

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(() => {
  initializeElm();

  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  // app.on("activate", () => {
  //   if (BrowserWindow.getAllWindows().length === 0) {
  //     initializeElm();
  //   }
  // });
});

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and import them here.
