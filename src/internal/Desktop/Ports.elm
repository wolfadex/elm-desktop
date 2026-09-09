port module Desktop.Ports exposing
    ( sendToBackend
    , sendToFrontend
    , toBackend
    , toFrontend
    )

{-| Low-level ports. Desktop users never touch this module directly -
`Desktop`, `Desktop.Frontend` and `Desktop.Backend` wrap it.

All message traffic between the renderer (frontend) and the node
(backend) process travels as `Bytes`, produced by the lamdera compiler's
generated wire codecs (see `Desktop.Wire`). Electron's IPC is just
carrying opaque binary blobs - it never needs to know what's inside them.

JS side needs to implement, roughly:

  - `openWindow` (renderer -> main): open a `BrowserWindow`
  - `sendToBackend` (renderer -> main -> backend node process): forward bytes
  - `sendToFrontend` (backend -> main -> renderer): forward bytes back
  - `toBackend` (subscription, backend side): deliver bytes arriving from a
    frontend
  - `toFrontend` (subscription, frontend side): deliver bytes arriving from
    the backend

-}

import Bytes exposing (Bytes)


port sendToBackend : Bytes -> Cmd msg


port sendToFrontend : ( Int, Bytes ) -> Cmd msg


port toBackend : (( Int, Bytes ) -> msg) -> Sub msg


port toFrontend : (Bytes -> msg) -> Sub msg
