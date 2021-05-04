port module Desktop.Window exposing (..)

import Browser
import Desktop.Window.Effect exposing (WindowEffect(..))
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
    (Value -> ( WindowModel, WindowEffect WindowMsg ))
    -> Value
    -> ( Model, Cmd Msg )
init windowInit flags =
    let
        ( windowModel, windowEffect ) =
            windowInit flags
    in
    fromEffect windowEffect
        { windowModel = windowModel }


subscriptions : (WindowModel -> Sub WindowMsg) -> Model -> Sub Msg
subscriptions windowSubscriptions model =
    Sub.batch
        [ Sub.map WindowMessage (windowSubscriptions model.windowModel)
        , toWindow ToWindowMessage
        ]


port toWindow : (Value -> msg) -> Sub msg


port fromWindow : Value -> Cmd msg


type Msg
    = NoOp
    | WindowMessage WindowMsg
    | ToWindowMessage Value


update :
    (ToWindow -> WindowModel -> ( WindowModel, WindowEffect WindowMsg ))
    -> (WindowMsg -> WindowModel -> ( WindowModel, WindowEffect WindowMsg ))
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


updateWindow : (WindowModel -> ( WindowModel, WindowEffect WindowMsg )) -> Model -> ( Model, Cmd Msg )
updateWindow windowUpdate model =
    let
        ( windowModel, windowEffect ) =
            windowUpdate model.windowModel
    in
    fromEffect windowEffect { model | windowModel = windowModel }


fromEffect : WindowEffect WindowMsg -> Model -> ( Model, Cmd Msg )
fromEffect effect model =
    case effect of
        EffNone ->
            ( model, Cmd.none )

        Effbatch effects ->
            List.foldl
                (\eff ( resModel, resCmds ) ->
                    Tuple.mapSecond
                        (\cmd -> cmd :: resCmds)
                        (fromEffect eff resModel)
                )
                ( model, [] )
                effects
                |> Tuple.mapSecond Cmd.batch

        EffToServer val ->
            ( model
            , fromWindow (Debug.todo "REPLACE_ME::_Json_wrap(val)")
            )


view : (WindowModel -> Html WindowMsg) -> Model -> Html Msg
view windowView model =
    Html.map WindowMessage (windowView model.windowModel)
