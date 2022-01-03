port module Desktop.Backend exposing
    ( BackendCodec
    , Program
    , app
    , toWindow
    )

import Codec exposing (Codec)
import Desktop.Effect exposing (Effect)
import Json.Decode
import Json.Encode exposing (Value)
import Types exposing (WindowId)


type alias Program flags model backendMsg =
    Platform.Program flags (Model model) (Msg backendMsg)


app :
    { init : flags -> ( model, Effect backendMsg )
    , update : backendMsg -> model -> ( model, Effect backendMsg )
    , updateFromWindow : WindowId -> fromWindowMsg -> model -> ( model, Effect backendMsg )
    , subscriptions : model -> Sub backendMsg
    , codecs : BackendCodec fromWindowMsg toWindowMsg
    }
    -> Program flags model backendMsg
app config =
    Platform.worker
        { init = init config.codecs config.init
        , update = update config.codecs config.updateFromWindow config.update
        , subscriptions = subscriptions config.codecs config.subscriptions
        }


type alias BackendCodec fromWindowMsg toWindowMsg =
    { fromWindow : Codec fromWindowMsg
    , toWindow : Codec toWindowMsg
    }


type alias Model model =
    { userModel : model
    }


init :
    BackendCodec fromWindowMsg toWindowMsg
    -> (flags -> ( model, Effect backendMsg ))
    -> flags
    -> ( Model model, Cmd (Msg backendMsg) )
init codecs userInit flags =
    let
        ( userModel, userEffect ) =
            userInit flags
    in
    ( { userModel = userModel }
    , Desktop.Effect.toCmd UserBackendMessage userEffect
    )


type Msg backendMsg
    = MessageFromWindow Value
    | UserBackendMessage backendMsg
    | UserBackendSub backendMsg


subscriptions :
    BackendCodec fromWindowMsg toWindowMsg
    -> (model -> Sub backendMsg)
    -> Model model
    -> Sub (Msg backendMsg)
subscriptions codecs userSubscriptions model =
    Sub.batch
        [ Sub.map UserBackendSub (userSubscriptions model.userModel)
        , fromWindowInternal MessageFromWindow
        ]


update :
    BackendCodec fromWindowMsg toWindowMsg
    -> (WindowId -> fromWindowMsg -> model -> ( model, Effect backendMsg ))
    -> (backendMsg -> model -> ( model, Effect backendMsg ))
    -> Msg backendMsg
    -> Model model
    -> ( Model model, Cmd (Msg backendMsg) )
update codecs userUpdateFromWindow userUpdate msg model =
    case msg of
        UserBackendMessage message ->
            let
                ( userModel, userEffect ) =
                    userUpdate message model.userModel
            in
            ( { model | userModel = userModel }, Desktop.Effect.toCmd UserBackendMessage userEffect )

        MessageFromWindow value ->
            case Codec.decodeValue (fromWindowCodec codecs.fromWindow) value of
                Ok ( windowId, fromWindowMessage ) ->
                    let
                        ( userModel, userEffect ) =
                            userUpdateFromWindow windowId fromWindowMessage model.userModel
                    in
                    ( { model | userModel = userModel }, Desktop.Effect.toCmd UserBackendMessage userEffect )

                Err err ->
                    Debug.todo ("TODO: " ++ Json.Decode.errorToString err)

        UserBackendSub message ->
            let
                ( userModel, userEffect ) =
                    userUpdate message model.userModel
            in
            ( { model | userModel = userModel }, Desktop.Effect.toCmd UserBackendMessage userEffect )


fromWindowCodec : Codec fromWindowMsg -> Codec ( WindowId, fromWindowMsg )
fromWindowCodec fromWindow =
    Codec.object Tuple.pair
        |> Codec.field "windowId" Tuple.first Codec.string
        |> Codec.field "toBackendMsg" Tuple.second fromWindow
        |> Codec.buildObject


toWindowCodec : Codec toWindowMsg -> Codec ( WindowId, toWindowMsg )
toWindowCodec toWindowC =
    Codec.object Tuple.pair
        |> Codec.field "windowId" Tuple.first Codec.string
        |> Codec.field "toWindowMsg" Tuple.second toWindowC
        |> Codec.buildObject


port fromWindowInternal : (Value -> msg) -> Sub msg


port toWindowInternal : Value -> Cmd msg


toWindow : Codec toWindowMsg -> WindowId -> toWindowMsg -> Effect msg
toWindow toWindowC windowId toWindowMsg =
    Desktop.Effect.fromCmd
        (toWindowInternal
            (Codec.encodeToValue
                (toWindowCodec toWindowC)
                ( windowId, toWindowMsg )
            )
        )
