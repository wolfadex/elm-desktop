port module Backend exposing (main)

import Desktop
import Desktop.Backend
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


init : Flags -> ( BackendModel, Cmd BackendMsg )
init {} =
    ( { pingsReceived = 0
      , window = Nothing
      , hyperswarm = Initializing
      }
    , Cmd.batch
        [ Desktop.openDebugWindow Debug.todo
            -- Desktop.openWindow WindowOpened
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
            let
                _ =
                    Debug.log "WindowOpened Ok" ()
            in
            ( { model | window = Just window }
            , case Debug.log "hyperswarm?" model.hyperswarm of
                Ready ->
                    Desktop.Backend.sendToFrontend window AppReady

                _ ->
                    Cmd.none
            )

        SwarmReady () ->
            let
                _ =
                    Debug.log "SwarmReady" ()
            in
            ( { model | hyperswarm = Ready }
            , case Debug.log "has window?" model.window of
                Nothing ->
                    Cmd.none

                Just window ->
                    Desktop.Backend.sendToFrontend window AppReady
            )

        DataReceived data ->
            Debug.todo ""


updateFromFrontend : Desktop.Window -> ToBackend -> BackendModel -> ( BackendModel, Cmd BackendMsg )
updateFromFrontend window msg model =
    case msg of
        Ping ->
            ( { model | pingsReceived = model.pingsReceived + 1 }
            , Desktop.Backend.sendToFrontend window Pong
            )
