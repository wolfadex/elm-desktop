module Internal.Effect exposing (..)

import Desktop.Window exposing (Window, WindowProgram)


type EffectInternal msg
    = EffNone
    | Effbatch (List (EffectInternal msg))
    | EffCommand (Command msg)
    | EffPrintLn String
    | EffOpenWindow
        { title : String
        , width : Int
        , height : Int
        , onOpen : Result String Window -> msg
        , runtime : WindowProgram model msg
        }


type alias Command msg =
    { command : String
    , arguments : List String
    , stderr : String -> msg
    , stdout : String -> msg
    , done : Int -> msg
    }
