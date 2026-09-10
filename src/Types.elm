module Types exposing (..)

import Desktop


type ToBackend
    = Ping


type ToFrontend
    = Pong
    | AppReady


type alias FrontendModel =
    { status : String
    , hyperswarm : Swarm
    }


type FrontendMsg
    = UserClickedPing


type alias BackendModel =
    { pingsReceived : Int
    , window : Maybe Desktop.Window
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
