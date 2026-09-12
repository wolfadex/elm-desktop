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
    | UserWantToCreateNetwork
    | UserWantsToJoinNetwork String


type ToFrontend
    = PickCreateOrJoin
    | InitializingSwarm String
    | NetworkJoined String
    | TodosRecieved String
    | DeviceNameUnset
    | DeviceNameSet String


type FrontendModel
    = InitializingFrontend { key : Desktop.FrontendKey, deviceName : DeviceName, network : NetworkState }
    | InitializedFrontend { key : Desktop.FrontendKey, todoDoc : Crdt.Doc.Doc Todo, secret : String }


type DeviceName
    = LocatingName
    | NeedsName String
    | SettingName String
    | HasName (Crdt.Doc.Doc Todo)


type NetworkState
    = FindingSecret
    | CreatingSecret String
    | JoiningSecret String
    | JoiningNetwork String
    | JoinError String String
    | JoinedNetwork String


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
    | MakeThisDeviceTheFirstDevice
    | MakeThisDeviceAnAdditionalDevice
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
    , savedTodos : Maybe String
    , hyperswarm : Hyperswarm
    }


type Hyperswarm
    = Uninitialized
    | CreateOrJoin
    | Initializing String
    | Joining { secret : String, topic : Json.Encode.Value, payloadKey : Json.Encode.Value }
    | Joined Swarm


type alias Swarm =
    { myPublicKey : String
    , peers : Dict String Json.Encode.Value
    , secret : String
    , topic : Json.Encode.Value
    , payloadKey : Json.Encode.Value
    }


type RemoteData e a
    = Loading
    | Loaded a
    | Error e


type BackendMsg
    = WindowOpened (Result String Desktop.Window)
    | PeerConnected ( String, Json.Encode.Value )
    | PeerDisconnected String
    | DoesSecretExist (Maybe String)
    | StoreReady { secret : String, topic : Json.Encode.Value, payloadKey : Json.Encode.Value }
    | SwarmReady { secret : String, payloadKey : Json.Encode.Value, topic : Json.Encode.Value, myPublicKey : String }
    | SwarmError String
    | DataReceived ( Bool, String )
    | SettingsLoaded (Result Desktop.FileError String)
    | SettingsSaved Settings (Result Desktop.FileError ())
    | TodosSaved (Result Desktop.FileError ())
    | TodosLoaded (Result Desktop.FileError String)
