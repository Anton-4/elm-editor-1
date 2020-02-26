module Helper.Sync exposing (sync, syncAndHighlightRenderedText, syncModel)

import Array exposing (Array)
import Cmd.Extra exposing (withCmd)
import Editor exposing (Editor, EditorMsg)
import Markdown.Option exposing (MarkdownOption(..))
import Markdown.Parse
import Render
    exposing
        ( MDData
        , MLData
        , RenderingData(..)
        )
import Sync
import Tree.Diff
import Types exposing (DocType(..), Model, Msg(..))
import View.Scroll


sync : Editor -> Cmd EditorMsg -> Model -> ( Model, Cmd Msg )
sync newEditor cmd model =
    model
        |> updateRenderingData (Editor.getLines newEditor)
        |> (\m -> { m | editor = newEditor })
        |> withCmd (Cmd.map EditorMsg cmd)


syncModel : Editor -> Model -> Model
syncModel newEditor model =
    model
        |> updateRenderingData (Editor.getLines newEditor)
        |> (\m -> { m | editor = newEditor })


syncAndHighlightRenderedText : String -> Cmd Msg -> Model -> ( Model, Cmd Msg )
syncAndHighlightRenderedText str cmd model =
    case ( model.docType, model.renderingData ) of
        ( MarkdownDoc, MD data ) ->
            syncAndHighlightRenderedMarkdownText str cmd model data

        ( MiniLaTeXDoc, ML data ) ->
            syncAndHighlightRenderedMiniLaTeXText str cmd model data

        _ ->
            ( model, Cmd.none )


syncAndHighlightRenderedMarkdownText : String -> Cmd Msg -> Model -> MDData -> ( Model, Cmd Msg )
syncAndHighlightRenderedMarkdownText str cmd model data =
    let
        str2 =
            Markdown.Parse.toMDBlockTree 0 ExtendedMath str
                |> Markdown.Parse.getLeadingTextFromAST

        id_ =
            Sync.getId str2 data.sourceMap
                |> Maybe.withDefault "0v0"
    in
    ( { model | selectedId_ = id_ }
    , Cmd.batch [ cmd, View.Scroll.setViewportForElementInRenderedText id_ ]
    )


syncAndHighlightRenderedMiniLaTeXText : String -> Cmd Msg -> Model -> MLData -> ( Model, Cmd Msg )
syncAndHighlightRenderedMiniLaTeXText str cmd model data =
    let
        id =
            Sync.getId str data.editRecord.sourceMap
                |> Maybe.withDefault "0v0"
    in
    ( model
    , Cmd.batch [ cmd, View.Scroll.setViewportForElementInRenderedText id ]
    )


processMarkdownContentForHighlighting : String -> MDData -> Model -> Model
processMarkdownContentForHighlighting str data model =
    let
        newAst_ =
            Markdown.Parse.toMDBlockTree model.counter ExtendedMath str

        newAst =
            Tree.Diff.mergeWith Markdown.Parse.equalIds data.fullAst newAst_
    in
    { model
        | counter = model.counter + 1
    }


updateRenderingData : Array String -> Model -> Model
updateRenderingData lines model =
    let
        source =
            lines |> Array.toList |> String.join "\n"

        counter =
            model.counter + 1

        newRenderingData =
            Render.update ( 0, 0 ) counter source model.renderingData
    in
    { model | renderingData = newRenderingData, counter = counter }
