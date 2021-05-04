port module Desktop.Window.Effect exposing (..)

import Json.Encode exposing (Value)
import Types exposing (ToServer)


port fromWindow : Value -> Cmd msg


toServer : ToServer -> Cmd msg
toServer val =
    fromWindow (Debug.todo "REPLACE_ME::_Json_wrap(val)")
