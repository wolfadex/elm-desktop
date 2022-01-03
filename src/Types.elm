module Types exposing (..)

import Codec exposing (Codec)


type ToWindowMsg
    = TWNoOp
    | SetCount Int


toWindowMsgCodec : Codec ToWindowMsg
toWindowMsgCodec =
    Codec.custom
        (\fNoOp fSetCount value ->
            case value of
                TWNoOp ->
                    fNoOp

                SetCount i ->
                    fSetCount i
        )
        |> Codec.variant0 "TWNoOp" TWNoOp
        |> Codec.variant1 "SetCount" SetCount Codec.int
        |> Codec.buildCustom


type ToBackendMsg
    = TBNoOp
    | IncrementBy Int Int
    | DecrementBy Int Int


toBackendMsgCodec : Codec ToBackendMsg
toBackendMsgCodec =
    Codec.custom
        (\fTBNoOp fIncrementBy fDecrementBy value ->
            case value of
                TBNoOp ->
                    fTBNoOp

                IncrementBy a b ->
                    fIncrementBy a b

                DecrementBy a b ->
                    fDecrementBy a b
        )
        |> Codec.variant0 "TBNoOp" TBNoOp
        |> Codec.variant2 "IncrementBy" IncrementBy Codec.int Codec.int
        |> Codec.variant2 "DecrementBy" DecrementBy Codec.int Codec.int
        |> Codec.buildCustom


type alias WindowId =
    String
