const { contextBridge } = require("electron");
const Store = require("electron-store");

let store = null;

contextBridge.exposeInMainWorld("elmDesktop", {
  save(data) {
    if (store === null) {
      store = new Store();
    }

    store.set("saved-data", data);
  },
  load(callback) {
    if (store === null) {
      store = new Store();
    }

    callback(store.get("saved-data"));
  },
});
