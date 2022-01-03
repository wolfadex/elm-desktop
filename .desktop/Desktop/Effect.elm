module Desktop.Effect exposing
    ( Effect
    , none
    , map
    , batch
    , fromCmd
    , toCmd
    )

{-|

@docs Effect
@docs none
@docs map
@docs batch
@docs fromCmd
@docs toCmd

-}


type Effect msg
    = None
    | Cmd (Cmd msg)
    | Batch (List (Effect msg))


none : Effect msg
none =
    None


map : (a -> b) -> Effect a -> Effect b
map fn effect =
    case effect of
        None ->
            None

        Cmd cmd ->
            Cmd (Cmd.map fn cmd)

        Batch list ->
            Batch (List.map (map fn) list)


fromCmd : Cmd msg -> Effect msg
fromCmd =
    Cmd


batch : List (Effect msg) -> Effect msg
batch =
    Batch



-- Used by Main.elm


toCmd : (serverMsg -> msg) -> Effect serverMsg -> Cmd msg
toCmd serverMsg effect =
    case effect of
        None ->
            Cmd.none

        Cmd cmd ->
            Cmd.map serverMsg cmd

        Batch list ->
            Cmd.batch (List.map (toCmd serverMsg) list)
