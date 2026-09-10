module Frontend exposing (main)

import Browser
import Crdt
import Crdt.Doc
import Crdt.Edit
import Crdt.Id
import Desktop
import Desktop.Frontend
import Html
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
            if String.isEmpty newTodo then
                ( model, Cmd.none )

            else
                case Crdt.Edit.append Types.todoDoc.todos newTodo model.todoDoc of
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
          in
          Html.div
            []
            [ case model.hyperswarm of
                Loading ->
                    Html.text "Connecting to the swarm"

                Error err ->
                    Html.text ("Failure with connecting to the swarm: " ++ err)

                Loaded () ->
                    Html.text "Connected"
            , Html.form
                [ Html.Events.onSubmit (SaveNewTodo newTodoValue) ]
                [ Html.label []
                    [ Html.span [] [ Html.text "New todo:" ]
                    , Html.input
                        [ Html.Attributes.value newTodoValue
                        , Html.Events.onInput UserChangedNewTodo
                        ]
                        []
                    ]
                , Html.button
                    [ Html.Attributes.type_ "submit"
                    ]
                    [ Html.text "Save" ]
                ]
            , model.todoDoc
                |> Crdt.Doc.read
                |> Result.map .todos
                |> Result.withDefault []
                |> List.map
                    (\todo ->
                        Html.li []
                            [ Html.text todo ]
                    )
                |> Html.ul []
            ]
        ]
    }
