const fs = require("fs");
const path = require("path");
const elmCompiler = require("node-elm-compiler");

console.log("Building ElmDesktop...");

elmCompiler
  .compileToString([".desktop/Desktop/Backend.elm"], { output: "elm.js" })
  .then(function (data) {
    const compiledBackend = data.toString();
    // Change the compiled elm file to not immediately call the compiled function
    const removeIIFEBackend = compiledBackend
      .replace(/\(function\(scope/g, "function init(scope")
      .replace(/}\(this\)\);/g, "}");
    // Export the compiled function as the default export (for Node)
    const exportedBackend = `${removeIIFEBackend}

const scope = {};
init(scope);
module.exports = scope.Elm;`;

    fs.writeFileSync("dist/elm.js", exportedBackend, { encoding: "utf8" });
    console.log("Backend compiled");
  });

elmCompiler
  .compile([".desktop/Desktop/Window.elm"], {
    output: "dist/public/elm.js",
  })
  .on("close", function (exitCode) {
    console.log("Frontend compiled");
  });

// const frontendsToCompile = new Set();

// function findWindows(startPath) {
//   const items = fs.readdirSync(startPath, { withFileTypes: true });
//   for (const item of items) {
//     if (item.isDirectory()) {
//       findWindows(path.join(startPath, item.name));
//     } else if (item.isFile() && item.name.endsWith(".elm")) {
//       frontendsToCompile.add(path.join(startPath, item.name));
//     }
//   }
// }

// console.log("Compiling frontend");

// findWindows(path.join(__dirname, "..", "src", "Window"));

// elmCompiler
//   .compile(Array.from(frontendsToCompile), { output: "dist/public/elm.js" })
//   .on("close", function (exitCode) {
//     if (exitCode === 0) {
//       for (const frontend of frontendsToCompile) {
//         const name = `Window${frontend
//           .split(path.join("src", "Window"))[1]
//           .replace(/[/\\]/g, ".")
//           .replace(".elm", "")}`;
//         const html = htmlTemplate(name);
//         fs.writeFileSync(
//           path.join(__dirname, "..", "dist", "public", `${name}.html`),
//           html,
//           { encoding: "utf8" }
//         );
//       }

//       console.log("Frontend compiled");
//     }
//   });

// function htmlTemplate(name) {
//   return `<!DOCTYPE html>
// <html>
//   <head>
//     <title>ElmDesktop</title>
//   </head>
//   <body>
//     <h1 id="elm-node">Loading...?</h1>
//     <script src="elm.js"></script>
//     <script>
//       window.elmDesktop.setId(function (windowId) {
//         const app = Elm.${name}.init({
//           node: document.getElementById("elm-node"),
//           flags: { windowId: windowId, userFlags: null },
//         });

//         window.elmDesktop.toWindow(app.ports.fromBackendInternal.send);
//         app.ports.toBackendInternal.subscribe(window.elmDesktop.fromWindow);
//       });
//     </script>
//   </body>
// </html>
// `;
// }
