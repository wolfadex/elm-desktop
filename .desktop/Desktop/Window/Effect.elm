module Desktop.Window.Effect exposing (..)

import Types exposing (ToServer)


batch : List (WindowEffect msg) -> WindowEffect msg
batch =
    Effbatch


none : WindowEffect msg
none =
    EffNone


type WindowEffect msg
    = EffNone
    | Effbatch (List (WindowEffect msg))
    | EffToServer ToServer


toServer : ToServer -> WindowEffect msg
toServer =
    EffToServer
