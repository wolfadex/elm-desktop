module Server exposing (..)

import Desktop.Server.Effect as Effect
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
        , effect : Cmd ServerMsg
        }
init _ =
    { title = "Desktop Counter"
    , width = 800
    , height = 600
    , model = {}
    , effect = Cmd.none
    }


subscriptions : Model -> Sub ServerMsg
subscriptions _ =
    Sub.none


update : ServerMsg -> Model -> ( Model, Cmd ServerMsg )
update msg model =
    case msg of
        SerNoOp ->
            ( model, Cmd.none )


updateFromWindow : Value -> ToServer -> Model -> ( Model, Cmd ServerMsg )
updateFromWindow window msg model =
    case msg of
        TSNoOp ->
            ( model, Cmd.none )

        IncrementBy change amount ->
            ( model, Effect.toWindow window (SetCount (amount + change)) )

        DecrementBy change amount ->
            ( model, Effect.toWindow window (SetCount (amount + change)) )
