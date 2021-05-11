port module Desktop.Window exposing (..)

import Browser
import Html exposing (Html)
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Types exposing (ToWindow(..), WindowModel, WindowMsg)
import Window


main : Program Value Model Msg
main =
    Browser.element
        { init = init Window.app.init
        , subscriptions = subscriptions Window.app.subscriptions
        , update = update Window.app.updateFromServer Window.app.update
        , view = view Window.app.view
        }


type alias Model =
    { windowModel : WindowModel
    }


init :
    (Value -> ( WindowModel, Cmd WindowMsg ))
    -> Value
    -> ( Model, Cmd Msg )
init windowInit flags =
    let
        ( windowModel, windowEffect ) =
            windowInit flags
    in
    ( { windowModel = windowModel }
    , Cmd.map WindowMessage windowEffect
    )


subscriptions : (WindowModel -> Sub WindowMsg) -> Model -> Sub Msg
subscriptions windowSubscriptions model =
    Sub.batch
        [ Sub.map WindowMessage (windowSubscriptions model.windowModel)
        , toWindow ToWindowMessage
        ]


port toWindow : (Value -> msg) -> Sub msg


type Msg
    = NoOp
    | WindowMessage WindowMsg
    | ToWindowMessage Value


update :
    (ToWindow -> WindowModel -> ( WindowModel, Cmd WindowMsg ))
    -> (WindowMsg -> WindowModel -> ( WindowModel, Cmd WindowMsg ))
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update updateFromServer windowUpdate msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        WindowMessage windowMsg ->
            updateWindow (windowUpdate windowMsg) model

        ToWindowMessage msgVal ->
            updateWindow (updateFromServer (Debug.todo "REPLACE_ME::_Json_unwrap(msgVal)")) model


decodeToWindowMessage : Decoder ToWindow
decodeToWindowMessage =
    Json.Decode.andThen
        (\msgStr ->
            case msgStr of
                "TWNoOp" ->
                    Json.Decode.succeed TWNoOp

                _ ->
                    Json.Decode.fail ("Unknown ToWindow msg: " ++ msgStr)
        )
        (Json.Decode.field "msg" Json.Decode.string)


updateWindow : (WindowModel -> ( WindowModel, Cmd WindowMsg )) -> Model -> ( Model, Cmd Msg )
updateWindow windowUpdate model =
    let
        ( windowModel, windowEffect ) =
            windowUpdate model.windowModel
    in
    ( { model | windowModel = windowModel }
    , Cmd.map WindowMessage windowEffect
    )


view : (WindowModel -> Html WindowMsg) -> Model -> Html Msg
view windowView model =
    Html.map WindowMessage (windowView model.windowModel)
