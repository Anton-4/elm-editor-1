module Update.Document exposing
    ( changeMetaData
    , createDocument
    , readDocumentCmd
    , updateDocument
    , listDocuments
    , loadDocument
    , toggleDocType
    )

import Cmd.Extra exposing (withCmd, withCmds, withNoCmd)
import Document exposing (DocType(..))
import Helper.Common
import Helper.Load
import Helper.Server
import Helper.File
import Helper.Sync
import Outside
import Types exposing (ChangingFileNameState(..)
  , DocumentStatus(..),
  FileLocation(..), Model, Msg, PopupStatus(..))
import View.Scroll

readDocumentCmd fileName model =
    case model.fileLocation of
                 FilesOnDisk ->
                   Outside.sendInfo (Outside.AskForFile fileName)
                 FilesOnServer ->
                    Helper.Server.getDocument model.serverURL fileName

updateDocument : Model -> ( Model, Cmd Msg )
updateDocument model =
    let
        document_ =
            model.document

        document =
            { document_ | timeUpdated = model.currentTime }
    in
    case model.documentStatus of
        DocumentDirty ->
            { model
                | tickCount = model.tickCount + 1
                , documentStatus = DocumentSaved
            }
                |> withCmd
                    (case model.fileLocation of
                        FilesOnDisk ->
                            Outside.sendInfo (Outside.WriteFile document)

                        FilesOnServer ->
                            Helper.Server.updateDocument model.serverURL document
                    )

        DocumentSaved ->
            ( { model | tickCount = model.tickCount + 1 }
            , Cmd.none
            )

changeMetaData : Model -> ( Model, Cmd Msg )
changeMetaData model =
    let
        oldDocument =
            model.document

        newDocument =
            { oldDocument
                | fileName = model.fileName_
                , tags = Helper.Common.listFromString model.tags_
                , categories = Helper.Common.listFromString model.categories_
                , title = model.title_
                , subtitle = model.subtitle_
                , abstract = model.abstract_
                , belongsTo = model.belongsTo_
            }
    in
    ( { model
        | fileName = model.fileName_
        , docType = Document.docType model.fileName_
        , changingFileNameState = FileNameOK
        , popupStatus = PopupClosed
        , document = newDocument
        , fileList = Helper.Server.updateFileList (Document.toMetadata newDocument) model.fileList
      }
    , Outside.sendInfo (Outside.WriteFile newDocument)
    )


{-|

    - Create a new document give the fileName and docType in the model
    - Load the document into the model using Helper.Load.loadDocument
    - Persist the document according to the value of fileLocation

-}
createDocument : Model -> ( Model, Cmd Msg )
createDocument model =
    let
        newModel =
            case model.docType of
                MarkdownDoc ->
                    Helper.Load.loadDocument model.currentTime (model.fileName_ ++ ".md") "" MarkdownDoc model

                MiniLaTeXDoc ->
                    Helper.Load.loadDocument model.currentTime (model.fileName_ ++ ".tex") "" MiniLaTeXDoc model

        doc =
            newModel.document

        createDocCmd =
            case model.fileLocation of
                FilesOnDisk ->
                    Outside.sendInfo (Outside.CreateFile doc)

                FilesOnServer ->
                    Helper.Server.createDocument model.serverURL doc
    in
    { newModel | popupStatus = PopupClosed }
        |> Helper.Sync.syncModel2
        |> withCmd
            (Cmd.batch
                [ View.Scroll.toEditorTop
                , View.Scroll.toRenderedTextTop
                , createDocCmd
                ]
            )


listDocuments : PopupStatus -> Model -> ( Model, Cmd Msg )
listDocuments status model =
   { model | popupStatus = status, documentStatus = DocumentSaved }
       |> withCmds
         (case model.fileLocation of
             FilesOnDisk ->
               [ Helper.File.getDocumentList
               ]
             FilesOnServer ->
               [ Helper.Server.getDocumentList model.serverURL
               -- , Helper.Server.updateDocument model.serverURL model.document
               ])



--
--|> Helper.Sync.syncModel2
--|> withCmd
--    (Cmd.batch
--        [ View.Scroll.toEditorTop
--        , View.Scroll.toRenderedTextTop
--        ]
--    )


loadDocument : String -> Model -> ( Model, Cmd Msg )
loadDocument content model =
    let
        docType =
            case Document.fileExtension model.fileName of
                "md" ->
                    MarkdownDoc

                "latex" ->
                    MiniLaTeXDoc

                "tex" ->
                    MiniLaTeXDoc

                _ ->
                    MarkdownDoc

        newModel =
            Helper.Load.loadDocument model.currentTime
                (Document.titleFromFileName model.fileName)
                content
                docType
                model
                |> (\m -> { m | docType = docType })
                |> Helper.Sync.syncModel2

        newDocument =
            newModel.document
    in
    newModel
        |> withCmds
            [ View.Scroll.toRenderedTextTop
            , View.Scroll.toEditorTop
            , Helper.Server.updateDocument model.serverURL newDocument
            ]


toggleDocType : Model -> ( Model, Cmd Msg )
toggleDocType model =
    let
        newDocType =
            case model.docType of
                MarkdownDoc ->
                    MiniLaTeXDoc

                MiniLaTeXDoc ->
                    MarkdownDoc
    in
    ( { model
        | docType = newDocType
        , fileName = Document.changeDocType newDocType model.fileName
      }
    , Cmd.none
    )
