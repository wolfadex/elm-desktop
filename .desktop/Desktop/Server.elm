port module Desktop.Server exposing (..)

import Desktop.Server.Effect exposing (Flag(..), Model, Msg(..))
import Dict
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
      , serverCommandsStdErr = Dict.empty
      , serverCommandsStdOut = Dict.empty
      , serverCommandsDone = Dict.empty
      , nextId = 0
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
        , commandStdErr CommandStdErr
        , commandStdOut CommandStdOut
        , commandDone CommandDone
        , windowConnection WindowConnection
        , toServer ToServerMessage
        ]


port commandStdErr : (Value -> msg) -> Sub msg


port commandStdOut : (Value -> msg) -> Sub msg


port commandDone : (Value -> msg) -> Sub msg


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

        CommandStdErr errVal ->
            case decodeCommandResponse Json.Decode.string errVal of
                Err _ ->
                    ( model, Cmd.none )

                Ok ( id, value ) ->
                    case Dict.get id model.serverCommandsStdErr of
                        Nothing ->
                            let
                                _ =
                                    Debug.log "no msg" id
                            in
                            ( model, Cmd.none )

                        Just serverMsg ->
                            updateServer (serverUpdate (serverMsg value)) model

        CommandStdOut outVal ->
            case decodeCommandResponse Json.Decode.string outVal of
                Err _ ->
                    ( model, Cmd.none )

                Ok ( id, value ) ->
                    case Dict.get id model.serverCommandsStdOut of
                        Nothing ->
                            let
                                _ =
                                    Debug.log "no msg" id
                            in
                            ( model, Cmd.none )

                        Just serverMsg ->
                            updateServer (serverUpdate (serverMsg value)) model

        CommandDone doneVal ->
            case decodeCommandResponse Json.Decode.int doneVal of
                Err _ ->
                    ( model, Cmd.none )

                Ok ( id, value ) ->
                    let
                        tempModel =
                            { model
                                | serverCommandsStdErr = Dict.remove id model.serverCommandsStdErr
                                , serverCommandsStdOut = Dict.remove id model.serverCommandsStdOut
                                , serverCommandsDone = Dict.remove id model.serverCommandsDone
                            }
                    in
                    case Dict.get id model.serverCommandsDone of
                        Nothing ->
                            let
                                _ =
                                    Debug.log "no msg" id
                            in
                            ( tempModel, Cmd.none )

                        Just serverMsg ->
                            updateServer (serverUpdate (serverMsg value)) tempModel


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


decodeCommandResponse : Decoder a -> Value -> Result String ( Int, a )
decodeCommandResponse valDecoder =
    Json.Decode.decodeValue (decodeCommandResponseHelper valDecoder)
        >> Result.mapError (Json.Decode.errorToString >> Debug.log "parse command err")


decodeCommandResponseHelper : Decoder a -> Decoder ( Int, a )
decodeCommandResponseHelper valDecoder =
    Json.Decode.map2 Tuple.pair
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "value" valDecoder)
