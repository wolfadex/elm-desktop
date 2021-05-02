module Desktop.Effect exposing (..)

import Desktop.Window exposing (Window) 

type Effect msg
    = EffNone
    | Effbatch (List (Effect msg))
    | EffCommand (Command msg)
    | EffPrintLn String
    | EffOpenWindow { title : String, width : Int, height : Int, onOpen : Window -> msg }


type alias Command msg =
    { command : String
    , arguments : List String
    , stderr : String -> msg
    , stdout : String -> msg
    , done : Int -> msg
    }


none : Effect msg
none =
    EffNone


batch : List (Effect msg) -> Effect msg
batch =
    Effbatch


runCommand : Command msg -> Effect msg
runCommand =
    EffCommand


printLn : String -> Effect msg
printLn =
    EffPrintLn


openWindow : { title : String, width : Int, height : Int, onOpen : Window -> msg } -> Effect msg
openWindow =
    EffOpenWindow