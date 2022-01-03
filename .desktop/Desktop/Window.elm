port module Desktop.Window exposing
    ( Program
    , app
    , toBackend
    , WindowCodec
    , Options
    , create
    , defaultOptions
    , withWidth
    , withHeight
    , withPosition
    )

{-|


# Program

@docs Program
@docs app
@docs toBackend
@docs WindowCodec


# Creation

@docs Options
@docs create
@docs defaultOptions
@docs withWidth
@docs withHeight
@docs withPosition

-}

import Browser
import Codec exposing (Codec)
import Desktop.Effect exposing (Effect)
import Html
import Json.Decode
import Json.Encode exposing (Value)
import Types exposing (WindowId)


type alias Program flags model windowMsg =
    Platform.Program (Flags flags) (Model model) (Msg windowMsg)


app :
    { init : ( WindowId, flags ) -> ( model, Effect windowMsg )
    , update : windowMsg -> model -> ( model, Effect windowMsg )
    , updateFromBackend : fromBackendMsg -> model -> ( model, Effect windowMsg )
    , subscriptions : model -> Sub windowMsg
    , view : model -> Browser.Document windowMsg
    , codecs : WindowCodec fromBackendMsg toBackendMsg
    }
    -> Program flags model windowMsg
app config =
    Browser.document
        { init = init config.codecs config.init
        , update = update config.codecs config.updateFromBackend config.update
        , subscriptions = subscriptions config.codecs config.subscriptions
        , view = view config.view
        }


type alias WindowCodec fromBackendMsg toBackendMsg =
    { fromBackend : Codec fromBackendMsg
    , toBackend : Codec toBackendMsg
    }


type alias Model model =
    { userModel : model
    , windowId : WindowId
    }


type alias Flags flags =
    { windowId : String
    , userFlags : flags
    }


init :
    WindowCodec fromBackendMsg toBackendMsg
    -> (( WindowId, flags ) -> ( model, Effect windowMsg ))
    -> Flags flags
    -> ( Model model, Cmd (Msg windowMsg) )
init codecs userInit { windowId, userFlags } =
    let
        ( userModel, userEffect ) =
            userInit ( windowId, userFlags )
    in
    ( { userModel = userModel, windowId = windowId }
    , Desktop.Effect.toCmd UserWindowMessage userEffect
    )


type Msg windowMsg
    = MessageFromWindow Value
    | UserWindowMessage windowMsg
    | UserWindowSub windowMsg


subscriptions :
    WindowCodec fromBackendMsg toBackendMsg
    -> (model -> Sub windowMsg)
    -> Model model
    -> Sub (Msg windowMsg)
subscriptions codecs userSubscriptions model =
    Sub.batch
        [ Sub.map UserWindowSub (userSubscriptions model.userModel)
        , fromBackendInternal MessageFromWindow
        ]


update :
    WindowCodec fromBackendMsg toBackendMsg
    -> (fromBackendMsg -> model -> ( model, Effect windowMsg ))
    -> (windowMsg -> model -> ( model, Effect windowMsg ))
    -> Msg windowMsg
    -> Model model
    -> ( Model model, Cmd (Msg windowMsg) )
update codecs userUpdateFromWindow userUpdate msg model =
    case msg of
        UserWindowMessage message ->
            let
                ( userModel, userEffect ) =
                    userUpdate message model.userModel
            in
            ( { model | userModel = userModel }, Desktop.Effect.toCmd UserWindowMessage userEffect )

        MessageFromWindow value ->
            case Codec.decodeValue (fromWindowCodec codecs.fromBackend) value of
                Ok ( windowId, fromWindowMessage ) ->
                    let
                        ( userModel, userEffect ) =
                            userUpdateFromWindow fromWindowMessage model.userModel
                    in
                    ( { model | userModel = userModel }, Desktop.Effect.toCmd UserWindowMessage userEffect )

                Err err ->
                    Debug.todo ("TODO: " ++ Json.Decode.errorToString err)

        UserWindowSub message ->
            let
                ( userModel, userEffect ) =
                    userUpdate message model.userModel
            in
            ( { model | userModel = userModel }, Desktop.Effect.toCmd UserWindowMessage userEffect )


view : (model -> Browser.Document windowMsg) -> Model model -> Browser.Document (Msg windowMsg)
view userView model =
    let
        { title, body } =
            userView model.userModel
    in
    { title = title
    , body = List.map (Html.map UserWindowMessage) body
    }


fromWindowCodec : Codec fromBackendMsg -> Codec ( WindowId, fromBackendMsg )
fromWindowCodec fromBackend =
    Codec.object Tuple.pair
        |> Codec.field "windowId" Tuple.first Codec.string
        |> Codec.field "toWindowMsg" Tuple.second fromBackend
        |> Codec.buildObject


toWindowCodec : Codec toBackendMsg -> Codec ( WindowId, toBackendMsg )
toWindowCodec toWindowC =
    Codec.object Tuple.pair
        |> Codec.field "windowId" Tuple.first Codec.string
        |> Codec.field "toBackendMsg" Tuple.second toWindowC
        |> Codec.buildObject


port fromBackendInternal : (Value -> msg) -> Sub msg


port toBackendInternal : Value -> Cmd msg


toBackend : Codec toBackendMsg -> WindowId -> toBackendMsg -> Effect msg
toBackend toWindowC windowId toBackendMsg =
    Desktop.Effect.fromCmd
        (toBackendInternal
            (Codec.encodeToValue
                (toWindowCodec toWindowC)
                ( windowId, toBackendMsg )
            )
        )



---- CREATION


port createWindowInternal : Value -> Cmd msg


create : String -> Options -> Effect msg
create moduleName config =
    Desktop.Effect.fromCmd
        (createWindowInternal
            (Json.Encode.object
                [ ( "options", encodeWindowConfig config )
                , ( "moduleName", Json.Encode.string moduleName )
                ]
            )
        )


encodeWindowConfig : Options -> Value
encodeWindowConfig (Options config) =
    [ ( "width", Maybe.map Json.Encode.int config.width )
    , ( "height", Maybe.map Json.Encode.int config.height )
    , ( "x", Maybe.map (\{ x } -> Json.Encode.int x) config.position )
    , ( "y", Maybe.map (\{ y } -> Json.Encode.int y) config.position )
    , ( "useContentSize", Maybe.map Json.Encode.bool config.useContentSize )
    , ( "center", Maybe.map Json.Encode.bool config.center )
    , ( "minWidth", Maybe.map Json.Encode.int config.minWidth )
    , ( "minHeight", Maybe.map Json.Encode.int config.minHeight )
    , ( "maxWidth", Maybe.map Json.Encode.int config.maxWidth )
    , ( "maxHeight", Maybe.map Json.Encode.int config.maxHeight )
    , ( "resizable", Maybe.map Json.Encode.bool config.resizable )
    , ( "movable", Maybe.map Json.Encode.bool config.movable )
    , ( "minimizable", Maybe.map Json.Encode.bool config.minimizable )
    , ( "cloable", Maybe.map Json.Encode.bool config.cloable )
    , ( "focusable", Maybe.map Json.Encode.bool config.focusable )
    , ( "alwaysOnTop", Maybe.map Json.Encode.bool config.alwaysOnTop )
    , ( "fullscreen", Maybe.map Json.Encode.bool config.fullscreen )
    , ( "funscreenable", Maybe.map Json.Encode.bool config.funscreenable )
    , ( "simpleFullscreen", Maybe.map Json.Encode.bool config.simpleFullscreen )
    , ( "skipTaskbar", Maybe.map Json.Encode.bool config.skipTaskbar )
    , ( "kiosk", Maybe.map Json.Encode.bool config.kiosk )
    , ( "title", Maybe.map Json.Encode.string config.title )
    , ( "icon", Maybe.map Json.Encode.string config.icon )
    , ( "show", Maybe.map Json.Encode.bool config.show )
    , ( "frame", Maybe.map Json.Encode.bool config.frame )
    , ( "parent", Maybe.map Json.Encode.string config.parent )
    , ( "modal", Maybe.map Json.Encode.bool config.modal )
    , ( "webPreferences", Maybe.map encodeWebPreferences config.webPreferences )
    ]
        |> List.filterMap (\( name, value ) -> Maybe.map (\v -> ( name, v )) value)
        |> Json.Encode.object


encodeWebPreferences : WebPreferences -> Value
encodeWebPreferences prefs =
    Json.Encode.object []


type alias OptionsInternal =
    { width : Maybe Int
    , height : Maybe Int
    , position : Maybe { x : Int, y : Int }
    , useContentSize : Maybe Bool
    , center : Maybe Bool
    , minWidth : Maybe Int
    , minHeight : Maybe Int
    , maxWidth : Maybe Int
    , maxHeight : Maybe Int
    , resizable : Maybe Bool
    , movable : Maybe Bool
    , minimizable : Maybe Bool
    , cloable : Maybe Bool
    , focusable : Maybe Bool
    , alwaysOnTop : Maybe Bool
    , fullscreen : Maybe Bool
    , funscreenable : Maybe Bool
    , simpleFullscreen : Maybe Bool
    , skipTaskbar : Maybe Bool
    , kiosk : Maybe Bool
    , title : Maybe String
    , icon : Maybe String
    , show : Maybe Bool
    , frame : Maybe Bool
    , parent : Maybe WindowId
    , modal : Maybe Bool
    , webPreferences : Maybe WebPreferences

    -- More ...
    }


withWidth : Int -> Options -> Options
withWidth width (Options options) =
    Options
        { options | width = Just width }


withHeight : Int -> Options -> Options
withHeight height (Options options) =
    Options
        { options | height = Just height }


withPosition : { x : Int, y : Int } -> Options -> Options
withPosition position (Options options) =
    Options
        { options | position = Just position }


type Options
    = Options OptionsInternal


defaultOptions : Options
defaultOptions =
    Options
        { width = Nothing
        , height = Nothing
        , position = Nothing
        , useContentSize = Nothing
        , center = Nothing
        , minWidth = Nothing
        , minHeight = Nothing
        , maxWidth = Nothing
        , maxHeight = Nothing
        , resizable = Nothing
        , movable = Nothing
        , minimizable = Nothing
        , cloable = Nothing
        , focusable = Nothing
        , alwaysOnTop = Nothing
        , fullscreen = Nothing
        , funscreenable = Nothing
        , simpleFullscreen = Nothing
        , skipTaskbar = Nothing
        , kiosk = Nothing
        , title = Nothing
        , icon = Nothing
        , show = Nothing
        , frame = Nothing
        , parent = Nothing
        , modal = Nothing
        , webPreferences = Nothing
        }


type alias WebPreferences =
    {}
