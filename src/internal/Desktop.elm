port module Desktop exposing
    ( BackendKey
    , Window
    , WindowOptions, FullScreen(..)
    , openWindow
    , openDebugWindow
    , saveUserData, loadUserData, FileError(..)
    , FrontendKey
    , clipboardWriteText
    )

{-|


# Backend

@docs BackendKey
@docs Window
@docs WindowOptions, FullScreen
@docs openWindow
@docs openDebugWindow
@docs saveUserData, loadUserData, FileError


# Frontend

@docs FrontendKey


# Both

@docs clipboardWriteText

-}

import Desktop.Internal
import Http
import Json.Decode
import Json.Encode


type alias Window =
    Desktop.Internal.Window


type alias BackendKey =
    Desktop.Internal.BackendKey


type alias FrontendKey =
    Desktop.Internal.FrontendKey


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
openWindow : Desktop.Internal.BackendKey -> (Result String Window -> msg) -> WindowOptions -> Cmd msg
openWindow _ toMsg options =
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
openDebugWindow : (String -> Never) -> Desktop.Internal.BackendKey -> (Result String Window -> msg) -> WindowOptions -> Cmd msg
openDebugWindow _ _ toMsg options =
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


type FileError
    = InternalError
    | PathNameTooLong
    | NoSuchFileOrDirectory
    | UnknownError String


saveUserData : Desktop.Internal.BackendKey -> (Result FileError () -> msg) -> { filename : String, data : String } -> Cmd msg
saveUserData _ toMsg { filename, data } =
    Http.post
        { url = "elm-desktop:save-user-data"
        , body =
            Json.Encode.object
                [ ( "filename", Json.Encode.string filename )
                , ( "data", Json.Encode.string data )
                ]
                |> Http.jsonBody
        , expect =
            Http.expectStringResponse
                toMsg
                (\response ->
                    case response of
                        Http.BadUrl_ _ ->
                            Err InternalError

                        Http.Timeout_ ->
                            Err InternalError

                        Http.NetworkError_ ->
                            Err InternalError

                        Http.BadStatus_ _ body ->
                            case body of
                                "ENOENT" ->
                                    Err NoSuchFileOrDirectory

                                "ENAMETOOLONG" ->
                                    Err PathNameTooLong

                                _ ->
                                    Err (UnknownError body)

                        Http.GoodStatus_ _ _ ->
                            Ok ()
                )
        }


loadUserData : Desktop.Internal.BackendKey -> (Result FileError String -> msg) -> String -> Cmd msg
loadUserData _ toMsg filename =
    Http.post
        { url = "elm-desktop:load-user-data"
        , body =
            Http.jsonBody
                (Json.Encode.string filename)
        , expect =
            Http.expectStringResponse
                toMsg
                (\response ->
                    case response of
                        Http.BadUrl_ _ ->
                            Err InternalError

                        Http.Timeout_ ->
                            Err InternalError

                        Http.NetworkError_ ->
                            Err InternalError

                        Http.BadStatus_ _ body ->
                            case body of
                                "ENOENT" ->
                                    Err NoSuchFileOrDirectory

                                "ENAMETOOLONG" ->
                                    Err PathNameTooLong

                                _ ->
                                    Err (UnknownError body)

                        Http.GoodStatus_ _ body ->
                            Ok body
                )
        }


port clipboardWriteText : String -> Cmd msg
