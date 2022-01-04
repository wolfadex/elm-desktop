port module Desktop exposing
    ( DesktopApp
    , app
    , Options
    , create
    , defaultOptions
    , withWidth
    , withHeight
    , withPosition
    , save
    )

{-|


# Program

@docs DesktopApp
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
import Desktop.Effect as Effect exposing (Effect)
import Json.Encode exposing (Value)


type alias DesktopApp model msg =
    { init : ( model, Effect msg )
    , persist :
        Maybe
            { codec : Codec model
            , onLoad :
                { currentModel : model
                , savedModel : Result Codec.Error model
                }
                -> ( model, Effect msg )
            }
    , update : msg -> model -> ( model, Effect msg )
    , subscriptions : model -> Sub msg
    , view : model -> Browser.Document msg
    , options : Value
    }


app :
    { init : ( model, Effect msg )
    , persist :
        Maybe
            { codec : Codec model
            , onLoad :
                { currentModel : model
                , savedModel : Result Codec.Error model
                }
                -> ( model, Effect msg )
            }
    , update : msg -> model -> ( model, Effect msg )
    , subscriptions : model -> Sub msg
    , view : model -> Browser.Document msg
    , options : Options
    }
    -> DesktopApp model msg
app config =
    { init = config.init
    , persist = config.persist
    , update = config.update
    , subscriptions = config.subscriptions
    , view = config.view
    , options = create config.options
    }


port saveModel : Value -> Cmd msg


save : Value -> Effect msg
save data =
    Effect.fromCmd (saveModel data)



---- CREATION


create : Options -> Value
create config =
    encodeWindowConfig config


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
encodeWebPreferences _ =
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


type alias WindowId =
    String
