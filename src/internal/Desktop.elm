module Desktop exposing
    ( Window
    , openWindow
    )

{-| Top-level API a Desktop _user_ reaches for. Everything else lives
under `Desktop.*` and is either re-exported here or used by
`Desktop.Frontend` / `Desktop.Backend` internally.
-}

import Desktop.Internal
import Http
import Json.Decode
import Json.Encode


type alias Window =
    Desktop.Internal.Window


openWindow : (Result String Window -> msg) -> { width : Int, height : Int } -> Cmd msg
openWindow toMsg options =
    Http.post
        { url = "elm-desktop:open-window"
        , body =
            Json.Encode.object
                [ ( "width", Json.Encode.int options.width )
                , ( "value", Json.Encode.int options.height )
                ]
                |> Http.jsonBody
        , expect =
            Http.expectJson
                (\res ->
                    Result.mapError Debug.toString res
                        |> toMsg
                )
                (Json.Decode.map Desktop.Internal.Window Json.Decode.int)
        }
