#/bin/bash

echo "Building Elm..."

elm make src/Backend.elm --output=dist/elm.js

# change the cmpiled elm file to not immediately call the compiled function
perl -i -pe 's/\(function\(scope/function init\(scope/g' dist/elm.js
perl -i -pe 's/}\(this\)\);/}/g' dist/elm.js

# export the compiled function as the default export (for Node)
echo "\n\nconst scope = {};\ninit(scope);\nmodule.exports = scope.Elm;" >> dist/elm.js

echo "Backend compiled"

elm make src/Window.elm --output=dist/public/elm.js

echo "Frontend compiled"

echo "Build complete"