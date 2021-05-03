module Server exposing (..)

import Desktop.Server.Effect as Effect exposing (ServerEffect)
import Json.Encode exposing (Value)
import Types exposing (ServerModel, ServerMsg(..), ToServer(..), ToWindow(..), WindowMsg(..))


app =
    { init = init
    , update = update
    , updateFromWindow = updateFromWindow
    , subscriptions = subscriptions
    }


type alias Model =
    ServerModel


init :
    Value
    ->
        { title : String
        , width : Int
        , height : Int
        , model : Model
        , effect : ServerEffect ServerMsg
        }
init _ =
    { title = "Desktop Counter"
    , width = 800
    , height = 600
    , model = {}

    -- , effect = Effect.toWindow 0 (SetCount -1)
    , effect = Effect.none
    }


subscriptions : Model -> Sub ServerMsg
subscriptions _ =
    Sub.none


update : ServerMsg -> Model -> ( Model, ServerEffect ServerMsg )
update msg model =
    case msg of
        SerNoOp ->
            ( model, Effect.none )


updateFromWindow : Int -> ToServer -> Model -> ( Model, ServerEffect ServerMsg )
updateFromWindow windowId msg model =
    case msg of
        TSNoOp ->
            ( model, Effect.none )

        IncrementBy change amount ->
            ( model, Effect.toWindow windowId (SetCount (amount + change)) )

        DecrementBy change amount ->
            ( model, Effect.toWindow windowId (SetCount (amount + change)) )
