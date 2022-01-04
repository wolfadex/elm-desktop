port module Desktop.Backend exposing (main)

import Json.Encode exposing (Value)
import Main


main : Program () () msg
main =
    Platform.worker
        { init = init
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }


init : () -> ( (), Cmd msg )
init flags =
    ( ()
    , createWindowInternal Main.app.options
    )


port createWindowInternal : Value -> Cmd msg
