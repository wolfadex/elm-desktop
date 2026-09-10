module Desktop.Backend exposing (Config, Msg, sendToFrontend, worker)

{-| Build the backend (a plain node process, no DOM) `main` for your app.

Assumes `Types` exposes `BackendModel`, `BackendMsg`, `ToBackend` and
`ToFrontend` - see Types.elm. Same deal as Desktop.Frontend: this
module calls the generated `Types.w3_decode_ToBackend` /
`Types.w3_encode_ToFrontend` itself, so nothing gets passed in.

    main =
        Desktop.Backend.worker
            { init = Backend.init
            , update = Backend.update
            , updateFromFrontend = Backend.updateFromFrontend
            , subscriptions = Backend.subscriptions
            }

-}

import Bytes exposing (Bytes)
import Desktop.Internal
import Desktop.Ports
import Lamdera.Wire3
import Types exposing (BackendModel, BackendMsg, ToBackend, ToFrontend)


type alias Config flags =
    { init : flags -> Desktop.Internal.BackendKey -> ( BackendModel, Cmd BackendMsg )
    , update : BackendMsg -> BackendModel -> ( BackendModel, Cmd BackendMsg )
    , updateFromFrontend : Desktop.Internal.Window -> ToBackend -> BackendModel -> ( BackendModel, Cmd BackendMsg )
    , subscriptions : BackendModel -> Sub BackendMsg
    }


{-| Internal message type - see the equivalent note on
`Desktop.Frontend.Msg`.
-}
type Msg
    = UserMsg BackendMsg
    | FromFrontend Desktop.Internal.Window ToBackend
    | FromFrontendDecodeError


worker : Config flags -> Program flags BackendModel Msg
worker config =
    Platform.worker
        { init = \flags -> config.init flags Desktop.Internal.BackendKey |> Tuple.mapSecond (Cmd.map UserMsg)
        , update = update config
        , subscriptions =
            \model ->
                Sub.batch
                    [ Sub.map UserMsg (config.subscriptions model)
                    , Desktop.Ports.toBackend decodeIncoming
                    ]
        }


update : Config flags -> Msg -> BackendModel -> ( BackendModel, Cmd Msg )
update config msg model =
    case msg of
        UserMsg userMsg ->
            config.update userMsg model |> Tuple.mapSecond (Cmd.map UserMsg)

        FromFrontend window toBackendMsg ->
            config.updateFromFrontend window toBackendMsg model |> Tuple.mapSecond (Cmd.map UserMsg)

        FromFrontendDecodeError ->
            ( model, Cmd.none )


decodeIncoming : ( Int, Bytes ) -> Msg
decodeIncoming ( windowId, bytes ) =
    case Lamdera.Wire3.bytesDecode Types.w3_decode_ToBackend bytes of
        Nothing ->
            FromFrontendDecodeError

        Just toBackendMsg ->
            FromFrontend (Desktop.Internal.Window windowId) toBackendMsg


{-| Send a message to a frontend window from your `update` function.

    Ping ->
        ( { model | pingsReceived = model.pingsReceived + 1 }
        , Desktop.Backend.sendToFrontend Pong
        )

-}
sendToFrontend : Desktop.Internal.BackendKey -> Desktop.Internal.Window -> ToFrontend -> Cmd msg
sendToFrontend _ (Desktop.Internal.Window window) msg =
    Desktop.Ports.sendToFrontend ( window, Lamdera.Wire3.bytesEncode (Types.w3_encode_ToFrontend msg) )
