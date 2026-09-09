module Frontend exposing (main)

import Browser
import Desktop
import Desktop.Frontend
import Html exposing (button, div, text)
import Html.Events exposing (onClick)
import Types exposing (FrontendModel, FrontendMsg(..), ToBackend(..), ToFrontend(..))


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
    ( { status = "idle" }
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
    case msg of
        Pong ->
            ( { model | status = "got pong!" }, Cmd.none )


view : FrontendModel -> Browser.Document FrontendMsg
view model =
    { title = "Elm + Electron + Lamdera wire demo"
    , body =
        [ div []
            [ button [ onClick UserClickedPing ] [ text "Ping" ]
            , div [] [ text ("status: " ++ model.status) ]
            ]
        ]
    }
