module Desktop.Server.Effect exposing
    ( Os(..)
    , getOs
    , printLn
    , getEnvVariable
    , getCwd
    , setCwd
    , ServerEffect(..)
    , none
    , batch
    , Command
    , runCommand
    , toWindow
    )

{-| A collection of synchronous and asynchronous effects for the Server side of your app. These are effects because they are in some way interacting with things outside the confines of your app.


## Synchronous

@docs Os
@docs getOs
@docs printLn
@docs getEnvVariable


### File System

@docs getCwd
@docs setCwd


## Asynchronous

@docs ServerEffect
@docs none
@docs batch
@docs none
@docs Command
@docs runCommand
@docs toWindow

-}

import Error
import Interop
import Json.Decode
import Json.Encode
import Types exposing (ToWindow)



---- SYNCHRONOUS ----


{-| Prints the first argument to the command line and returns the second argument.
-}
printLn : String -> a -> a
printLn str val =
    Interop.eval
        { msg = "PRINT_LINE", args = Json.Encode.string str }
        |> (\_ -> val)


{-| -}
getEnvVariable : String -> Maybe String
getEnvVariable key =
    Interop.eval
        { msg = "GET_ENV", args = Json.Encode.string key }
        Json.Decode.string
        |> Result.toMaybe


{-| -}
getCwd : String
getCwd =
    Interop.eval
        { msg = "GET_CWD", args = Json.Encode.null }
        Json.Decode.string
        |> Result.toMaybe
        |> Maybe.withDefault ""


{-| -}
setCwd : String -> Result String String
setCwd dir =
    Interop.eval
        { msg = "CHANGE_CWD", args = Json.Encode.string dir }
        (Json.Decode.succeed dir)
        |> Result.mapError Error.toString


{-| -}
type Os
    = OsUnknown String
    | Aix
    | Darwin
    | FreeBsd
    | Linux
    | OpenBsd
    | SunOs
    | Win32
    | Android


{-| -}
getOs : Os
getOs =
    Interop.eval
        { msg = "GET_PLATFORM", args = Json.Encode.null }
        decodeOsPlatform
        |> Result.toMaybe
        |> Maybe.withDefault (OsUnknown "")


decodeOsPlatform : Json.Decode.Decoder Os
decodeOsPlatform =
    Json.Decode.map
        (\os ->
            case os of
                "aix" ->
                    Aix

                "darwin" ->
                    Darwin

                "freebsd" ->
                    FreeBsd

                "linux" ->
                    Linux

                "openbsd" ->
                    OpenBsd

                "sunos" ->
                    SunOs

                "win32" ->
                    Win32

                "android" ->
                    Android

                _ ->
                    OsUnknown os
        )
        Json.Decode.string



---- ASYNCHRONOUS ----


{-| -}
type ServerEffect msg
    = EffNone
    | Effbatch (List (ServerEffect msg))
    | EffCommand (Command msg)
    | EffToWindow Int ToWindow


{-| The command you want to run, and its arguments.
-}
type alias Command msg =
    { command : String
    , arguments : List String
    , stderr : String -> msg
    , stdout : String -> msg
    , done : Int -> msg
    }


{-| -}
runCommand : Command msg -> ServerEffect msg
runCommand =
    EffCommand


{-| -}
batch : List (ServerEffect msg) -> ServerEffect msg
batch =
    Effbatch


{-| -}
none : ServerEffect msg
none =
    EffNone


{-| -}
toWindow : Int -> ToWindow -> ServerEffect msg
toWindow =
    EffToWindow
