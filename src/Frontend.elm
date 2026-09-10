module Frontend exposing (main)

import Browser
import Desktop
import Desktop.Frontend
import Html
import Html.Events
import Types exposing (..)


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


init : Flags -> ( FrontendModel, Cmd FrontendMsg )
init {} =
    ( { status = "idle"
      , hyperswarm = Initializing
      }
    , Cmd.none
    )


update : FrontendMsg -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
update msg model =
    case msg of
        UserClickedPing ->
            ( { model | status = "waiting for pong..." }
            , Desktop.Frontend.sendToBackend Ping
            )


updateFromBackend : ToFrontend -> FrontendModel -> ( FrontendModel, Cmd FrontendMsg )
updateFromBackend msg model =
    case Debug.log "ToFrontend" msg of
        Pong ->
            ( { model | status = "got pong!" }, Cmd.none )

        AppReady ->
            ( { model | hyperswarm = Ready }, Cmd.none )


view : FrontendModel -> Browser.Document FrontendMsg
view model =
    { title = "Elm + Electron + Lamdera wire demo"
    , body =
        [ Html.div []
            [ Html.button [ Html.Events.onClick UserClickedPing ] [ Html.text "Ping" ]
            , Html.div [] [ Html.text ("status: " ++ model.status) ]
            ]
        , case model.hyperswarm of
            Initializing ->
                Html.text "Connecting to the swarm"

            Error err ->
                Html.text ("Failure with connecting to the swarm: " ++ err)

            Ready ->
                Html.text "Connected"
        ]
    }
