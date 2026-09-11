module Frontend exposing (main)

import Browser
import Crdt
import Crdt.Doc
import Crdt.Edit
import Crdt.Id
import Desktop
import Desktop.Frontend
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode
import Json.Encode
import Types
    exposing
        ( FrontendModel
        , FrontendMsg(..)
        , RemoteData(..)
        , ToBackend(..)
        , ToFrontend(..)
        )


type alias Flags =
    {}


main : Program Flags FrontendModel Desktop.Frontend.Msg
main =
    Desktop.Frontend.application
        { init = init
        , update = update
        , updateFromBackend = updateFromBackend
        , view = view
        , subscriptions = \_ -> Sub.none
        }


init : Flags -> Desktop.FrontendKey -> ( FrontendModel, Cmd FrontendMsg )
init {} key =
    ( { key = key
      , hyperswarm = Loading
      , todoDoc = Crdt.init (Crdt.Id.replica "wolfgang") Types.todoDoc.schema
      }
    , Cmd.none
    )


update : FrontendMsg -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
update msg model =
    case msg of
        UserChangedNewTodo newTodo ->
            case Crdt.Edit.set Types.todoDoc.newTodo newTodo model.todoDoc of
                Err err ->
                    Debug.todo (Debug.toString err)

                Ok todoDoc ->
                    ( { model | todoDoc = todoDoc }
                    , Cmd.none
                    )

        SaveNewTodo newTodo ->
            let
                trimmedNewTodo =
                    String.trim newTodo
            in
            if String.isEmpty trimmedNewTodo then
                ( model, Cmd.none )

            else
                case Crdt.Edit.append Types.todoDoc.todos trimmedNewTodo model.todoDoc of
                    Err err ->
                        Debug.todo (Debug.toString err)

                    Ok todoDocWithUpdatedTodos ->
                        case Crdt.Edit.set Types.todoDoc.newTodo "" todoDocWithUpdatedTodos of
                            Err err ->
                                Debug.todo (Debug.toString err)

                            Ok todoDoc ->
                                ( { model | todoDoc = todoDoc }
                                , Desktop.Frontend.sendToBackend model.key (SaveTodos (Crdt.Doc.encode todoDoc |> Json.Encode.encode 0))
                                )

        RemoveTodo idx ->
            case Crdt.Edit.remove Types.todoDoc.todos idx model.todoDoc of
                Err err ->
                    Debug.todo (Debug.toString err)

                Ok todoDoc ->
                    ( { model | todoDoc = todoDoc }
                    , Desktop.Frontend.sendToBackend model.key (SaveTodos (Crdt.Doc.encode todoDoc |> Json.Encode.encode 0))
                    )


updateFromBackend : ToFrontend -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
updateFromBackend msg model =
    case msg of
        AppReady ->
            ( { model | hyperswarm = Loaded () }, Cmd.none )

        TodosRecieved todosStr ->
            ( case Json.Decode.decodeString Json.Decode.value todosStr of
                Err err ->
                    Debug.todo (Debug.toString err)

                Ok todos ->
                    case Crdt.Doc.decodeInto todos model.todoDoc of
                        Err err ->
                            Debug.todo err

                        Ok todoDoc ->
                            { model | todoDoc = todoDoc }
            , Cmd.none
            )


view : FrontendModel -> Browser.Document FrontendMsg
view model =
    { title = "Elm + Electron + Lamdera wire demo"
    , body =
        [ let
            newTodoValue =
                model.todoDoc
                    |> Crdt.Doc.read
                    |> Result.map .newTodo
                    |> Result.withDefault ""

            todos =
                model.todoDoc
                    |> Crdt.Doc.read
                    |> Result.map .todos
                    |> Result.withDefault []
          in
          -- Html.div
          --   []
          --   [ case model.hyperswarm of
          --       Loading ->
          --           Html.text "Connecting to the swarm"
          --       Error err ->
          --           Html.text ("Failure with connecting to the swarm: " ++ err)
          --       Loaded () ->
          --           Html.text "Connected"
          --   , Html.form
          --       [ Html.Events.onSubmit (SaveNewTodo newTodoValue) ]
          --       [ Html.label []
          --           [ Html.span [] [ Html.text "New todo:" ]
          --           , Html.input
          --               [ Html.Attributes.value newTodoValue
          --               , Html.Events.onInput UserChangedNewTodo
          --               ]
          --               []
          --           ]
          --       , Html.button
          --           [ Html.Attributes.type_ "submit"
          --           ]
          --           [ Html.text "Save" ]
          --       ]
          --   , model.todoDoc
          --       |> Crdt.Doc.read
          --       |> Result.map .todos
          --       |> Result.withDefault []
          --       |> List.map
          --           (\todo ->
          --               Html.li []
          --                   [ Html.text todo ]
          --           )
          --       |> Html.ul []
          --   ]
          Html.div [ Html.Attributes.class "todo-app" ]
            [ -- statusBar model.syncStatus
              case model.hyperswarm of
                Loading ->
                    Html.text "Connecting to the swarm"

                Error err ->
                    Html.text ("Failure with connecting to the swarm: " ++ err)

                Loaded () ->
                    Html.text "Connected"
            , Html.div []
                [ newTodoForm newTodoValue
                , todoList todos
                ]
            ]
        ]
    }



-- statusBar : SyncStatus -> Html Msg
-- statusBar syncStatus =
--     case syncStatus of
--         Idle ->
--             Html.text ""
--         Saving ->
--             Html.div [ Html.Attributes.class "status status-saving" ] [ Html.text "Saving…" ]
--         ReceivingRemoteChanges ->
--             Html.div [ Html.Attributes.class "status status-syncing" ]
--                 [ Html.text "Updating from another device…" ]
--         SyncFailed err ->
--             Html.div [ Html.Attributes.class "status status-error" ]
--                 [ Html.text ("Couldn't save: " ++ err) ]


newTodoForm : String -> Html FrontendMsg
newTodoForm newTodoValue =
    Html.form
        [ Html.Events.onSubmit (SaveNewTodo newTodoValue)
        , Html.Attributes.class "new-todo-form"
        ]
        [ Html.input
            [ Html.Attributes.value newTodoValue
            , Html.Events.onInput UserChangedNewTodo
            , Html.Attributes.placeholder "What needs doing?"
            ]
            []
        , Html.button
            [ Html.Attributes.type_ "submit"
            , Html.Attributes.disabled (String.trim newTodoValue == "")
            ]
            [ Html.text "Add" ]
        ]


todoList : List String -> Html FrontendMsg
todoList todos =
    if List.isEmpty todos then
        Html.div [ Html.Attributes.class "empty-state" ]
            [ Html.text "Nothing to do yet." ]

    else
        Html.ul [ Html.Attributes.class "todo-list" ]
            (List.indexedMap todoItem todos)


todoItem : Int -> String -> Html FrontendMsg
todoItem idx todo =
    Html.li [ Html.Attributes.class "todo-item" ]
        [ Html.span [ Html.Attributes.class "todo-text" ]
            [ Html.text todo ]
        , Html.button
            [ Html.Attributes.type_ "button"
            , Html.Events.onClick (RemoveTodo idx)
            , Html.Attributes.class "remove-button"
            ]
            [ Html.text "×" ]
        ]
