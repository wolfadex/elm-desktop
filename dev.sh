#/bin/bash

echo "Building Elm..."

elm make .desktop/Desktop/Server.elm .desktop/Desktop/Window.elm --output=dist/public/elm.js

# find and replace
deno run -A dev.ts

cp dist/public/elm.js dist/elm.mjs

# change the cmpiled elm file to not immediately call the compiled function
perl -i -pe 's/\(function\(scope/function init\(scope/g' dist/elm.mjs
perl -i -pe 's/}\(this\)\);/}/g' dist/elm.mjs

# export the compiled function as the default export
echo "\n\nconst scope = {};\ninit(scope);\nexport default scope.Elm;" >> dist/elm.mjs

echo "Elm compiled"