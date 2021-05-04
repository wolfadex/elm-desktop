port module Desktop.Server exposing (..)

import Desktop.Server.Effect exposing (ServerEffect(..))
import Dict exposing (Dict)
import Interop
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Server
import Task
import Types exposing (ServerModel, ServerMsg(..), ToServer(..), WindowId)


main : Program Value Model Msg
main =
    Platform.worker
        { init = init Server.app.init
        , subscriptions = subscriptions Server.app.subscriptions
        , update = update Server.app.updateFromWindow Server.app.update
        }


type alias Model =
    { serverModel : ServerModel
    , serverCommandsStdErr : Dict Int (String -> ServerMsg)
    , serverCommandsStdOut : Dict Int (String -> ServerMsg)
    , serverCommandsDone : Dict Int (Int -> ServerMsg)
    , nextId : Int
    , window : Maybe Value
    }


init :
    (Value -> { title : String, width : Int, height : Int, model : ServerModel, effect : ServerEffect ServerMsg })
    -> Value
    -> ( Model, Cmd Msg )
init serverInit flags =
    let
        serverInited =
            serverInit flags
    in
    fromEffect serverInited.effect
        { serverModel = serverInited.model
        , serverCommandsStdErr = Dict.empty
        , serverCommandsStdOut = Dict.empty
        , serverCommandsDone = Dict.empty
        , nextId = 0
        , window = Nothing
        }
        |> Tuple.mapSecond
            (\cmd ->
                Cmd.batch
                    [ cmd
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


port fromServer : Value -> Cmd msg


type Msg
    = NoOp
    | ServerMessage ServerMsg
    | CommandStdErr Value
    | CommandStdOut Value
    | CommandDone Value
    | WindowConnection Value
    | ToServerMessage Value


update :
    (WindowId -> ToServer -> ServerModel -> ( ServerModel, ServerEffect ServerMsg ))
    -> (ServerMsg -> ServerModel -> ( ServerModel, ServerEffect ServerMsg ))
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
            updateServer (serverUpdateFromWindow 0 (Debug.todo "REPLACE_ME::_Json_unwrap(msgVal)")) model

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


updateServer : (ServerModel -> ( ServerModel, ServerEffect ServerMsg )) -> Model -> ( Model, Cmd Msg )
updateServer serverUpdate model =
    let
        ( serverModel, serverEffect ) =
            serverUpdate model.serverModel
    in
    fromEffect serverEffect { model | serverModel = serverModel }


decodeCommandResponse : Decoder a -> Value -> Result String ( Int, a )
decodeCommandResponse valDecoder =
    Json.Decode.decodeValue (decodeCommandResponseHelper valDecoder)
        >> Result.mapError (Json.Decode.errorToString >> Debug.log "parse command err")


decodeCommandResponseHelper : Decoder a -> Decoder ( Int, a )
decodeCommandResponseHelper valDecoder =
    Json.Decode.map2 Tuple.pair
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "value" valDecoder)


fromEffect : ServerEffect ServerMsg -> Model -> ( Model, Cmd Msg )
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

        EffCommand command ->
            ( { model
                | serverCommandsStdErr = Dict.insert model.nextId command.stderr model.serverCommandsStdErr
                , serverCommandsStdOut = Dict.insert model.nextId command.stdout model.serverCommandsStdOut
                , serverCommandsDone = Dict.insert model.nextId command.done model.serverCommandsDone
                , nextId = model.nextId + 1
              }
            , Interop.evalAsync
                "RUN_COMMAND"
                (Json.Encode.object
                    [ ( "cmd", Json.Encode.list Json.Encode.string (command.command :: command.arguments) )
                    , ( "id", Json.Encode.int model.nextId )
                    ]
                )
                (Json.Decode.succeed ())
                |> Task.attempt (\_ -> NoOp)
            )

        EffPrintLn message ->
            Interop.eval
                { msg = "PRINT_LINE", args = Json.Encode.string message }
                (Json.Decode.succeed ())
                |> (\_ -> ( model, Cmd.none ))

        EffToWindow windowId val ->
            ( model
            , fromServer
                (Json.Encode.object
                    [ ( "socket", Maybe.withDefault Json.Encode.null model.window )
                    , ( "message", Debug.todo "REPLACE_ME::_Json_wrap(val)" )
                    ]
                )
            )
