module Jukai exposing
    ( Window
    , openWindow
    )

{-| Top-level API a Jukai _user_ reaches for. Everything else lives
under `Jukai.*` and is either re-exported here or used by
`Jukai.Frontend` / `Jukai.Backend` internally.
-}

import Http
import Json.Decode
import Json.Encode
import Jukai.Internal


type alias Window =
    Jukai.Internal.Window


openWindow : (Result String Window -> msg) -> { width : Int, height : Int } -> Cmd msg
openWindow toMsg options =
    Http.post
        { url = "jukai:open-window"
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
                (Json.Decode.map Jukai.Internal.Window Json.Decode.int)
        }
