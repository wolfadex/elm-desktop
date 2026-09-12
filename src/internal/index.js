const path = require("node:path");
const fs = require("node:fs");

const { app, BrowserWindow, ipcMain, clipboard } = require("electron");

require("./XMLHttpRequest.js");
const httpHijack = require("./http-hijack.js").default;

const { Elm } = require("../elm-backend.js");
const backend = require("../backend.js");

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require("electron-squirrel-startup")) {
  app.quit();
}

var elmApp;
var windows = {};
var nextWindowId = 0;

httpHijack("elm-desktop", globalThis, function (router) {
  router.post("open-window", function (req, res) {
    openWindow(JSON.parse(req.body), false, function (thisWindowId) {
      res.json(thisWindowId);
    });
  });

  router.post("open-debug-window", function (req, res) {
    openWindow(JSON.parse(req.body), true, function (thisWindowId) {
      res.json(thisWindowId);
    });
  });

  router.post("save-user-data", function (req, res) {
    const { filename, data } = req.json;
    const filePath = path.join(app.getPath("userData"), filename);

    fs.writeFile(filePath, data, function (error) {
      if (error) {
        console.error(error);
        res.error(error.toString());
      } else {
        res.ok();
      }
    });
  });

  router.post("load-user-data", function (req, res) {
    const filename = req.json;
    const filePath = path.join(app.getPath("userData"), filename);
    console.log(filePath)

    fs.readFile(filePath, "utf-8", function (error, data) {
      if (error) {
        res.error(error.code);
      } else {
        res.text(data);
      }
    });
  });
});

function openWindow(options, showDevtools, onLoaded) {
  const thisWindowId = nextWindowId;

  nextWindowId += 1;

  const window = new BrowserWindow({
    ...options,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  window.webContents.on("did-finish-load", () => {
    window.webContents.send("initialize-window", thisWindowId);
    onLoaded(thisWindowId);
  });

  window.loadFile(path.join(__dirname, "index.html"));

  if (showDevtools) {
    window.webContents.openDevTools();
  }

  windows[thisWindowId] = window;
}

function initializeElm() {
  const flags = backend.flags();

  elmApp = Elm.Backend.init({ flags: flags });

  backend.ports(elmApp);

  elmApp.ports.sendToFrontend?.subscribe(function ([windowId, msg]) {
    const window = windows[windowId];

    if (window) {
      window.webContents.send("from-backend", msg);
    }
  });

  app.ports?.clipboardWriteText?.subscribe(async function (text) {
    await clipboard.writeText(text);
  });
}

ipcMain.on("to-backend", (event, [windowId, arrayBuffer]) => {
  elmApp.ports.toBackend?.send([windowId, arrayBuffer]);
});

ipcMain.on("clipboard-writetext", async (event, text) => {
  await clipboard.writeText(text);
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
