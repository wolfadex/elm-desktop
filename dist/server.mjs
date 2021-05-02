import { spawn } from "child_process";
import path from "path";
import webview from "webview";
import Elm from "./elm.mjs";

let elmApp;

Object.defineProperty(Object.prototype, "__elm_interop_sync", {
  set(code) {
    try {
      const { msg, args } = code;
      let result;
      switch (msg) {
        case "PRINT_LINE":
          console.log(args);
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
          case "RUN_COMMAND":
            {
              const [actualCmd, ...cmdArgs] = args.cmd;
              const cmdProcess = spawn(actualCmd, cmdArgs);

              cmdProcess.stdout.on("data", async (data) => {
                const decoder = new TextDecoder("utf-8");
                const value = await decoder.decode(data);

                elmApp.ports.commandStdOut.send({ id: args.id, value });
              });

              cmdProcess.stderr.on("data", async (data) => {
                const decoder = new TextDecoder("utf-8");
                const value = await decoder.decode(data);

                elmApp.ports.commandStdErr.send({ id: args.id, value });
              });

              cmdProcess.on("exit", async (code) => {
                elmApp.ports.commandDone.send({ id: args.id, value: code });
              });
            }
            break;
          case "OPEN_WINDOW":
            {
              console.log("carl", 1, process.cwd());
              const appWindow = spawn(
                webview.binaryPath,
                [
                  ["--title", args.title],
                  ["--width", args.width],
                  ["--height", args.height],
                  ["--dir", "public"],
                ].flat(),
                { cwd: path.join(process.cwd(), "dist") }
              );
              elmApp.ports.windowOpened.send({
                id: args.id,
                window: appWindow,
              });
            }
            break;
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

elmApp = Elm.Pipeline.init();
