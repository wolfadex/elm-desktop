module Desktop.Server.Effect exposing (..)

import Interop
import Json.Decode
import Json.Encode
import Types exposing (ToWindow)


printLn : String -> ServerEffect msg
printLn =
    EffPrintLn


runCommand : Command msg -> ServerEffect msg
runCommand =
    EffCommand


batch : List (ServerEffect msg) -> ServerEffect msg
batch =
    Effbatch


none : ServerEffect msg
none =
    EffNone


type ServerEffect msg
    = EffNone
    | Effbatch (List (ServerEffect msg))
    | EffCommand (Command msg)
    | EffPrintLn String
    | EffToWindow Int ToWindow


type alias Command msg =
    { command : String
    , arguments : List String
    , stderr : String -> msg
    , stdout : String -> msg
    , done : Int -> msg
    }


toWindow : Int -> ToWindow -> ServerEffect msg
toWindow =
    EffToWindow


getEnvVariable : String -> Maybe String
getEnvVariable key =
    Interop.eval
        { msg = "GET_ENV", args = Json.Encode.string key }
        Json.Decode.string
        |> Result.toMaybe
