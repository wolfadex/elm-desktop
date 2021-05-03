const fs = require("fs");

const elmPath = "dist/public/elm.js";

fs.readFile(elmPath, { encoding: "utf8" }, (err, data) => {
  if (err) {
    throw err;
  }

  const result = data.replace(
    /_Debug_todo\([\n\t\w'.,{:}\s()]*'REPLACE_ME::(.*)'\)/g,
    "$1"
  );

  fs.writeFile(elmPath, result, { encoding: "utf8" }, (err) => {
    if (err) throw err;
  });
});
