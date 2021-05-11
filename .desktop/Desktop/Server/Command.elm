module Desktop.Server.Command exposing (CommandStatus(..))

{-| -}


{-| -}
type CommandStatus
    = Complete Int
    | Running (Result String String)
