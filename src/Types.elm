module Types exposing (..)

import Crdt
import Crdt.Doc
import Desktop
import Dict exposing (Dict)
import Json.Decode
import Json.Encode


type ToBackend
    = SaveTodos String
    | SetDeviceName String


type ToFrontend
    = AppReady
    | TodosRecieved String
    | DeviceNameUnset
    | DeviceNameSet String


type alias FrontendModel =
    { key : Desktop.FrontendKey
    , state : FrontendState
    }


type FrontendState
    = WaitingForDeviceName
    | NeedsDeviceName String
    | SavingDeviceName String
    | ReadyForTodos FrontendReady


type alias FrontendReady =
    { hyperswarm : RemoteData String ()
    , todoDoc : Crdt.Doc.Doc Todo
    }


type alias Todo =
    { newTodo : String
    , todos : List String
    }


type alias TodoDoc =
    { newTodo : Crdt.Ref Todo Crdt.Settable String
    , todos : Crdt.Ref Todo (Crdt.ListK Crdt.Fixed Crdt.Settable String) (List String)
    , schema : Crdt.Schema Crdt.Nested Todo
    }


todoDoc : TodoDoc
todoDoc =
    Crdt.record Todo TodoDoc
        |> Crdt.field "newTodo" .newTodo Crdt.text
        |> Crdt.field "todos" .todos (Crdt.list Crdt.text)
        |> Crdt.build


type TodoStatus
    = NeedsDoing
    | Complete


type FrontendMsg
    = DeviceNameChanged String
    | DeviceNameSubmitted String
    | UserChangedNewTodo String
    | SaveNewTodo String
    | RemoveTodo Int


type alias Settings =
    { version : Int
    , deviceName : String
    }


encodeSettings : Settings -> Json.Encode.Value
encodeSettings settings =
    Json.Encode.object
        [ ( "version", Json.Encode.int settings.version )
        , ( "deviceName", Json.Encode.string settings.deviceName )
        ]


decodeSettings : Json.Decode.Decoder Settings
decodeSettings =
    Json.Decode.field "version" Json.Decode.int
        |> Json.Decode.andThen
            (\version ->
                case version of
                    0 ->
                        Json.Decode.map (Settings version)
                            (Json.Decode.field "deviceName" Json.Decode.string)

                    _ ->
                        Json.Decode.fail "Unknown version"
            )


type alias BackendModel =
    { key : Desktop.BackendKey
    , window : Maybe Desktop.Window
    , settings : RemoteData Desktop.FileError Settings
    , hyperswarm : RemoteData String Hyperswarm
    , savedTodos : Maybe String
    }


type alias Hyperswarm =
    { myPublicKey : String
    , peers : Dict String Json.Encode.Value
    }


type RemoteData e a
    = Loading
    | Loaded a
    | Error e


type BackendMsg
    = WindowOpened (Result String Desktop.Window)
    | PeerConnected ( String, Json.Encode.Value )
    | PeerDisconnected String
    | SwarmReady String
    | DataReceived String
    | SettingsLoaded (Result Desktop.FileError String)
    | SettingsSaved Settings (Result Desktop.FileError ())
    | TodosSaved (Result Desktop.FileError ())
    | TodosLoaded (Result Desktop.FileError String)
