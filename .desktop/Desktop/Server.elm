port module Desktop.Server exposing (..)

import Desktop.Server.Command exposing (CommandStatus(..))
import Desktop.Server.Effect exposing (Flag(..), Model, Msg(..))
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Server
import Types exposing (ServerModel, ServerMsg(..), ToServer(..))


main : Program Value Model Msg
main =
    Platform.worker
        { init = init Server.app.init
        , subscriptions = subscriptions Server.app.subscriptions
        , update = update Server.app.updateFromWindow Server.app.update
        }


init :
    (Value -> { title : String, width : Int, height : Int, model : ServerModel, effect : Cmd ServerMsg })
    -> Value
    -> ( Model, Cmd Msg )
init serverInit flags =
    let
        serverInited =
            serverInit flags
    in
    ( { serverModel = serverInited.model
      , window = Nothing
      }
    , Cmd.batch
        [ Cmd.map ServerMessage serverInited.effect
        , openWindow
            (Json.Encode.object
                [ ( "title", Json.Encode.string serverInited.title )
                , ( "width", Json.Encode.int serverInited.width )
                , ( "height", Json.Encode.int serverInited.height )
                ]
            )
        ]
    )


port openWindow : Value -> Cmd msg


subscriptions : (ServerModel -> Sub ServerMsg) -> Model -> Sub Msg
subscriptions serverSubscriptions model =
    Sub.batch
        [ Sub.map ServerMessage (serverSubscriptions model.serverModel)
        , commandUpdate CommandUpdate
        , windowConnection WindowConnection
        , toServer ToServerMessage
        ]


port commandUpdate : (( Value, Value ) -> msg) -> Sub msg


port windowConnection : (Value -> msg) -> Sub msg


port toServer : (Value -> msg) -> Sub msg


update :
    (Value -> ToServer -> ServerModel -> ( ServerModel, Cmd ServerMsg ))
    -> (ServerMsg -> ServerModel -> ( ServerModel, Cmd ServerMsg ))
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update serverUpdateFromWindow serverUpdate msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ServerMessage serverMsg ->
            updateServer (serverUpdate serverMsg) model

        WindowConnection window ->
            ( { model | window = Just window }, Cmd.none )

        ToServerMessage msgVal ->
            updateServer
                (serverUpdateFromWindow
                    (Maybe.withDefault Json.Encode.null model.window)
                    (Debug.todo "REPLACE_ME::_Json_unwrap(msgVal)")
                )
                model

        CommandUpdate ( responseHandler, value ) ->
            case Json.Decode.decodeValue decodeCommandUpdate value of
                Err err ->
                    Debug.todo ("Unexpected error: " ++ Json.Decode.errorToString err)

                Ok updateVal ->
                    let
                        serverMsg =
                            Debug.todo "REPLACE_ME::_Json_unwrap(responseHandler)"
                    in
                    updateServer
                        (serverUpdate (serverMsg updateVal))
                        model


decodeToServerMessage : Decoder ToServer
decodeToServerMessage =
    Json.Decode.andThen
        (\msgStr ->
            case msgStr of
                "TSNoOp" ->
                    Json.Decode.succeed TSNoOp

                _ ->
                    Json.Decode.fail ("Unknown ToServer msg: " ++ msgStr)
        )
        (Json.Decode.field "msg" Json.Decode.string)


updateServer : (ServerModel -> ( ServerModel, Cmd ServerMsg )) -> Model -> ( Model, Cmd Msg )
updateServer serverUpdate model =
    let
        ( serverModel, serverEffect ) =
            serverUpdate model.serverModel
    in
    ( { model | serverModel = serverModel }, Cmd.map ServerMessage serverEffect )


decodeCommandUpdate : Decoder CommandStatus
decodeCommandUpdate =
    Json.Decode.maybe (Json.Decode.field "done" Json.Decode.int)
        |> Json.Decode.andThen
            (\maybeExitCode ->
                case maybeExitCode of
                    Just exitCode ->
                        Json.Decode.succeed (Complete exitCode)

                    Nothing ->
                        Json.Decode.map2
                            (\isOk val ->
                                Running <|
                                    if isOk then
                                        Ok val

                                    else
                                        Err val
                            )
                            (Json.Decode.field "ok" Json.Decode.bool)
                            (Json.Decode.field "value" Json.Decode.string)
            )
