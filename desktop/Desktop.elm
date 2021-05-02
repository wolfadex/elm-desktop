port module Desktop exposing (..)

import Desktop.Effect exposing (Effect(..))
import Desktop.Window exposing (Window) 
import Dict exposing (Dict, update)
import Interop
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Platform
import Task


type alias DesktopApp flags model msg =
    Program flags (Model msg model) (Msg msg)


application :
    { init : flags -> ( userModel, Effect userMsg )
    , update : userMsg -> userModel -> ( userModel, Effect userMsg )
    , subscriptions : userModel -> Sub userMsg
    }
    -> DesktopApp flags userModel userMsg
application config =
    Platform.worker
        { init = init config.init
        , update = update config.update
        , subscriptions = subscriptions config.subscriptions
        }


type alias Model userMsg userModel =
    { userModel : userModel
    , userCommandsStdErr : Dict Id (String -> userMsg)
    , userCommandsStdOut : Dict Id (String -> userMsg)
    , userCommandsDone : Dict Id (Int -> userMsg)
    , windowsOpening : Dict Id (Window -> userMsg)
    , nextId : Id
    }


type alias Id =
    Int


init : (flags -> ( userModel, Effect userMsg )) -> flags -> ( Model userMsg userModel, Cmd (Msg userMsg) )
init userInit flags =
    let
        ( userModel, userEffect ) =
            userInit flags
    in
    fromEffect userEffect
        { userModel = userModel
        , userCommandsStdErr = Dict.empty
        , userCommandsStdOut = Dict.empty
        , userCommandsDone = Dict.empty
        , windowsOpening = Dict.empty
        , nextId = 0
        }


subscriptions : (userModel -> Sub userMsg) -> Model userMsg userModel -> Sub (Msg userMsg)
subscriptions userSubscriptions model =
    Sub.batch
        [ Sub.map UserMessage (userSubscriptions model.userModel)
        , commandStdErr CommandStdErr
        , commandStdOut CommandStdOut
        , commandDone CommandDone
        , windowOpened WindowOpened
        ]


port commandStdErr : (Value -> msg) -> Sub msg


port commandStdOut : (Value -> msg) -> Sub msg


port commandDone : (Value -> msg) -> Sub msg


port windowOpened : (Value -> msg) -> Sub msg


type Msg userMsg
    = UserMessage userMsg
    | NoOp
    | CommandStdErr Value
    | CommandStdOut Value
    | CommandDone Value
    | WindowOpened Value


update :
    (userMsg -> userModel -> ( userModel, Effect userMsg ))
    -> Msg userMsg
    -> Model userMsg userModel
    -> ( Model userMsg userModel, Cmd (Msg userMsg) )
update userUpdate msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        UserMessage userMsg ->
            updateUser userUpdate userMsg model

        CommandStdErr errVal ->
            case decodeCommandResponse Json.Decode.string errVal of
                Err _ ->
                    ( model, Cmd.none )

                Ok ( id, value ) ->
                    case Dict.get id model.userCommandsStdErr of
                        Nothing ->
                            let
                                _ =
                                    Debug.log "no msg" id
                            in
                            ( model, Cmd.none )

                        Just userMsg ->
                            updateUser userUpdate (userMsg value) model

        CommandStdOut outVal ->
            case decodeCommandResponse Json.Decode.string outVal of
                Err _ ->
                    ( model, Cmd.none )

                Ok ( id, value ) ->
                    case Dict.get id model.userCommandsStdOut of
                        Nothing ->
                            let
                                _ =
                                    Debug.log "no msg" id
                            in
                            ( model, Cmd.none )

                        Just userMsg ->
                            updateUser userUpdate (userMsg value) model

        CommandDone doneVal ->
            case decodeCommandResponse Json.Decode.int doneVal of
                Err _ ->
                    ( model, Cmd.none )

                Ok ( id, value ) ->
                    let
                        tempModel =
                            { model
                                | userCommandsStdErr = Dict.remove id model.userCommandsStdErr
                                , userCommandsStdOut = Dict.remove id model.userCommandsStdOut
                                , userCommandsDone = Dict.remove id model.userCommandsDone
                            }
                    in
                    case Dict.get id model.userCommandsDone of
                        Nothing ->
                            let
                                _ =
                                    Debug.log "no msg" id
                            in
                            ( tempModel, Cmd.none )

                        Just userMsg ->
                            updateUser userUpdate (userMsg value) tempModel

        WindowOpened val ->
            case Json.Decode.decodeValue decodeWindowOpen val of
                Err err ->
                    let
                        _ =
                            Debug.log "window open err" err
                    in
                    ( model, Cmd.none )

                Ok ( id, window ) ->
                    let
                        tempModel =
                            { model | windowsOpening = Dict.remove id model.windowsOpening }
                    in
                    case Dict.get id model.windowsOpening of
                        Nothing ->
                            ( tempModel, Cmd.none )

                        Just userMsg ->
                            updateUser userUpdate (userMsg window) tempModel


decodeWindowOpen : Decoder ( Id, Window )
decodeWindowOpen =
    Json.Decode.map2 Tuple.pair
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "window" Json.Decode.value)



updateUser :
    (userMsg -> userModel -> ( userModel, Effect userMsg ))
    -> userMsg
    -> Model userMsg userModel
    -> ( Model userMsg userModel, Cmd (Msg userMsg) )
updateUser userUpdate userMsg model =
    let
        ( userModel, userEffect ) =
            userUpdate userMsg model.userModel
    in
    fromEffect userEffect { model | userModel = userModel }


decodeCommandResponse : Decoder a -> Value -> Result String ( Id, a )
decodeCommandResponse valDecoder =
    Json.Decode.decodeValue (decodeCommandResponseHelper valDecoder)
        >> Result.mapError (Json.Decode.errorToString >> Debug.log "parse command err")


decodeCommandResponseHelper : Decoder a -> Decoder ( Id, a )
decodeCommandResponseHelper valDecoder =
    Json.Decode.map2 Tuple.pair
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "value" valDecoder)


fromEffect : Effect userMsg -> Model userMsg userModel -> ( Model userMsg userModel, Cmd (Msg userMsg) )
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
                | userCommandsStdErr = Dict.insert model.nextId command.stderr model.userCommandsStdErr
                , userCommandsStdOut = Dict.insert model.nextId command.stdout model.userCommandsStdOut
                , userCommandsDone = Dict.insert model.nextId command.done model.userCommandsDone
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

        EffOpenWindow config ->
            ( { model
                | windowsOpening = Dict.insert model.nextId config.onOpen model.windowsOpening
                , nextId = model.nextId + 1
              }
            , Interop.evalAsync
                "OPEN_WINDOW"
                (Json.Encode.object
                    [ ( "title", Json.Encode.string config.title )
                    , ( "width", Json.Encode.int config.width )
                    , ( "height", Json.Encode.int config.height )
                    , ( "id", Json.Encode.int model.nextId )
                    ]
                )
                (Json.Decode.succeed ())
                |> Task.attempt (\_ -> NoOp)
            )
