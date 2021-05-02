import { compileToModule } from "https://deno.land/x/deno_elm_compiler@0.1.0/compiler.ts";

await compileToModule("./src/Pipeline.elm", { output: "./dist/elm.js" });

await Deno.rename("dist/elm.js", "dist/elm.mjs");

console.log("Elm compiled");
