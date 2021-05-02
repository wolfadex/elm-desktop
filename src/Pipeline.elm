module Pipeline exposing (main)

import Desktop exposing (DesktopApp)
import Desktop.Effect as Effect exposing (Effect)
import Desktop.Window as Window exposing (Window)
import Dict exposing (Dict)


main : DesktopApp () Model Msg
main =
    Desktop.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { windows : Dict Id Window }


type alias Id = Int


init : () -> ( Model, Effect Msg )
init () =
    ( { windows = Dict.empty}
      -- , Effect.runCommand
      --     { command = "api-pipeline"
      --     , arguments = [ "-environment", "production", "generate", "oas" ]
      --     , stderr = StdErr
      --     , stdout = StdOut
      --     , done = Done
      --     }
    , Effect.openWindow
        { title = "Carl Window!"
        , width = 800
        , height = 600
        , onOpen = WindowOpened 0
        }
    )


type Msg
    = NoOp
    | StdErr String
    | StdOut String
    | Done Int
    | WindowOpened Int Window


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )

        Done _ ->
            ( model, Effect.none )

        StdOut stdout ->
            ( model, Effect.printLn stdout )

        StdErr stderr ->
            let
                _ =
                    Debug.log "stderr" stderr
            in
            ( model, Effect.none )

        WindowOpened id window ->
            ( { model | windows = Dict.insert id window model.windows }
            , Effect.none
            )
