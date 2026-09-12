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
import QRCode
import Types
    exposing
        ( DeviceName(..)
        , FrontendModel(..)
        , FrontendMsg(..)
        , NetworkState(..)
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
    ( InitializingFrontend
        { key = key
        , deviceName = LocatingName
        , network = FindingSecret
        }
    , Cmd.none
    )


update : FrontendMsg -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
update msg model =
    case model of
        InitializingFrontend mod ->
            case msg of
                DeviceNameChanged name ->
                    case mod.deviceName of
                        LocatingName ->
                            ( model, Cmd.none )

                        NeedsName _ ->
                            ( InitializingFrontend { mod | deviceName = NeedsName name }, Cmd.none )

                        SettingName _ ->
                            ( model, Cmd.none )

                        HasName _ ->
                            ( model, Cmd.none )

                DeviceNameSubmitted name ->
                    case mod.deviceName of
                        LocatingName ->
                            ( model, Cmd.none )

                        NeedsName _ ->
                            let
                                trimmedDeviceName =
                                    String.trim name
                            in
                            if String.isEmpty trimmedDeviceName then
                                ( model, Cmd.none )

                            else
                                ( InitializingFrontend { mod | deviceName = SettingName trimmedDeviceName }
                                , Desktop.Frontend.sendToBackend mod.key (SetDeviceName trimmedDeviceName)
                                )

                        SettingName _ ->
                            ( model, Cmd.none )

                        HasName _ ->
                            ( model, Cmd.none )

                UserChangedNewTodo newTodo ->
                    case mod.deviceName of
                        LocatingName ->
                            ( model, Cmd.none )

                        NeedsName _ ->
                            ( model, Cmd.none )

                        SettingName _ ->
                            ( model, Cmd.none )

                        HasName todoDoc ->
                            case Crdt.Edit.set Types.todoDoc.newTodo newTodo todoDoc of
                                Err err ->
                                    Debug.todo (Debug.toString err)

                                Ok newTodoDoc ->
                                    ( InitializingFrontend { mod | deviceName = HasName newTodoDoc }
                                    , Cmd.none
                                    )

                SaveNewTodo newTodo ->
                    case mod.deviceName of
                        LocatingName ->
                            ( model, Cmd.none )

                        NeedsName _ ->
                            ( model, Cmd.none )

                        SettingName _ ->
                            ( model, Cmd.none )

                        HasName todoDoc ->
                            let
                                trimmedNewTodo =
                                    String.trim newTodo
                            in
                            if String.isEmpty trimmedNewTodo then
                                ( model, Cmd.none )

                            else
                                case Crdt.Edit.append Types.todoDoc.todos trimmedNewTodo todoDoc of
                                    Err err ->
                                        Debug.todo (Debug.toString err)

                                    Ok todoDocWithUpdatedTodos ->
                                        case Crdt.Edit.set Types.todoDoc.newTodo "" todoDocWithUpdatedTodos of
                                            Err err ->
                                                Debug.todo (Debug.toString err)

                                            Ok newTodoDoc ->
                                                ( InitializingFrontend { mod | deviceName = HasName newTodoDoc }
                                                , Desktop.Frontend.sendToBackend mod.key (SaveTodos (Crdt.Doc.encode newTodoDoc |> Json.Encode.encode 0))
                                                )

                RemoveTodo idx ->
                    case mod.deviceName of
                        LocatingName ->
                            ( model, Cmd.none )

                        NeedsName _ ->
                            ( model, Cmd.none )

                        SettingName _ ->
                            ( model, Cmd.none )

                        HasName todoDoc ->
                            case Crdt.Edit.remove Types.todoDoc.todos idx todoDoc of
                                Err err ->
                                    Debug.todo (Debug.toString err)

                                Ok newTodoDoc ->
                                    ( InitializingFrontend { mod | deviceName = HasName newTodoDoc }
                                    , Desktop.Frontend.sendToBackend mod.key (SaveTodos (Crdt.Doc.encode newTodoDoc |> Json.Encode.encode 0))
                                    )

                MakeThisDeviceTheFirstDevice ->
                    case mod.network of
                        CreatingSecret secret ->
                            ( InitializingFrontend { mod | network = JoiningNetwork secret }
                            , Desktop.Frontend.sendToBackend mod.key UserWantToCreateNetwork
                            )

                        _ ->
                            ( model, Cmd.none )

                UserSetDeviceSecret secret ->
                    case mod.network of
                        CreatingSecret _ ->
                            ( InitializingFrontend { mod | network = CreatingSecret secret }
                            , Cmd.none
                            )

                        _ ->
                            ( model, Cmd.none )

                UserSubmitDeviceSecret secret ->
                    case mod.network of
                        CreatingSecret _ ->
                            ( InitializingFrontend { mod | network = JoiningSecret secret }
                            , Desktop.Frontend.sendToBackend mod.key (UserWantsToJoinNetwork secret)
                            )

                        _ ->
                            ( model, Cmd.none )

                CopyToClipboard str ->
                    ( model, Desktop.clipboardWriteText str )

        InitializedFrontend mod ->
            case msg of
                CopyToClipboard str ->
                    ( model, Desktop.clipboardWriteText str )

                MakeThisDeviceTheFirstDevice ->
                    ( model, Cmd.none )

                UserSetDeviceSecret _ ->
                    ( model, Cmd.none )

                UserSubmitDeviceSecret _ ->
                    ( model, Cmd.none )

                DeviceNameChanged _ ->
                    ( model, Cmd.none )

                DeviceNameSubmitted _ ->
                    ( model, Cmd.none )

                UserChangedNewTodo newTodo ->
                    case Crdt.Edit.set Types.todoDoc.newTodo newTodo mod.todoDoc of
                        Err err ->
                            Debug.todo (Debug.toString err)

                        Ok todoDoc ->
                            ( InitializedFrontend { mod | todoDoc = todoDoc }
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
                        case Crdt.Edit.append Types.todoDoc.todos trimmedNewTodo mod.todoDoc of
                            Err err ->
                                Debug.todo (Debug.toString err)

                            Ok todoDocWithUpdatedTodos ->
                                case Crdt.Edit.set Types.todoDoc.newTodo "" todoDocWithUpdatedTodos of
                                    Err err ->
                                        Debug.todo (Debug.toString err)

                                    Ok todoDoc ->
                                        ( InitializedFrontend { mod | todoDoc = todoDoc }
                                        , Desktop.Frontend.sendToBackend mod.key (SaveTodos (Crdt.Doc.encode todoDoc |> Json.Encode.encode 0))
                                        )

                RemoveTodo idx ->
                    case Crdt.Edit.remove Types.todoDoc.todos idx mod.todoDoc of
                        Err err ->
                            Debug.todo (Debug.toString err)

                        Ok todoDoc ->
                            ( InitializedFrontend { mod | todoDoc = todoDoc }
                            , Desktop.Frontend.sendToBackend mod.key (SaveTodos (Crdt.Doc.encode todoDoc |> Json.Encode.encode 0))
                            )


updateFromBackend : ToFrontend -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
updateFromBackend msg model =
    case model of
        InitializingFrontend mod ->
            case msg of
                DeviceNameUnset ->
                    ( InitializingFrontend { mod | deviceName = NeedsName "" }, Cmd.none )

                DeviceNameSet deviceName ->
                    ( InitializingFrontend
                        { mod
                            | deviceName =
                                HasName (Crdt.init (Crdt.Id.replica deviceName) Types.todoDoc.schema)
                        }
                    , Cmd.none
                    )

                InitializingSwarm secret ->
                    ( InitializingFrontend { mod | network = JoiningNetwork secret }, Cmd.none )

                PickCreateOrJoin ->
                    ( InitializingFrontend { mod | network = CreatingSecret "" }, Cmd.none )

                NetworkJoined secret ->
                    case mod.network of
                        JoiningNetwork _ ->
                            case mod.deviceName of
                                HasName todoDoc ->
                                    ( InitializedFrontend { key = mod.key, todoDoc = todoDoc, secret = secret }, Cmd.none )

                                _ ->
                                    ( InitializingFrontend { mod | network = JoinedNetwork secret }, Cmd.none )

                        JoinError _ _ ->
                            case mod.deviceName of
                                HasName todoDoc ->
                                    ( InitializedFrontend { key = mod.key, todoDoc = todoDoc, secret = secret }, Cmd.none )

                                _ ->
                                    ( InitializingFrontend { mod | network = JoinedNetwork secret }, Cmd.none )

                        FindingSecret ->
                            ( InitializingFrontend { mod | network = JoinedNetwork secret }, Cmd.none )

                        CreatingSecret _ ->
                            ( InitializingFrontend { mod | network = JoinedNetwork secret }, Cmd.none )

                        JoiningSecret _ ->
                            ( InitializingFrontend { mod | network = JoinedNetwork secret }, Cmd.none )

                        JoinedNetwork _ ->
                            ( InitializingFrontend { mod | network = JoinedNetwork secret }, Cmd.none )

                TodosRecieved todosStr ->
                    case Json.Decode.decodeString Json.Decode.value todosStr of
                        Err err ->
                            Debug.todo (Debug.toString err)

                        Ok todos ->
                            case mod.deviceName of
                                HasName todoDoc ->
                                    case Crdt.Doc.decodeInto todos todoDoc of
                                        Err err ->
                                            Debug.todo err

                                        Ok newTodoDoc ->
                                            ( InitializingFrontend { mod | deviceName = HasName newTodoDoc }
                                            , Cmd.none
                                            )

                                _ ->
                                    ( model, Cmd.none )

        InitializedFrontend mod ->
            case msg of
                DeviceNameUnset ->
                    ( model, Cmd.none )

                DeviceNameSet _ ->
                    ( model, Cmd.none )

                PickCreateOrJoin ->
                    ( model, Cmd.none )

                InitializingSwarm _ ->
                    ( model, Cmd.none )

                NetworkJoined secret ->
                    ( InitializedFrontend { mod | secret = secret }, Cmd.none )

                TodosRecieved todosStr ->
                    case Json.Decode.decodeString Json.Decode.value todosStr of
                        Err err ->
                            Debug.todo (Debug.toString err)

                        Ok todos ->
                            case Crdt.Doc.decodeInto todos mod.todoDoc of
                                Err err ->
                                    Debug.todo err

                                Ok todoDoc ->
                                    ( InitializedFrontend { mod | todoDoc = todoDoc }
                                    , Cmd.none
                                    )


view : FrontendModel -> Browser.Document FrontendMsg
view model =
    { title = "Notes"
    , body =
        case model of
            InitializingFrontend mod ->
                case ( mod.deviceName, mod.network ) of
                    ( LocatingName, _ ) ->
                        [ Html.div [ Html.Attributes.class "loading-screen" ]
                            [ Html.div [ Html.Attributes.class "loading-spinner" ] []
                            , Html.div [ Html.Attributes.class "loading-message" ]
                                [ Html.text "Loading" ]
                            ]
                        ]

                    ( SettingName _, _ ) ->
                        [ Html.div [ Html.Attributes.class "loading-screen" ]
                            [ Html.div [ Html.Attributes.class "loading-spinner" ] []
                            , Html.div [ Html.Attributes.class "loading-message" ]
                                [ Html.text "Loading" ]
                            ]
                        ]

                    ( NeedsName deviceName, _ ) ->
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

                    ( HasName todoDoc, network ) ->
                        [ let
                            newTodoValue =
                                todoDoc
                                    |> Crdt.Doc.read
                                    |> Result.map .newTodo
                                    |> Result.withDefault ""

                            todos =
                                todoDoc
                                    |> Crdt.Doc.read
                                    |> Result.map .todos
                                    |> Result.withDefault []
                          in
                          Html.div [ Html.Attributes.class "todo-app" ]
                            [ statusBar network
                            , Html.div []
                                [ newTodoForm newTodoValue
                                , todoList todos
                                ]
                            ]
                        ]

            InitializedFrontend mod ->
                [ let
                    newTodoValue =
                        mod.todoDoc
                            |> Crdt.Doc.read
                            |> Result.map .newTodo
                            |> Result.withDefault ""

                    todos =
                        mod.todoDoc
                            |> Crdt.Doc.read
                            |> Result.map .todos
                            |> Result.withDefault []
                  in
                  Html.div [ Html.Attributes.class "todo-app" ]
                    [ Html.div [ Html.Attributes.class "status status-connected" ]
                        [ Html.text "Connected"
                        , Html.button
                            [ Html.Attributes.class "share-button"
                            , Html.Attributes.type_ "button"
                            , Html.Attributes.attribute "commandfor" "share-dialog"
                            , Html.Attributes.attribute "command" "show-modal"
                            ]
                            [ Html.text "Share" ]
                        ]
                    , Html.div []
                        [ newTodoForm newTodoValue
                        , todoList todos
                        ]
                    ]
                , sharePanel mod.secret
                ]
    }


sharePanel : String -> Html FrontendMsg
sharePanel secretString =
    Html.node "dialog"
        [ Html.Attributes.class "share-panel"
        , Html.Attributes.id "share-dialog"
        ]
        [ Html.button
            [ Html.Attributes.class "dialog-close"
            , Html.Attributes.type_ "button"
            , Html.Attributes.attribute "commandfor" "share-dialog"
            , Html.Attributes.attribute "command" "close"
            ]
            [ Html.text "×" ]
        , Html.div [ Html.Attributes.class "qr-frame" ]
            [ secretString
                |> QRCode.fromString
                |> Result.map
                    (QRCode.toSvg
                        [ Html.Attributes.width 500
                        , Html.Attributes.height 500
                        ]
                    )
                |> Result.withDefault
                    (Html.text "Error creating QR code")
            ]
        , Html.div [ Html.Attributes.class "share-code" ]
            [ Html.text secretString ]
        , Html.button
            [ Html.Attributes.class "copy-button"
            , Html.Attributes.type_ "button"
            , Html.Events.onClick (CopyToClipboard secretString)
            ]
            [ Html.text "Copy" ]
        ]


statusBar : NetworkState -> Html FrontendMsg
statusBar network =
    case network of
        FindingSecret ->
            Html.div
                [ Html.Attributes.class "status status-syncing" ]
                [ Html.text "Initializing…"
                , Html.div [ Html.Attributes.class "loading-spinner" ] []
                ]

        JoiningSecret _ ->
            Html.div
                [ Html.Attributes.class "status status-syncing" ]
                [ Html.text "Joining…"
                , Html.div [ Html.Attributes.class "loading-spinner" ] []
                ]

        JoiningNetwork _ ->
            Html.div
                [ Html.Attributes.class "status status-syncing" ]
                [ Html.text "Connecting…"
                , Html.div [ Html.Attributes.class "loading-spinner" ] []
                ]

        JoinedNetwork _ ->
            Html.div [ Html.Attributes.class "status status-connected" ]
                [ Html.text "Connected"
                , Html.button
                    [ Html.Attributes.class "share-button"
                    , Html.Attributes.type_ "button"
                    , Html.Attributes.attribute "commandfor" "share-dialog"
                    , Html.Attributes.attribute "command" "show-modal"
                    ]
                    [ Html.text "Share" ]
                ]

        JoinError _ err ->
            Html.div [ Html.Attributes.class "status status-error" ]
                [ Html.text ("Offline: " ++ err) ]

        CreatingSecret secret ->
            Html.div
                [ Html.Attributes.class "status status-syncing" ]
                [ Html.button
                    [ Html.Attributes.class "device-choice-button"
                    , Html.Attributes.type_ "button"
                    , Html.Events.onClick MakeThisDeviceTheFirstDevice
                    ]
                    [ Html.text "This is my first device" ]
                , Html.button
                    [ Html.Attributes.class "device-choice-button"
                    , Html.Attributes.type_ "button"
                    , Html.Attributes.attribute "command" "show-modal"
                    , Html.Attributes.attribute "commandfor" "connect-device-dialog"

                    -- fallback for browsers without Invoker Commands support;
                    -- harmless no-op on browsers that already opened it declaratively
                    ]
                    [ Html.text "Connect to another device" ]
                , connectDeviceDialog secret
                ]


connectDeviceDialog : String -> Html FrontendMsg
connectDeviceDialog secret =
    Html.node "dialog"
        [ Html.Attributes.class "connect-dialog"
        , Html.Attributes.id "connect-device-dialog"
        ]
        [ Html.button
            [ Html.Attributes.class "dialog-close"
            , Html.Attributes.type_ "button"
            , Html.Attributes.attribute "command" "close"
            , Html.Attributes.attribute "commandfor" "connect-device-dialog"
            ]
            [ Html.text "×" ]
        , Html.div [ Html.Attributes.class "camera-frame" ]
            [ Html.text "Camera preview coming soon" ]
        , Html.div [ Html.Attributes.class "dialog-divider" ]
            [ Html.span [] [ Html.text "or paste a code" ] ]
        , Html.input
            [ Html.Attributes.class "paste-code-input"
            , Html.Attributes.type_ "text"
            , Html.Attributes.value secret
            , Html.Attributes.placeholder "Paste connection code"
            , Html.Events.onInput UserSetDeviceSecret
            ]
            []
        , Html.button
            [ Html.Attributes.class "copy-button"
            , Html.Attributes.type_ "button"
            , Html.Events.onClick (UserSubmitDeviceSecret secret)
            ]
            [ Html.text "Connect" ]
        ]


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
