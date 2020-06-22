import {Metadata, Document} from "./document.ts";
import { load, safeDump } from 'https://deno.land/x/js_yaml_port/js-yaml.js'
import {MANIFEST} from './config.ts'
import {fetchDocument, writeDocument} from "./file.ts"

const hasSameFileName = (a: Metadata, b: Metadata) => a.fileName == b.fileName;

const hasSameId = (a: Metadata, b: Metadata) => a.id == b.id;

const isNotPresent = (d: Metadata, manifest_: Array<Metadata>) =>
  manifest_.filter((r) => hasSameId(r, d)).length == 0;


export const fetchManifest = async (): Promise<Metadata[]> => {
  const data = await Deno.readFile(MANIFEST);

  const decoder = new TextDecoder();
  const decodedData = decoder.decode(data);

  return load(decodedData);
};

var manifest = await fetchManifest();

export const writeManifest = async (data: Array<Metadata>): Promise<void> => {
  const encoder = new TextEncoder();
  await Deno.writeFile(MANIFEST, encoder.encode(safeDump(data)));
};


/////////////////////////


const updateMetadata = (s: Metadata, t : Metadata) =>
  s.id == t.id ?  Object.assign({}, s) : t


export const fetchDocumentById = async (id: String): Promise<Document> => {
   const metaData = manifest.filter(r => r.id == id)[0]

   return fetchDocument(metaData)

}

export const fetchDocumentByFileName = async (fileName: String): Promise<Document> => {
   const metaData = manifest.filter(r => r.fileName == fileName)[0]

   return fetchDocument(metaData)

}

/////////////


export const updateDocument = async ({
  request,
  response,
}: {
  request: any;
  response: any;
}) => {
  const {
    value : {fileName, id, author, timeCreated, timeUpdated, tags, categories,
       title, subtitle, abstract, belongsTo, content},
  } = await request.body();
  response.headers.set("Access-Control-Allow-Origin", "*");
  response.headers.append("Access-Control-Allow-Methods", "PUT, OPTIONS");
  response.headers.append(
    "Access-Control-Allow-Headers",
    "X-Requested-With, Content-Type, Accept, Origin",
  );

    const sourceDoc: Document = { id: id, fileName: fileName, author: author,
       timeCreated: timeCreated, timeUpdated: timeUpdated, tags: tags,
       categories: categories, title: title, subtitle: subtitle,
       abstract: abstract, belongsTo: belongsTo,
       content: content };

    const sourceMetadata: Metadata = { id: id, fileName: fileName, author: author,
       timeCreated: timeCreated, timeUpdated: timeUpdated, tags: tags,
       categories: categories, title: title, subtitle: subtitle,
       abstract: abstract, belongsTo: belongsTo};

    if (isNotPresent(sourceMetadata, manifest)) {
      manifest.push(sourceMetadata);
      writeManifest(manifest)
      writeDocument(sourceDoc)
      console.log("added: " + sourceDoc.fileName);
      response.body = { msg: "Added: " + sourceDoc.fileName};
      response.status = 200;

    } else {
      manifest = manifest.map((d:Metadata) => updateMetadata(sourceMetadata, d))
      writeManifest(manifest)
      writeDocument(sourceDoc)
      console.log("updated: " + sourceDoc.fileName);
      response.body = { msg: "Updated: " + sourceDoc.fileName };
      response.status = 200;
    }

};

//////////////////////


export const getDocuments = ( { response }: { response: any }) => {
  console.log("file list requested");
  response.headers.set("Access-Control-Allow-Origin", "*");
  response.body = manifest;
};

// Get a document by file name
export const  getDocument = async ({
  params,
  response,
}: {
  params: {
    fileName: string;
  };
  response: any;
}) => {
  console.log("GET", params.fileName)
  response.headers.set("Access-Control-Allow-Origin", "*");
  response.body = await fetchDocumentByFileName(params.fileName)

  response.status = 200;
  return;
};


// Add a new document
export const createDocument = async ({
  request,
  response,
}: {
  request: any;
  response: any;
}) => {
  console.log("processing POST request");
  const {
    value : {token, fileName, id, author, timeCreated, timeUpdated, tags, categories,
       title, subtitle, abstract, belongsTo, content},
  } = await request.body();
  response.headers.set("Access-Control-Allow-Origin", "*");
  response.headers.append("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.headers.append(
    "Access-Control-Allow-Headers",
    "X-Requested-With, Content-Type, Accept, Origin",
  );

  if (true) {

    const doc_ = { id: id, fileName: fileName, author: author,
       timeCreated: timeCreated, timeUpdated: timeUpdated, tags: tags,
       categories: categories, title: title, subtitle: subtitle,
       abstract: abstract, belongsTo: belongsTo,
       content: content };

    const metaData_ = { id: id, fileName: fileName, author: author,
       timeCreated: timeCreated, timeUpdated: timeUpdated, tags: tags,
       categories: categories, title: title, subtitle: subtitle,
       abstract: abstract, belongsTo: belongsTo};

    if (isNotPresent(metaData_, manifest)) {

      manifest.push(doc_);
      writeManifest(manifest)
      writeDocument(doc_)

      console.log("pushing document: " + doc_.fileName);
      response.body = { msg: "OK" };
      response.status = 200;

    } else {
      console.log("duplicate document");
      response.body = { msg: "file already exists" };
      response.status = 200;
    }
  } else {
    response.body = { msg: "Token does not match" };
    response.status = 400;
  }
};
