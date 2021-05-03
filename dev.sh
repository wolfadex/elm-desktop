#/bin/bash

echo "Building Elm..."

elm make desktop/Desktop/Server.elm desktop/Desktop/Window.elm --output=dist/public/elm.js

# find and replace
deno run -A dev.ts

cp dist/public/elm.js dist/elm.mjs

# change the cmpiled elm file to not immediately call the compiled function
perl -i -pe 's/\(function\(scope/function init\(scope/g' dist/elm.mjs
perl -i -pe 's/}\(this\)\);/}/g' dist/elm.mjs

# export the compiled function as the default export
echo "\n\nconst scope = {};\ninit(scope);\nexport default scope.Elm;" >> dist/elm.mjs

# while read -r line ; do
#   # extract the name of the module
#   if [[ $line =~ \$author\$project\$(.+)\$main ]]
#   then
#       name="${BASH_REMATCH[1]}"
#       # add the module as a named export
#       echo "export const ${name} = def.${name};" >> dist/elm.mjs
#   else
#       echo "$line doesn't match" >&2
#   fi
# # find modules being exported with a 'main' function
# done < <(egrep -o 'var \$author\$project\$(.+)\$main' dist/elm.mjs)

echo "Elm compiled"