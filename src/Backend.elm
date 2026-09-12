port module Backend exposing (main)

import Desktop
import Desktop.Backend
import Dict
import Json.Decode
import Json.Encode
import Types exposing (..)


type alias Flags =
    {}


main : Program Flags BackendModel Desktop.Backend.Msg
main =
    Desktop.Backend.worker
        { init = init
        , update = update
        , updateFromFrontend = updateFromFrontend
        , subscriptions = subscriptions
        }


init : Flags -> Desktop.BackendKey -> ( BackendModel, Cmd BackendMsg )
init {} key =
    ( { key = key
      , window = Nothing
      , settings = Loading
      , hyperswarm = Loading
      , savedTodos = Nothing
      }
    , Cmd.batch
        [ Desktop.openDebugWindow Debug.todo
            -- Desktop.openWindow
            key
            WindowOpened
            { width = 800
            , height = 600
            , frame = True
            , fullscreen = Desktop.AllowFullscreen
            , maxWidth = Nothing
            , maxHeight = Nothing
            , minWidth = Nothing
            , minHeight = Nothing
            , opacity = 1.0
            , resizable = True
            }
        , Desktop.loadUserData key SettingsLoaded "settings.json"
        ]
    )


appName : String
appName =
    "wolfadex-todo"


port initializeHyperswarm : String -> Cmd msg


port swarmReady : (String -> msg) -> Sub msg


port sendData : String -> Cmd msg


port dataReceived : (String -> msg) -> Sub msg


port peerConnected : (( String, Json.Encode.Value ) -> msg) -> Sub msg


port peerDisconnected : (String -> msg) -> Sub msg


subscriptions : BackendModel -> Sub BackendMsg
subscriptions _ =
    Sub.batch
        [ swarmReady SwarmReady
        , dataReceived DataReceived
        , peerConnected PeerConnected
        , peerDisconnected PeerDisconnected
        ]


update : BackendMsg -> BackendModel -> ( BackendModel, Cmd BackendMsg )
update msg model =
    case msg of
        PeerConnected ( publicKey, socket ) ->
            case model.hyperswarm of
                Loaded hyperswarm ->
                    ( { model | hyperswarm = Loaded { hyperswarm | peers = Dict.insert publicKey socket hyperswarm.peers } }
                    , case List.sort (hyperswarm.myPublicKey :: publicKey :: Dict.keys hyperswarm.peers) of
                        leader :: _ ->
                            if leader == hyperswarm.myPublicKey then
                                case model.savedTodos of
                                    Nothing ->
                                        Cmd.none

                                    Just todos ->
                                        sendData todos

                            else
                                Cmd.none

                        _ ->
                            Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        PeerDisconnected publicKey ->
            case model.hyperswarm of
                Loaded hyperswarm ->
                    ( { model | hyperswarm = Loaded { hyperswarm | peers = Dict.remove publicKey hyperswarm.peers } }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        WindowOpened (Err err) ->
            let
                _ =
                    Debug.log "WindowOpened Err" err
            in
            ( model, Cmd.none )

        WindowOpened (Ok window) ->
            ( { model | window = Just window }
            , Cmd.batch
                [ case model.hyperswarm of
                    Loaded _ ->
                        Desktop.Backend.sendToFrontend model.key window AppReady

                    _ ->
                        Cmd.none
                , case model.savedTodos of
                    Nothing ->
                        Cmd.none

                    Just savedTodos ->
                        Desktop.Backend.sendToFrontend model.key window (TodosRecieved savedTodos)
                , case model.settings of
                    Loaded settings ->
                        if settings.deviceName == "" then
                            Desktop.Backend.sendToFrontend model.key window DeviceNameUnset

                        else
                            Desktop.Backend.sendToFrontend model.key window (DeviceNameSet settings.deviceName)

                    _ ->
                        Cmd.none
                ]
            )

        SettingsLoaded (Err err) ->
            let
                _ =
                    Debug.log "SettingsLoaded" (Debug.toString err)
            in
            ( { model | settings = Loaded { version = 0, deviceName = "" } }
            , case model.window of
                Nothing ->
                    Cmd.none

                Just window ->
                    Desktop.Backend.sendToFrontend model.key window DeviceNameUnset
            )

        SettingsLoaded (Ok settingsStr) ->
            case Json.Decode.decodeString decodeSettings settingsStr of
                Err err ->
                    Debug.todo (Debug.toString err)

                Ok settings ->
                    ( { model | settings = Loaded settings }
                    , case model.window of
                        Nothing ->
                            Desktop.loadUserData model.key TodosLoaded "todos.json"

                        Just window ->
                            Cmd.batch
                                [ Desktop.Backend.sendToFrontend model.key window (DeviceNameSet settings.deviceName)
                                , Desktop.loadUserData model.key TodosLoaded "todos.json"
                                ]
                    )

        SettingsSaved _ (Err err) ->
            Debug.todo (Debug.toString err)

        SettingsSaved settings (Ok ()) ->
            case model.window of
                Nothing ->
                    ( model, Cmd.none )

                Just window ->
                    ( model
                    , Desktop.Backend.sendToFrontend model.key window (DeviceNameSet settings.deviceName)
                    )

        SwarmReady myPublicKey ->
            ( { model
                | hyperswarm =
                    Loaded
                        { myPublicKey = myPublicKey
                        , peers = Dict.empty
                        }
              }
            , case model.window of
                Nothing ->
                    Cmd.none

                Just window ->
                    Desktop.Backend.sendToFrontend model.key window AppReady
            )

        DataReceived data ->
            ( model
            , case model.window of
                Nothing ->
                    Cmd.none

                Just window ->
                    Desktop.Backend.sendToFrontend model.key window (TodosRecieved data)
            )

        TodosSaved (Err err) ->
            Debug.todo (Debug.toString err)

        TodosSaved (Ok ()) ->
            ( model, Cmd.none )

        TodosLoaded (Err err) ->
            ( model, initializeHyperswarm appName )

        TodosLoaded (Ok savedTodos) ->
            case model.window of
                Nothing ->
                    ( { model | savedTodos = Just savedTodos }, initializeHyperswarm appName )

                Just window ->
                    ( model
                    , Cmd.batch
                        [ Desktop.Backend.sendToFrontend model.key window (TodosRecieved savedTodos)
                        , initializeHyperswarm appName
                        ]
                    )


updateFromFrontend : Desktop.Window -> ToBackend -> BackendModel -> ( BackendModel, Cmd BackendMsg )
updateFromFrontend window msg model =
    case msg of
        SetDeviceName deviceName ->
            case model.settings of
                Loading ->
                    ( model, Cmd.none )

                Loaded settings ->
                    let
                        updatedSettings =
                            { settings | deviceName = deviceName }
                    in
                    ( model
                    , Desktop.saveUserData model.key
                        (SettingsSaved updatedSettings)
                        { filename = "settings.json"
                        , data =
                            encodeSettings updatedSettings
                                |> Json.Encode.encode 0
                        }
                    )

                Error _ ->
                    let
                        updatedSettings =
                            { version = 0, deviceName = deviceName }
                    in
                    ( model
                    , Desktop.saveUserData model.key
                        (SettingsSaved updatedSettings)
                        { filename = "settings.json"
                        , data =
                            encodeSettings updatedSettings
                                |> Json.Encode.encode 0
                        }
                    )

        SaveTodos todos ->
            ( { model | savedTodos = Just todos }
            , Cmd.batch
                [ Desktop.saveUserData model.key
                    TodosSaved
                    { filename = "todos.json"
                    , data = todos
                    }
                , sendData todos
                ]
            )
