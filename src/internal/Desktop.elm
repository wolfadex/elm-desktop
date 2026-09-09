module Desktop exposing
    ( Window
    , WindowOptions, FullScreen(..)
    , openWindow
    , openDebugWindow
    )

{-|

@docs Window
@docs WindowOptions, FullScreen
@docs openWindow
@docs openDebugWindow

-}

import Desktop.Internal
import Http
import Json.Decode
import Json.Encode


type alias Window =
    Desktop.Internal.Window


type alias WindowOptions =
    { width : Int
    , height : Int
    , frame : Bool
    , fullscreen : FullScreen
    , maxWidth : Maybe Int
    , maxHeight : Maybe Int
    , minWidth : Maybe Int
    , minHeight : Maybe Int
    , opacity : Float
    , resizable : Bool
    }


type FullScreen
    = StartFullScreen
    | DisableFullScreen
    | AllowFullscreen


encodeWindowOptions : WindowOptions -> Json.Encode.Value
encodeWindowOptions options =
    [ Just ( "width", Json.Encode.int options.width )
    , Just ( "height", Json.Encode.int options.height )
    , Just ( "frame", Json.Encode.bool options.frame )
    , case options.fullscreen of
        StartFullScreen ->
            Just ( "fullscreen", Json.Encode.bool True )

        DisableFullScreen ->
            Just ( "fullscreen", Json.Encode.bool False )

        AllowFullscreen ->
            Nothing
    , maybeField "maxWidth" Json.Encode.int options.maxWidth
    , maybeField "maxHeight" Json.Encode.int options.maxHeight
    , maybeField "minWidth" Json.Encode.int options.minWidth
    , maybeField "minHeight" Json.Encode.int options.minHeight
    , Just ( "opacity", Json.Encode.float options.opacity )
    , Just ( "resizable", Json.Encode.bool options.resizable )
    ]
        |> List.filterMap identity
        |> Json.Encode.object


maybeField : String -> (a -> Json.Encode.Value) -> Maybe a -> Maybe ( String, Json.Encode.Value )
maybeField label encoder value =
    case value of
        Nothing ->
            Nothing

        Just val ->
            Just ( label, encoder val )


{-|

    Desktop.openWindow
        options

-}
openWindow : (Result String Window -> msg) -> WindowOptions -> Cmd msg
openWindow toMsg options =
    Http.post
        { url = "elm-desktop:open-window"
        , body =
            encodeWindowOptions options
                |> Http.jsonBody
        , expect =
            Http.expectJson
                (\res ->
                    Result.mapError Debug.toString res
                        |> toMsg
                )
                (Json.Decode.map Desktop.Internal.Window Json.Decode.int)
        }


{-| The same as `openWindow` but it opens the dev tools.

    Desktop.openDebugWindow Debug.todo
        options

-}
openDebugWindow : (String -> Never) -> (Result String Window -> msg) -> WindowOptions -> Cmd msg
openDebugWindow _ toMsg options =
    Http.post
        { url = "elm-desktop:open-debug-window"
        , body =
            encodeWindowOptions options
                |> Http.jsonBody
        , expect =
            Http.expectJson
                (\res ->
                    Result.mapError Debug.toString res
                        |> toMsg
                )
                (Json.Decode.map Desktop.Internal.Window Json.Decode.int)
        }
