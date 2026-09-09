module Backend exposing (main)

import Desktop
import Desktop.Backend
import Types exposing (BackendModel, BackendMsg(..), ToBackend(..), ToFrontend(..))


type alias Flags =
    {}


main : Program Flags BackendModel Desktop.Backend.Msg
main =
    Desktop.Backend.worker
        { init = init
        , update = update
        , updateFromFrontend = updateFromFrontend
        , subscriptions = \_ -> Sub.none
        }


init : Flags -> ( BackendModel, Cmd BackendMsg )
init {} =
    ( { pingsReceived = 0
      , window = Nothing
      }
      -- , Desktop.openWindow WindowOpened
    , Desktop.openDebugWindow Debug.todo
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
    )


update : BackendMsg -> BackendModel -> ( BackendModel, Cmd BackendMsg )
update msg model =
    case msg of
        WindowOpened (Err err) ->
            ( model, Cmd.none )

        WindowOpened (Ok window) ->
            ( { model | window = Just window }, Cmd.none )


updateFromFrontend : Desktop.Window -> ToBackend -> BackendModel -> ( BackendModel, Cmd BackendMsg )
updateFromFrontend window msg model =
    case msg of
        Ping ->
            ( { model | pingsReceived = model.pingsReceived + 1 }
            , Desktop.Backend.sendToFrontend window Pong
            )
