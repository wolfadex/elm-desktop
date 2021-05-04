# elm-desktop

WIP, PoC, framework for building desktop apps with Elm. The basic layout is a `Server.elm`, `Types.elm`, and `Window.elm` which you as the user modify and build your app on top off, e.g. everything in `src/`.

To compile run `npm run dev:build` and to start your app run `npm run dev:start`.

This currently depends on [webview]() For Linux users this means GTK3 and GtkWebkit2 must be installed. Ubunutu users can install them with:

```
sudo apt install libwebkit2gtk-4.0-dev
```
