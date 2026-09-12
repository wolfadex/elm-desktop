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
        , FrontendState(..)
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
      , state = WaitingForDeviceName
      }
    , Cmd.none
    )


update : FrontendMsg -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
update msg model =
    case model.state of
        WaitingForDeviceName ->
            ( model, Cmd.none )

        NeedsDeviceName _ ->
            case msg of
                DeviceNameChanged deviceName ->
                    ( { model
                        | state = NeedsDeviceName deviceName
                      }
                    , Cmd.none
                    )

                DeviceNameSubmitted deviceName ->
                    let
                        trimmedDeviceName =
                            String.trim deviceName
                    in
                    if String.isEmpty trimmedDeviceName then
                        ( model, Cmd.none )

                    else
                        ( { model | state = SavingDeviceName deviceName }
                        , Desktop.Frontend.sendToBackend model.key (SetDeviceName trimmedDeviceName)
                        )

                _ ->
                    ( model, Cmd.none )

        SavingDeviceName _ ->
            ( model, Cmd.none )

        ReadyForTodos ready ->
            case msg of
                DeviceNameChanged _ ->
                    ( model, Cmd.none )

                DeviceNameSubmitted _ ->
                    ( model, Cmd.none )

                UserChangedNewTodo newTodo ->
                    case Crdt.Edit.set Types.todoDoc.newTodo newTodo ready.todoDoc of
                        Err err ->
                            Debug.todo (Debug.toString err)

                        Ok todoDoc ->
                            ( { model | state = ReadyForTodos { ready | todoDoc = todoDoc } }
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
                        case Crdt.Edit.append Types.todoDoc.todos trimmedNewTodo ready.todoDoc of
                            Err err ->
                                Debug.todo (Debug.toString err)

                            Ok todoDocWithUpdatedTodos ->
                                case Crdt.Edit.set Types.todoDoc.newTodo "" todoDocWithUpdatedTodos of
                                    Err err ->
                                        Debug.todo (Debug.toString err)

                                    Ok todoDoc ->
                                        ( { model | state = ReadyForTodos { ready | todoDoc = todoDoc } }
                                        , Desktop.Frontend.sendToBackend model.key (SaveTodos (Crdt.Doc.encode todoDoc |> Json.Encode.encode 0))
                                        )

                RemoveTodo idx ->
                    case Crdt.Edit.remove Types.todoDoc.todos idx ready.todoDoc of
                        Err err ->
                            Debug.todo (Debug.toString err)

                        Ok todoDoc ->
                            ( { model | state = ReadyForTodos { ready | todoDoc = todoDoc } }
                            , Desktop.Frontend.sendToBackend model.key (SaveTodos (Crdt.Doc.encode todoDoc |> Json.Encode.encode 0))
                            )


updateFromBackend : ToFrontend -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
updateFromBackend msg model =
    case model.state of
        WaitingForDeviceName ->
            case msg of
                DeviceNameUnset ->
                    ( { model | state = NeedsDeviceName "" }, Cmd.none )

                DeviceNameSet deviceName ->
                    ( { model
                        | state =
                            ReadyForTodos
                                { hyperswarm = Loading
                                , todoDoc = Crdt.init (Crdt.Id.replica deviceName) Types.todoDoc.schema
                                }
                      }
                    , Cmd.none
                    )

                _ ->
                    Debug.todo (Debug.toString msg)

        NeedsDeviceName _ ->
            case msg of
                DeviceNameSet deviceName ->
                    ( { model
                        | state =
                            ReadyForTodos
                                { hyperswarm = Loading
                                , todoDoc = Crdt.init (Crdt.Id.replica deviceName) Types.todoDoc.schema
                                }
                      }
                    , Cmd.none
                    )

                _ ->
                    Debug.todo (Debug.toString msg)

        SavingDeviceName _ ->
            case msg of
                DeviceNameSet deviceName ->
                    ( { model
                        | state =
                            ReadyForTodos
                                { hyperswarm = Loading
                                , todoDoc = Crdt.init (Crdt.Id.replica deviceName) Types.todoDoc.schema
                                }
                      }
                    , Cmd.none
                    )

                _ ->
                    Debug.todo (Debug.toString msg)

        ReadyForTodos ready ->
            case msg of
                AppReady ->
                    ( { model | state = ReadyForTodos { ready | hyperswarm = Loaded () } }, Cmd.none )

                TodosRecieved todosStr ->
                    ( case Json.Decode.decodeString Json.Decode.value todosStr of
                        Err err ->
                            Debug.todo (Debug.toString err)

                        Ok todos ->
                            case Crdt.Doc.decodeInto todos ready.todoDoc of
                                Err err ->
                                    Debug.todo err

                                Ok todoDoc ->
                                    { model | state = ReadyForTodos { ready | todoDoc = todoDoc } }
                    , Cmd.none
                    )

                DeviceNameUnset ->
                    Debug.todo "DeviceNameUnset"

                DeviceNameSet deviceName ->
                    ( { model
                        | state =
                            ReadyForTodos
                                { hyperswarm = Loading
                                , todoDoc =
                                    Crdt.Doc.merge
                                        ready.todoDoc
                                        (Crdt.init (Crdt.Id.replica deviceName) Types.todoDoc.schema)
                                }
                      }
                    , Cmd.none
                    )


view : FrontendModel -> Browser.Document FrontendMsg
view model =
    { title = "Elm + Electron + Lamdera wire demo"
    , body =
        case model.state of
            WaitingForDeviceName ->
                [ Html.div [ Html.Attributes.class "loading-screen" ]
                    [ Html.div [ Html.Attributes.class "loading-spinner" ] []
                    , Html.div [ Html.Attributes.class "loading-message" ]
                        [ Html.text "Loading" ]
                    ]
                ]

            NeedsDeviceName deviceName ->
                [ Html.div [ Html.Attributes.class "devicename-screen" ]
                    [ Html.div [ Html.Attributes.class "devicename-card" ]
                        [ Html.h1 [ Html.Attributes.class "devicename-title" ]
                            [ Html.text "Welcome" ]
                        , Html.p [ Html.Attributes.class "devicename-subtitle" ]
                            [ Html.text "Choose a devicename to get started." ]
                        , Html.form
                            [ Html.Events.onSubmit (DeviceNameSubmitted deviceName)
                            , Html.Attributes.class "devicename-form"
                            ]
                            [ Html.input
                                [ Html.Attributes.value deviceName
                                , Html.Events.onInput DeviceNameChanged
                                , Html.Attributes.placeholder "Device name"
                                ]
                                []
                            , Html.button
                                [ Html.Attributes.type_ "submit"
                                , Html.Attributes.disabled (String.trim deviceName == "")
                                ]
                                [ Html.text "Continue" ]
                            ]
                        ]
                    ]
                ]

            SavingDeviceName deviceName ->
                [ Html.div [ Html.Attributes.class "devicename-screen" ]
                    [ Html.div [ Html.Attributes.class "devicename-card" ]
                        [ Html.h1 [ Html.Attributes.class "devicename-title" ]
                            [ Html.text "Welcome" ]
                        , Html.p [ Html.Attributes.class "devicename-subtitle" ]
                            [ Html.text "Choose a devicename to get started." ]
                        , Html.form
                            [ Html.Events.onSubmit (DeviceNameSubmitted deviceName)
                            , Html.Attributes.class "devicename-form"
                            ]
                            [ Html.input
                                [ Html.Attributes.value deviceName
                                , Html.Events.onInput DeviceNameChanged
                                , Html.Attributes.placeholder "Device name"
                                ]
                                []
                            , Html.button
                                [ Html.Attributes.type_ "submit"
                                , Html.Attributes.disabled (String.trim deviceName == "")
                                ]
                                [ Html.text "Continue" ]
                            ]
                        ]
                    ]
                ]

            ReadyForTodos ready ->
                [ let
                    newTodoValue =
                        ready.todoDoc
                            |> Crdt.Doc.read
                            |> Result.map .newTodo
                            |> Result.withDefault ""

                    todos =
                        ready.todoDoc
                            |> Crdt.Doc.read
                            |> Result.map .todos
                            |> Result.withDefault []
                  in
                  Html.div [ Html.Attributes.class "todo-app" ]
                    [ statusBar ready.hyperswarm
                    , Html.div []
                        [ newTodoForm newTodoValue
                        , todoList todos
                        ]
                    ]
                ]
    }


statusBar : RemoteData String () -> Html FrontendMsg
statusBar hyperswarm =
    case hyperswarm of
        Loading ->
            Html.div
                [ Html.Attributes.class "status status-syncing" ]
                [ Html.text "Connecting…"
                , Html.div [ Html.Attributes.class "loading-spinner" ] []
                ]

        Loaded () ->
            Html.div [ Html.Attributes.class "status status-saving" ]
                [ Html.text "Connected" ]

        Error err ->
            Html.div [ Html.Attributes.class "status status-error" ]
                [ Html.text ("Offline: " ++ err) ]


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
