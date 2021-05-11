port module Desktop.Server.Effect exposing (..)

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


### File System

@docs File
@docs Path
@docs Encoding
@docs Flag
@docs readFile
@docs writeFile

-}

import Desktop.Server.Command exposing (CommandStatus)
import Error
import Interop
import Json.Decode
import Json.Encode exposing (Value)
import Task exposing (Task)
import Types exposing (ServerModel, ServerMsg, ToWindow)



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


type alias Model =
    { serverModel : ServerModel
    , window : Maybe Value
    }


type Msg
    = NoOp
    | ServerMessage ServerMsg
    | CommandUpdate ( Value, Value )
    | WindowConnection Value
    | ToServerMessage Value


{-| The command you want to run, and its arguments.
-}
type alias Command =
    { command : String
    , arguments : List String
    }


{-| -}
runCommand : Command -> (CommandStatus -> ServerMsg) -> Task String ()
runCommand command responseHnadler =
    Interop.evalAsync
        "RUN_COMMAND"
        (Json.Encode.object
            [ ( "cmd", Json.Encode.list Json.Encode.string (command.command :: command.arguments) )
            , ( "responseHandler", Debug.todo "REPLACE_ME::_Json_wrap(responseHnadler)" )
            ]
        )
        (Json.Decode.succeed ())
        |> Task.mapError Error.toString


port fromServer : Value -> Cmd msg


{-| -}
toWindow : Value -> ToWindow -> Cmd msg
toWindow window val =
    fromServer
        (Json.Encode.object
            [ ( "socket", window )
            , ( "message", Debug.todo "REPLACE_ME::_Json_wrap(val)" )
            ]
        )



-- FILE SYSTEM


{-| -}
type alias Encoding =
    String


{-| How you want to interacte with the file.

    Append: Open file for appending. The file is created if it does not exist.
    AppendIfDoesntExist: Like `Append` but fails if the path exists.
    AppendAndRead: Open file for reading and appending. The file is created if it does not exist.
    AppendAndReadIfDoesntExist: Like `AppendAndRead` but fails if the path exists.
    Read: Open file for reading. An exception occurs if the file does not exist.
    ReadAndWriteIfDoesntExist: Open file for reading and writing. An exception occurs if the file does not exist.
    Write Open file for writing. The file is created (if it does not exist) or truncated (if it exists).
    WriteIfDoesntExist: Like `Write` but fails if the path exists.
    ReadWriteTruncate: Open file for reading and writing. The file is created (if it does not exist) or truncated (if it exists).

-}
type Flag
    = Append
    | AppendIfDoesntExist
    | AppendAndRead
    | AppendAndReadIfDoesntExist
    | Read
    | ReadAndWriteIfDoesntExist
    | Write
    | WriteIfDoesntExist
    | ReadWriteTruncate


{-| -}
type alias File =
    String


{-| -}
type alias Path =
    String


{-| -}
readFile : { encoding : Encoding, flag : Flag } -> Path -> Task String File
readFile { encoding, flag } path =
    Interop.evalAsync
        "FS_READ_FILE"
        (Json.Encode.object
            [ ( "path", Json.Encode.string path )
            , ( "options"
              , Json.Encode.object
                    [ ( "encoding", Json.Encode.string encoding )
                    , ( "flag", encodeFlag flag )
                    ]
              )
            ]
        )
        Json.Decode.string
        |> Task.mapError Error.toString


{-| -}
writeFile : { path : Path, encoding : Encoding, flag : Flag } -> String -> Task String ()
writeFile { encoding, flag, path } data =
    Interop.evalAsync
        "FS_WRITE_FILE"
        (Json.Encode.object
            [ ( "path", Json.Encode.string path )
            , ( "data", Json.Encode.string data )
            , ( "options"
              , Json.Encode.object
                    [ ( "encoding", Json.Encode.string encoding )
                    , ( "flag", encodeFlag flag )
                    ]
              )
            ]
        )
        (Json.Decode.succeed ())
        |> Task.mapError Error.toString


encodeFlag : Flag -> Value
encodeFlag flag =
    Json.Encode.string <|
        case flag of
            Append ->
                "a"

            AppendIfDoesntExist ->
                "ax"

            AppendAndRead ->
                "a+"

            AppendAndReadIfDoesntExist ->
                "ax+"

            Read ->
                "r"

            ReadAndWriteIfDoesntExist ->
                "r+"

            Write ->
                "w"

            WriteIfDoesntExist ->
                "wx"

            ReadWriteTruncate ->
                "w+"
