module Desktop.Server.Effect exposing (..)

import Error
import Interop
import Json.Decode
import Json.Encode
import Types exposing (ToWindow)



---- ASYNC ----


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



---- IMMEDIATE ----


printLn : String -> a -> a
printLn str val =
    Interop.eval
        { msg = "PRINT_LINE", args = Json.Encode.string str }
        |> (\_ -> val)


getEnvVariable : String -> Maybe String
getEnvVariable key =
    Interop.eval
        { msg = "GET_ENV", args = Json.Encode.string key }
        Json.Decode.string
        |> Result.toMaybe


getCwd : String
getCwd =
    Interop.eval
        { msg = "GET_CWD", args = Json.Encode.null }
        Json.Decode.string
        |> Result.toMaybe
        |> Maybe.withDefault ""


setCwd : String -> Result String String
setCwd dir =
    Interop.eval
        { msg = "CHANGE_CWD", args = Json.Encode.string dir }
        (Json.Decode.succeed dir)
        |> Result.mapError Error.toString
