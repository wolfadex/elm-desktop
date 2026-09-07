module Backend exposing (main)

import Jukai
import Jukai.Backend
import Types exposing (BackendModel, BackendMsg(..), ToBackend(..), ToFrontend(..))


main : Program () BackendModel Jukai.Backend.Msg
main =
    Jukai.Backend.worker
        { init = init
        , update = update
        , updateFromFrontend = updateFromFrontend
        , subscriptions = \_ -> Sub.none
        }


init : () -> ( BackendModel, Cmd BackendMsg )
init _ =
    ( { pingsReceived = 0
      , window = Nothing
      }
    , Jukai.openWindow WindowOpened { width = 800, height = 600 }
    )


update : BackendMsg -> BackendModel -> ( BackendModel, Cmd BackendMsg )
update msg model =
    case msg of
        WindowOpened (Err err) ->
            ( model, Cmd.none )

        WindowOpened (Ok window) ->
            ( { model | window = Just window }, Cmd.none )


updateFromFrontend : Jukai.Window -> ToBackend -> BackendModel -> ( BackendModel, Cmd BackendMsg )
updateFromFrontend window msg model =
    case msg of
        Ping ->
            ( { model | pingsReceived = model.pingsReceived + 1 }
            , Jukai.Backend.sendToFrontend window Pong
            )
