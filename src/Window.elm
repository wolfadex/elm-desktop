module Window exposing (..)

import Browser exposing (Document)
import Desktop.Effect exposing (Effect)
import Desktop.Window
import Html
import Html.Attributes as Attrs
import Html.Events as Events
import Types exposing (ToBackendMsg(..), ToWindowMsg(..), WindowId, toBackendMsgCodec, toWindowMsgCodec)


main : Desktop.Window.Program () Model Msg
main =
    Desktop.Window.app
        { init = init
        , update = update
        , subscriptions = subscriptions
        , updateFromBackend = updateFromBackend
        , view = view
        , codecs =
            { fromBackend = toWindowMsgCodec
            , toBackend = toBackendMsgCodec
            }
        }


type alias Model =
    { count : Int, windowId : WindowId }


init : ( WindowId, () ) -> ( Model, Effect Msg )
init ( windowId, () ) =
    ( { count = 0
      , windowId = windowId
      }
    , Desktop.Effect.none
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


type Msg
    = WinNoOp
    | Increment
    | Decrement
    | IncrementMany
    | DecrementMany


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        WinNoOp ->
            ( model, Desktop.Effect.none )

        Increment ->
            ( { model | count = model.count + 1 }, Desktop.Effect.none )

        Decrement ->
            ( { model | count = model.count - 1 }, Desktop.Effect.none )

        IncrementMany ->
            ( model
            , Desktop.Window.toBackend toBackendMsgCodec model.windowId (IncrementBy 3 model.count)
            )

        DecrementMany ->
            ( model
            , Desktop.Window.toBackend toBackendMsgCodec model.windowId (DecrementBy 3 model.count)
            )


updateFromBackend : ToWindowMsg -> Model -> ( Model, Effect Msg )
updateFromBackend msg model =
    case msg of
        TWNoOp ->
            ( model, Desktop.Effect.none )

        SetCount amount ->
            ( { model | count = amount }, Desktop.Effect.none )


view : Model -> Document Msg
view model =
    { title = "Counting!"
    , body =
        [ Html.div
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
        ]
    }
