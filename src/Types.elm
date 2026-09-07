module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , FrontendModel
    , FrontendMsg(..)
    , ToBackend(..)
    , ToFrontend(..)
    )

{-| Framework.Frontend / Framework.Backend assume this module, under this
exact name, exposing exactly these six things. `ToBackend` and
`ToFrontend` are the only types that need to cross the wire - the
lamdera compiler generates `w3_encode_ToBackend`, `w3_decode_ToBackend`,
`w3_encode_ToFrontend` and `w3_decode_ToFrontend` right into this module
for you; the framework calls them directly (as `Types.w3_encode_ToBackend`
etc.) so nothing about them needs to appear here.
-}

import Jukai


{-| Frontend -> Backend.
-}
type ToBackend
    = Ping


{-| Backend -> Frontend.
-}
type ToFrontend
    = Pong



-- FRONTEND (renderer process)


type alias FrontendModel =
    { status : String
    }


type FrontendMsg
    = UserClickedPing



-- BACKEND (node process)


type alias BackendModel =
    { pingsReceived : Int
    , window : Maybe Jukai.Window
    }


type BackendMsg
    = WindowOpened (Result String Jukai.Window)
