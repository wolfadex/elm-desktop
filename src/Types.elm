module Types exposing (..)


type alias WindowModel =
    { count : Int }


type WindowMsg
    = WinNoOp
    | Increment
    | Decrement
    | IncrementMany
    | DecrementMany


type ToWindow
    = TWNoOp
    | SetCount Int


type alias ServerModel =
    {}


type ServerMsg
    = SerNoOp


type ToServer
    = TSNoOp
    | IncrementBy Int Int
    | DecrementBy Int Int


type alias WindowId =
    Int
