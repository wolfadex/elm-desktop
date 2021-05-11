module Window exposing (..)

import Desktop.Window.Effect as Effect
import Html exposing (Html)
import Html.Attributes as Attrs
import Html.Events as Events
import Json.Encode exposing (Value)
import Types exposing (ServerMsg(..), ToServer(..), ToWindow(..), WindowModel, WindowMsg(..))


app =
    { init = init
    , update = update
    , updateFromServer = updateFromServer
    , subscriptions = subscriptions
    , view = view
    }


type alias Model =
    WindowModel


init : Value -> ( Model, Cmd WindowMsg )
init _ =
    ( { count = 0 }
    , Cmd.none
    )


subscriptions : Model -> Sub WindowMsg
subscriptions _ =
    Sub.none


update : WindowMsg -> Model -> ( Model, Cmd WindowMsg )
update msg model =
    case msg of
        WinNoOp ->
            ( model, Cmd.none )

        Increment ->
            ( { model | count = model.count + 1 }, Cmd.none )

        Decrement ->
            ( { model | count = model.count - 1 }, Cmd.none )

        IncrementMany ->
            ( model
            , Effect.toServer (IncrementBy 3 model.count)
            )

        DecrementMany ->
            ( model
            , Effect.toServer (DecrementBy -3 model.count)
            )


updateFromServer : ToWindow -> Model -> ( Model, Cmd WindowMsg )
updateFromServer msg model =
    case msg of
        TWNoOp ->
            ( model, Cmd.none )

        SetCount amount ->
            ( { model | count = amount }, Cmd.none )


view : Model -> Html WindowMsg
view model =
    Html.div
        [ Attrs.style "display" "flex"
        , Attrs.style "flex-direction" "column"
        , Attrs.style "align-items" "flex-start"
        ]
        [ Html.button
            [ Events.onClick IncrementMany ]
            [ Html.text "+3" ]
        , Html.button
            [ Events.onClick Increment ]
            [ Html.text "+" ]
        , Html.span
            []
            [ Html.text (String.fromInt model.count) ]
        , Html.button
            [ Events.onClick Decrement ]
            [ Html.text "-" ]
        , Html.button
            [ Events.onClick DecrementMany ]
            [ Html.text "-3" ]
        ]
