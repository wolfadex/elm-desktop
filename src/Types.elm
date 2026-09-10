module Types exposing (..)

import Desktop


type ToBackend
    = ToBackendNoOp


type ToFrontend
    = AppReady


type alias FrontendModel =
    { hyperswarm : Swarm
    }


type FrontendMsg
    = FrontendNoOp


type alias BackendModel =
    { window : Maybe Desktop.Window
    , hyperswarm : Swarm
    }


type Swarm
    = Initializing
    | Ready
    | Error String


type BackendMsg
    = WindowOpened (Result String Desktop.Window)
    | SwarmReady ()
    | DataReceived String
