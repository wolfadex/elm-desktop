module Types exposing (..)

import Crdt
import Crdt.Doc
import Desktop
import Json.Encode


type ToBackend
    = SaveTodos String


type ToFrontend
    = AppReady
    | TodosRecieved String


type alias FrontendModel =
    { key : Desktop.FrontendKey
    , hyperswarm : RemoteData String ()
    , todoDoc : Crdt.Doc.Doc Todo
    }


type alias Todo =
    { newTodo : String
    , todos : List String
    }


type alias TodoDoc =
    { newTodo : Crdt.Ref Todo Crdt.Settable String
    , todos : Crdt.Ref Todo (Crdt.ListK Crdt.Fixed Crdt.Settable String) (List String)
    , schema : Crdt.Schema Crdt.Nested Todo
    }


todoDoc : TodoDoc
todoDoc =
    Crdt.record Todo TodoDoc
        |> Crdt.field "newTodo" .newTodo Crdt.text
        |> Crdt.field "todos" .todos (Crdt.list Crdt.text)
        |> Crdt.build


type TodoStatus
    = NeedsDoing
    | Complete


type FrontendMsg
    = UserChangedNewTodo String
    | SaveNewTodo String


type alias BackendModel =
    { key : Desktop.BackendKey
    , window : Maybe Desktop.Window
    , hyperswarm : RemoteData String ()
    , savedTodos : Maybe String
    }


type RemoteData e a
    = Loading
    | Loaded a
    | Error e


type BackendMsg
    = WindowOpened (Result String Desktop.Window)
    | SwarmReady ()
    | DataReceived String
    | TodosSaved (Result String ())
    | TodosLoaded (Result String String)
