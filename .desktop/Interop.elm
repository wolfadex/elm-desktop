module Interop exposing (..)

import Error exposing (Error(..))
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Process
import Task exposing (Task)


eval : { msg : String, args : Value } -> Decoder a -> Result Error a
eval { msg, args } decoder =
    Json.Encode.object
        [ ( "__elm_interop_sync"
          , Json.Encode.object
                [ ( "msg", Json.Encode.string msg )
                , ( "args", args )
                ]
          )
        ]
        |> Json.Decode.decodeValue (Json.Decode.field "__elm_interop_sync" (decodeEvalResult decoder))
        |> Result.mapError TypeError
        |> Result.andThen identity


evalAsync : String -> Value -> Decoder a -> Task Error a
evalAsync message args decoder =
    let
        token =
            Json.Encode.object []
    in
    Task.succeed ()
        |> Task.andThen
            (\_ ->
                let
                    _ =
                        Json.Encode.object [ ( "__elm_interop_async", Json.Encode.list identity [ token, Json.Encode.string message, args ] ) ]
                in
                -- 69 108 109 == Elm
                Process.sleep -69108109
            )
        |> Task.andThen
            (\_ ->
                case
                    Json.Encode.object [ ( "token", token ) ]
                        |> Json.Decode.decodeValue (Json.Decode.field "__elm_interop_async" (decodeEvalResult decoder))
                        |> Result.mapError TypeError
                        |> Result.andThen identity
                of
                    Ok result ->
                        Task.succeed result

                    Err error ->
                        Task.fail error
            )


decodeEvalResult : Decoder a -> Decoder (Result Error a)
decodeEvalResult decodeResult =
    Json.Decode.field "tag" Json.Decode.string
        |> Json.Decode.andThen
            (\tag ->
                case tag of
                    "Ok" ->
                        Json.Decode.value
                            |> Json.Decode.andThen
                                (\value ->
                                    Json.Decode.decodeValue (Json.Decode.field "result" decodeResult) value
                                        |> Result.mapError TypeError
                                        |> Json.Decode.succeed
                                )

                    "Error" ->
                        Json.Decode.field "error" decodeRuntimeError
                            |> Json.Decode.map Err

                    _ ->
                        Json.Decode.value
                            |> Json.Decode.andThen
                                (\value ->
                                    Json.Decode.succeed
                                        (Json.Decode.Failure ("`tag` field must be one of Ok/Error, instead found `" ++ tag ++ "`") value
                                            |> TypeError
                                            |> Err
                                        )
                                )
            )


decodeRuntimeError : Decoder Error
decodeRuntimeError =
    Json.Decode.field "message" Json.Decode.string |> Json.Decode.map RuntimeError
