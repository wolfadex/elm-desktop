module Main exposing (app)

import Browser exposing (Document)
import Codec exposing (Codec)
import Desktop exposing (DesktopApp)
import Desktop.Effect as Effect exposing (Effect)
import Html
import Html.Attributes as Attrs
import Html.Events as Events


app : DesktopApp Model Msg
app =
    Desktop.app
        { init = init
        , persist = Just persist
        , view = view
        , update = update
        , subscriptions = subscriptions
        , options =
            Desktop.defaultOptions
                |> Desktop.withPosition { x = 0, y = -1 }
                |> Desktop.withWidth 1024
                |> Desktop.withHeight 768
        }


persist :
    { codec : Codec Model
    , onLoad :
        { currentModel : Model
        , savedModel : Result Codec.Error Model
        }
        -> ( Model, Effect Msg )
    }
persist =
    { codec = modelCodec
    , onLoad =
        \{ currentModel, savedModel } ->
            case ( currentModel, savedModel ) |> Debug.log "carl, 1" of
                ( Loaded _, _ ) ->
                    ( currentModel, Effect.none )

                ( _, Ok (Loaded count) ) ->
                    ( Loaded count, Effect.none )

                _ ->
                    ( Loaded 0, Effect.none )
    }


type Model
    = Loading
    | Loaded Int


modelCodec : Codec Model
modelCodec =
    Codec.custom
        (\fLoading fLoaded value ->
            case value of
                Loading ->
                    fLoading

                Loaded m ->
                    fLoaded m
        )
        |> Codec.variant0 "Loading" Loading
        |> Codec.variant1 "Loaded" Loaded Codec.int
        |> Codec.buildCustom


init : ( Model, Effect Msg )
init =
    ( Loading
    , Effect.none
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


type Msg
    = Increment
    | Decrement


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case model of
        Loading ->
            ( Loading, Effect.none )

        Loaded count ->
            case msg of
                Increment ->
                    let
                        newModel =
                            Loaded (count + 1)
                    in
                    ( newModel, Desktop.save (Codec.encodeToValue modelCodec newModel) )

                Decrement ->
                    let
                        newModel =
                            Loaded (count - 1)
                    in
                    ( newModel, Desktop.save (Codec.encodeToValue modelCodec newModel) )


view : Model -> Document Msg
view model =
    { title = "Counter"
    , body =
        [ case model of
            Loading ->
                Html.text "Loading the count..."

            Loaded count ->
                Html.div
                    [ Attrs.style "display" "flex"
                    , Attrs.style "flex-direction" "column"
                    , Attrs.style "align-items" "flex-start"
                    ]
                    [ Html.button
                        [ Events.onClick Increment ]
                        [ Html.text "+" ]
                    , Html.span
                        []
                        [ Html.text (String.fromInt count) ]
                    , Html.button
                        [ Events.onClick Decrement ]
                        [ Html.text "-" ]
                    ]
        ]
    }
