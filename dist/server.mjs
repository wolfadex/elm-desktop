import { spawn } from "child_process";
import path from "path";
import { fileURLToPath } from "url";
import fsPromises from "fs/promises";
import webview from "webview";
import WebSocket from "ws";
import Elm from "./elm.mjs";

/**
 * `__dirname` isn't accessible in `.mjs` files so we use this.
 * https://stackoverflow.com/questions/8817423/why-is-dirname-not-defined-in-node-repl
 */
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const wss = new WebSocket.Server({ port: 8080 });
let elmServerApp;
let appWindow;

Object.defineProperty(Object.prototype, "__elm_interop_sync", {
  set(code) {
    try {
      const { msg, args } = code;
      let result;
      switch (msg) {
        case "PRINT_LINE":
          console.log(args);
          result = null;
          break;
        case "GET_ENV":
          result = process.env[args];
          break;
        case "GET_CWD":
          result = process.cwd();
          break;
        case "CHANGE_CWD":
          process.chdir(args);
          result = null;
          break;
        case "GET_PLATFORM":
          result = process.platform;
          break;
        default:
          throw new Error(`Unknown JS code to run: ${msg}`);
      }
      this.__elm_interop_result = { tag: "Ok", result };
    } catch (err) {
      this.__elm_interop_result = { tag: "Error", error: err };
    }
  },
  get() {
    return this.__elm_interop_result;
  },
});

const _setTimeout = setTimeout;
const __elm_interop_tasks = new Map();
let __elm_interop_nextTask = null;

Object.defineProperty(Object.prototype, "__elm_interop_async", {
  set([token, msg, args]) {
    // Async version see setTimeout below for execution
    __elm_interop_nextTask = [token, msg, args];
  },
  get() {
    let ret = __elm_interop_tasks.get(this.token);
    __elm_interop_tasks.delete(ret);
    return ret;
  },
});

setTimeout = (callback, time, ...args) => {
  // 69 108 109 === Elm
  if (time === -69108109 && __elm_interop_nextTask != null) {
    const [token, msg, args] = __elm_interop_nextTask;
    __elm_interop_nextTask = null;

    Promise.resolve()
      .then(async (_) => {
        switch (msg) {
          case "TO_WINDOW": {
            arg.socket.send(args.message);
            return true;
          }
          case "RUN_COMMAND": {
            const [actualCmd, ...cmdArgs] = args.cmd;
            const cmdProcess = spawn(actualCmd, cmdArgs);

            cmdProcess.stdout.on("data", async (data) => {
              const decoder = new TextDecoder("utf-8");
              const value = await decoder.decode(data);

              elmServerApp.ports.commandStdOut.send({ id: args.id, value });
            });

            cmdProcess.stderr.on("data", async (data) => {
              const decoder = new TextDecoder("utf-8");
              const value = await decoder.decode(data);

              elmServerApp.ports.commandStdErr.send({ id: args.id, value });
            });

            cmdProcess.on("exit", async (code) => {
              elmServerApp.ports.commandDone.send({
                id: args.id,
                value: code,
              });
            });

            return true;
          }
          case "OPEN_WINDOW": {
            const appWindow = spawn(
              webview.binaryPath,
              [
                ["--title", args.title],
                ["--width", args.width],
                ["--height", args.height],
                ["--dir", "public"],
              ].flat(),
              { cwd: __dirname }
            );
            return appWindow;
          }
          case "FS_READ_FILE":
            return fsPromises.readFile(args.path, args.options);
          case "FS_WRITE_FILE":
            return fsPromises
              .writeFile(args.path, args.data, args.options)
              .then(() => null);
          default:
            console.error(`Error: Unknown server request: "${msg}"`, args);
        }
      })
      .then((result) => {
        __elm_interop_tasks.set(token, { tag: "Ok", result });
      })
      .catch((err) => {
        __elm_interop_tasks.set(token, { tag: "Error", error: err });
      })
      .then((_) => {
        callback();
      });
  } else {
    return _setTimeout(callback, time, ...args);
  }
};

elmServerApp = Elm.Desktop.Server.init();

elmServerApp.ports.fromServer.subscribe(function (msg) {
  if (msg.socket) {
    msg.socket.send(JSON.stringify(msg.message));
  }
});

wss.on("connection", function connection(ws) {
  elmServerApp.ports.windowConnection.send(ws);

  ws.on("message", function incoming(message) {
    elmServerApp.ports.toServer.send(JSON.parse(message));
  });
});

elmServerApp.ports.openWindow.subscribe(function (msg) {
  appWindow = spawn(
    webview.binaryPath,
    [
      ["--title", msg.title],
      ["--width", msg.width],
      ["--height", msg.height],
      ["--dir", "public"],
    ].flat(),
    { cwd: __dirname }
  );
});
