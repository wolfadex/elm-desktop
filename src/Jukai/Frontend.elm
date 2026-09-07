module Jukai.Frontend exposing (Config, Msg, application, sendToBackend)

{-| Build the frontend (Electron renderer process) `main` for your app.

Assumes `Types` exposes `FrontendModel`, `FrontendMsg`, `ToBackend` and
`ToFrontend` - see Types.elm. Because this module knows exactly which
module those types live in, it can call the lamdera-compiler-generated
`Types.w3_encode_ToBackend` / `Types.w3_decode_ToFrontend` itself, so you
never pass an encoder or decoder anywhere.

    main =
        Jukai.Frontend.application
            { init = Frontend.init
            , update = Frontend.update
            , updateFromBackend = Frontend.updateFromBackend
            , view = Frontend.view
            , subscriptions = Frontend.subscriptions
            }

-}

import Browser
import Bytes exposing (Bytes)
import Html
import Jukai.Ports
import Lamdera.Wire3
import Types exposing (FrontendModel, FrontendMsg, ToBackend, ToFrontend)


type alias Config flags =
    { init : flags -> ( FrontendModel, Cmd FrontendMsg )
    , update : FrontendMsg -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )

    -- Called whenever a `ToFrontend` value arrives from the backend,
    -- alongside (not instead of) your normal `update`.
    , updateFromBackend : ToFrontend -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
    , view : FrontendModel -> Browser.Document FrontendMsg
    , subscriptions : FrontendModel -> Sub FrontendMsg
    }


{-| Internal message type. `main`'s type becomes
`Program flags FrontendModel Jukai.Frontend.Msg` rather than
`Program flags FrontendModel FrontendMsg` - this is just plumbing to get
bytes off the `toFrontend` port and into `updateFromBackend`; nothing
outside this module ever constructs or pattern-matches on it.
-}
type Msg
    = UserMsg FrontendMsg
    | FromBackend ToFrontend
    | FromBackendDecodeError


application : Config flags -> Program flags FrontendModel Msg
application config =
    Browser.document
        { init = \flags -> config.init flags |> Tuple.mapSecond (Cmd.map UserMsg)
        , update = update config
        , view = view config
        , subscriptions =
            \model ->
                Sub.batch
                    [ Sub.map UserMsg (config.subscriptions model)
                    , Jukai.Ports.toFrontend (decodeIncoming >> toMsg)
                    ]
        }


update : Config flags -> Msg -> FrontendModel -> ( FrontendModel, Cmd Msg )
update config msg model =
    case msg of
        UserMsg userMsg ->
            config.update userMsg model |> Tuple.mapSecond (Cmd.map UserMsg)

        FromBackend toFrontendMsg ->
            config.updateFromBackend toFrontendMsg model |> Tuple.mapSecond (Cmd.map UserMsg)

        FromBackendDecodeError ->
            ( model, Cmd.none )


view : Config flags -> FrontendModel -> Browser.Document Msg
view config model =
    let
        doc =
            config.view model
    in
    { title = doc.title
    , body = List.map (Html.map UserMsg) doc.body
    }


decodeIncoming : Bytes -> Maybe ToFrontend
decodeIncoming =
    Lamdera.Wire3.bytesDecode Types.w3_decode_ToFrontend


toMsg : Maybe ToFrontend -> Msg
toMsg maybeToFrontend =
    case maybeToFrontend of
        Just toFrontendMsg ->
            FromBackend toFrontendMsg

        Nothing ->
            FromBackendDecodeError


{-| Send a message to the backend process from your `update` function.

    UserClickedPing ->
        ( { model | status = Waiting }
        , Jukai.Frontend.sendToBackend Ping
        )

-}
sendToBackend : ToBackend -> Cmd msg
sendToBackend msg =
    Jukai.Ports.sendToBackend (Lamdera.Wire3.bytesEncode (Types.w3_encode_ToBackend msg))
