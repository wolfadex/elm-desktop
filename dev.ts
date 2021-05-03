const decoder = new TextDecoder("utf-8");
const data = await Deno.readFile("dist/public/elm.js");
const elm = await decoder.decode(data);

const result = elm.replace(
  /_Debug_todo\([\n\t\w'.,{:}\s()]*'REPLACE_ME::(.*)'\)/g,
  "$1"
);

const encoder = new TextEncoder();
const resultData = await encoder.encode(result);
await Deno.writeFile("dist/public/elm.js", resultData);
