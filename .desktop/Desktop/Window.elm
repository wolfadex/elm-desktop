port module Desktop.Window exposing (main)

import Browser
import Codec exposing (Value)
import Desktop.Effect
import Html
import Main


main =
    Browser.document
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init () =
    let
        ( model, effects ) =
            Main.app.init
    in
    ( model
    , Desktop.Effect.toCmd UserWindowMessage effects
    )


type Msg windowMsg
    = UserWindowMessage windowMsg
    | UserWindowSub windowMsg
    | SavedModelLoaded Value


subscriptions model =
    Sub.batch
        [ Sub.map UserWindowSub (Main.app.subscriptions model)
        , case Main.app.persist of
            Nothing ->
                Sub.none

            Just _ ->
                savedModelLoaded SavedModelLoaded
                    |> Debug.log "waiting for model, 1"
        ]


port savedModelLoaded : (Value -> msg) -> Sub msg


update msg model =
    case msg of
        UserWindowMessage message ->
            Main.app.update message model
                |> Tuple.mapSecond (Desktop.Effect.toCmd UserWindowMessage)

        UserWindowSub message ->
            Main.app.update message model
                |> Tuple.mapSecond (Desktop.Effect.toCmd UserWindowMessage)

        SavedModelLoaded encodedModel ->
            case Main.app.persist of
                Nothing ->
                    ( model, Cmd.none )

                Just persist ->
                    persist.onLoad { currentModel = model, savedModel = Codec.decodeValue persist.codec encodedModel }
                        |> Tuple.mapSecond (Desktop.Effect.toCmd UserWindowMessage)


view model =
    let
        { title, body } =
            Main.app.view model
    in
    { title = title
    , body = List.map (Html.map UserWindowMessage) body
    }
