port module Backend exposing (main)

import Desktop
import Desktop.Backend
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
        , initializeHyperswarm appName
        , Desktop.loadUserData key
            TodosLoaded
            "todos.json"
        ]
    )


appName : String
appName =
    "wolfadex-todo"


port initializeHyperswarm : String -> Cmd msg


port swarmReady : (() -> msg) -> Sub msg


port sendData : String -> Cmd msg


port dataReceived : (String -> msg) -> Sub msg


subscriptions : BackendModel -> Sub BackendMsg
subscriptions _ =
    Sub.batch
        [ swarmReady SwarmReady
        , dataReceived DataReceived
        ]


update : BackendMsg -> BackendModel -> ( BackendModel, Cmd BackendMsg )
update msg model =
    case msg of
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
                    Loaded () ->
                        Desktop.Backend.sendToFrontend model.key window AppReady

                    _ ->
                        Cmd.none
                , case model.savedTodos of
                    Nothing ->
                        Cmd.none

                    Just savedTodos ->
                        Desktop.Backend.sendToFrontend model.key window (TodosRecieved savedTodos)
                ]
            )

        SwarmReady () ->
            ( { model | hyperswarm = Loaded () }
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
            Debug.todo (Debug.toString err)

        TodosLoaded (Ok savedTodos) ->
            case model.window of
                Nothing ->
                    ( { model | savedTodos = Just savedTodos }, Cmd.none )

                Just window ->
                    ( model
                    , Desktop.Backend.sendToFrontend model.key window (TodosRecieved savedTodos)
                    )


updateFromFrontend : Desktop.Window -> ToBackend -> BackendModel -> ( BackendModel, Cmd BackendMsg )
updateFromFrontend window msg model =
    case msg of
        SaveTodos todos ->
            ( model
            , Cmd.batch
                [ Desktop.saveUserData model.key
                    TodosSaved
                    { filename = "todos.json"
                    , data = todos
                    }
                , sendData todos
                ]
            )
