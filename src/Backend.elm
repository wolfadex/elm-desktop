module Backend exposing (..)

import Desktop.Backend
import Desktop.Effect exposing (Effect)
import Desktop.Window
import Types exposing (ToBackendMsg(..), ToWindowMsg(..), WindowId, toBackendMsgCodec, toWindowMsgCodec)


main : Desktop.Backend.Program () Model Msg
main =
    Desktop.Backend.app
        { init = init
        , update = update
        , subscriptions = subscriptions
        , updateFromWindow = updateFromWindow
        , codecs =
            { fromWindow = toBackendMsgCodec
            , toWindow = toWindowMsgCodec
            }
        }


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}
    , Desktop.Window.defaultOptions
        |> Desktop.Window.withPosition { x = 0, y = -1 }
        |> Desktop.Window.create
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Desktop.Effect.none )


updateFromWindow : WindowId -> ToBackendMsg -> Model -> ( Model, Effect Msg )
updateFromWindow windowId msg model =
    case msg of
        TBNoOp ->
            ( model, Desktop.Effect.none )

        IncrementBy adjust orig ->
            ( model
            , Desktop.Backend.toWindow toWindowMsgCodec windowId (SetCount (orig + adjust))
            )

        DecrementBy adjust orig ->
            ( model
            , Desktop.Backend.toWindow toWindowMsgCodec windowId (SetCount (orig - adjust))
            )
