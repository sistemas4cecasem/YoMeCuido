#!/usr/bin/env node

const fs = require('fs');
const https = require('https');
const path = require('path');
const { execFileSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '..');
const firestoreDatabase = '(default)';
const args = new Set(process.argv.slice(2));
const execute = args.has('--execute');
const confirmProject = readArgValue('--confirm-project');

async function main() {
  const configuredProjectId = readConfiguredProjectId();
  const gcloudProjectId = runGcloud(['config', 'get-value', 'project']).trim();
  if (!configuredProjectId) {
    throw new Error('No se pudo detectar un projectId configurado.');
  }
  if (gcloudProjectId !== configuredProjectId) {
    throw new Error(
      `gcloud apunta a "${gcloudProjectId}", pero el proyecto configurado es "${configuredProjectId}".`,
    );
  }
  if (execute && confirmProject !== configuredProjectId) {
    throw new Error(
      `Para ejecutar borrado usa --confirm-project ${configuredProjectId}.`,
    );
  }

  const token = runGcloud(['auth', 'print-access-token']).trim();
  if (!token) {
    throw new Error('No se pudo obtener token OAuth de gcloud.');
  }

  const client = new GoogleRestClient({
    projectId: configuredProjectId,
    token,
  });
  const authUsers = await client.listAuthUsers();
  const rootCollections = await client.listRootCollections();
  const categoryDocs = await client.listDocuments('categories');
  const contentSummary = await client.countEducationalContent(categoryDocs);
  const userDocs = await client.listDocuments('users');
  const usernameDocs = await client.listDocuments('usernames');
  const authUidSet = new Set(authUsers.map((user) => user.localId));
  const userDocsToDelete = userDocs.filter((document) => {
    return authUidSet.has(document.id);
  });
  const usernameDocsToDelete = usernameDocs.filter((document) => {
    const uid = readFirestoreString(document.fields?.uid);
    return uid != null && authUidSet.has(uid);
  });
  const userTreeCounts = [];
  for (const document of userDocsToDelete) {
    userTreeCounts.push(await client.countDocumentTree(document.name));
  }

  printPlan({
    projectId: configuredProjectId,
    execute,
    rootCollections,
    authUsers,
    categoryDocs,
    contentSummary,
    userDocs,
    userDocsToDelete,
    usernameDocs,
    usernameDocsToDelete,
    userTreeCounts,
  });

  if (!rootCollections.includes('categories')) {
    throw new Error('No se encontró la colección de contenido categories.');
  }
  if (categoryDocs.length === 0) {
    throw new Error('La colección categories está vacía; no se continuará.');
  }
  if (execute) {
    for (const document of userDocsToDelete) {
      await client.deleteDocumentTree(document.name);
    }
    for (const document of usernameDocsToDelete) {
      await client.deleteDocument(document.name);
    }
    if (authUsers.length > 0) {
      await client.deleteAuthUsers(authUsers.map((user) => user.localId));
    }
  }

  await verifyCleanup({
    client,
    execute,
    authUsers,
    contentSummaryBefore: contentSummary,
    deletedUserDocIds: userDocsToDelete.map((document) => document.id),
  });
}

function printPlan({
  projectId,
  execute,
  rootCollections,
  authUsers,
  categoryDocs,
  contentSummary,
  userDocs,
  userDocsToDelete,
  usernameDocs,
  usernameDocsToDelete,
  userTreeCounts,
}) {
  const nestedUserDocuments = userTreeCounts.reduce(
    (total, item) => total + item.totalDocuments,
    0,
  );
  console.log(`Proyecto: ${projectId}`);
  console.log(`Modo: ${execute ? 'execute' : 'dry-run'}`);
  console.log(`Colecciones raíz: ${rootCollections.join(', ') || '(ninguna)'}`);
  console.log(`Usuarios Auth encontrados: ${authUsers.length}`);
  console.log(`Documentos users encontrados: ${userDocs.length}`);
  console.log(`Documentos users a eliminar: ${userDocsToDelete.length}`);
  console.log(`Documentos usernames encontrados: ${usernameDocs.length}`);
  console.log(`Documentos usernames a eliminar: ${usernameDocsToDelete.length}`);
  console.log(`Documentos en jerarquías de progreso/perfil: ${nestedUserDocuments}`);
  console.log(`Documentos categories preservados: ${categoryDocs.length}`);
  console.log(
    `Contenido preservado: lessonPages=${contentSummary.lessonPages}, activities=${contentSummary.activities}, questions=${contentSummary.questions}, examConfig=${contentSummary.examConfig}`,
  );
}

async function verifyCleanup({
  client,
  execute,
  authUsers,
  contentSummaryBefore,
  deletedUserDocIds,
}) {
  const categoryDocsAfter = await client.listDocuments('categories');
  const contentSummaryAfter = await client.countEducationalContent(categoryDocsAfter);
  if (!sameContentSummary(contentSummaryBefore, contentSummaryAfter)) {
    throw new Error('La cantidad de categorías cambió durante la verificación.');
  }
  if (!execute) {
    console.log('Dry-run completado. No se eliminaron datos.');
    return;
  }

  const authUsersAfter = await client.listAuthUsers();
  const remainingDeletedUsers = await client.findExistingDocumentIds(
    'users',
    deletedUserDocIds,
  );
  const remainingAuthUsers = authUsersAfter.filter((user) => {
    return authUsers.some((before) => before.localId === user.localId);
  });

  console.log(`Usuarios Auth restantes de la limpieza: ${remainingAuthUsers.length}`);
  console.log(`Documentos users restantes de la limpieza: ${remainingDeletedUsers.length}`);
  console.log(`Documentos categories preservados tras limpieza: ${categoryDocsAfter.length}`);
  console.log(
    `Contenido preservado tras limpieza: lessonPages=${contentSummaryAfter.lessonPages}, activities=${contentSummaryAfter.activities}, questions=${contentSummaryAfter.questions}, examConfig=${contentSummaryAfter.examConfig}`,
  );

  if (remainingAuthUsers.length > 0) {
    throw new Error('Quedaron usuarios Auth de prueba sin eliminar.');
  }
  if (remainingDeletedUsers.length > 0) {
    throw new Error('Quedaron documentos users de prueba sin eliminar.');
  }
}

function readConfiguredProjectId() {
  const firebaserc = JSON.parse(
    fs.readFileSync(path.join(repoRoot, '.firebaserc'), 'utf8'),
  );
  const firebaseJson = JSON.parse(
    fs.readFileSync(path.join(repoRoot, 'firebase.json'), 'utf8'),
  );
  const optionsSource = fs.readFileSync(
    path.join(repoRoot, 'lib', 'firebase_options.dart'),
    'utf8',
  );
  const rcProject = firebaserc.projects?.default;
  const flutterProject =
    firebaseJson.flutter?.platforms?.android?.default?.projectId;
  const dartProject =
    firebaseJson.flutter?.platforms?.dart?.['lib/firebase_options.dart']?.projectId;
  const optionsProject = optionsSource.match(/projectId: '([^']+)'/)?.[1];
  const projectIds = [rcProject, flutterProject, dartProject, optionsProject];
  if (projectIds.some((value) => !value)) {
    throw new Error('Falta projectId en la configuración Firebase local.');
  }
  if (new Set(projectIds).size !== 1) {
    throw new Error(`Los projectId configurados no coinciden: ${projectIds.join(', ')}`);
  }
  return rcProject;
}

function readArgValue(name) {
  const index = process.argv.indexOf(name);
  if (index === -1) return null;
  return process.argv[index + 1] ?? null;
}

function runGcloud(args) {
  return execFileSync('cmd.exe', ['/c', 'gcloud', ...args], {
    cwd: repoRoot,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

class GoogleRestClient {
  constructor({ projectId, token }) {
    this.projectId = projectId;
    this.token = token;
  }

  async listAuthUsers() {
    const users = [];
    let nextPageToken = null;
    do {
      const url = new URL(
        `https://identitytoolkit.googleapis.com/v1/projects/${this.projectId}/accounts:batchGet`,
      );
      url.searchParams.set('maxResults', '1000');
      if (nextPageToken) {
        url.searchParams.set('nextPageToken', nextPageToken);
      }
      const response = await this.request('GET', url.toString());
      users.push(...(response.userInfo ?? response.users ?? []));
      nextPageToken = response.nextPageToken ?? null;
    } while (nextPageToken);
    return users;
  }

  async deleteAuthUsers(localIds) {
    if (localIds.length === 0) return;
    const response = await this.request(
      'POST',
      `https://identitytoolkit.googleapis.com/v1/projects/${this.projectId}/accounts:batchDelete`,
      { localIds, force: true },
    );
    if (response.errors?.length) {
      throw new Error(`No se eliminaron todos los usuarios Auth: ${JSON.stringify(response.errors)}`);
    }
  }

  async listRootCollections() {
    const response = await this.request(
      'POST',
      this.firestoreDocumentsUrl(':listCollectionIds'),
      { pageSize: 100 },
    );
    return response.collectionIds ?? [];
  }

  async listDocuments(pathValue) {
    const documents = [];
    let pageToken = null;
    do {
      const url = new URL(this.firestoreDocumentsUrl(`/${pathValue}`));
      url.searchParams.set('pageSize', '100');
      if (pageToken) {
        url.searchParams.set('pageToken', pageToken);
      }
      const response = await this.request('GET', url.toString(), null, {
        allowNotFound: true,
      });
      documents.push(...(response.documents ?? []).map(toListedDocument));
      pageToken = response.nextPageToken ?? null;
    } while (pageToken);
    return documents;
  }

  async findExistingDocumentIds(collectionId, documentIds) {
    const remaining = [];
    for (const documentId of documentIds) {
      const name = this.firestoreDocumentName(`${collectionId}/${documentId}`);
      const response = await this.request('GET', `https://firestore.googleapis.com/v1/${name}`, null, {
        allowNotFound: true,
      });
      if (!response.__notFound) {
        remaining.push(documentId);
      }
    }
    return remaining;
  }

  async countDocumentTree(documentName) {
    const collections = await this.listCollectionIdsForDocument(documentName);
    let totalDocuments = 1;
    for (const collectionId of collections) {
      const childPath = `${documentPathFromName(documentName)}/${collectionId}`;
      const children = await this.listDocuments(childPath);
      for (const child of children) {
        totalDocuments += (await this.countDocumentTree(child.name)).totalDocuments;
      }
    }
    return { totalDocuments };
  }

  async deleteDocumentTree(documentName) {
    const collections = await this.listCollectionIdsForDocument(documentName);
    for (const collectionId of collections) {
      const childPath = `${documentPathFromName(documentName)}/${collectionId}`;
      const children = await this.listDocuments(childPath);
      for (const child of children) {
        await this.deleteDocumentTree(child.name);
      }
    }
    await this.deleteDocument(documentName);
  }

  async deleteDocument(documentName) {
    await this.request('DELETE', `https://firestore.googleapis.com/v1/${documentName}`);
  }

  async listCollectionIdsForDocument(documentName) {
    const response = await this.request(
      'POST',
      `https://firestore.googleapis.com/v1/${documentName}:listCollectionIds`,
      { pageSize: 100 },
    );
    return response.collectionIds ?? [];
  }

  async countEducationalContent(categoryDocs) {
    const summary = {
      categories: categoryDocs.length,
      lessonPages: 0,
      activities: 0,
      questions: 0,
      examConfig: 0,
    };
    for (const category of categoryDocs) {
      const categoryPath = documentPathFromName(category.name);
      summary.lessonPages += (await this.listDocuments(`${categoryPath}/lessonPages`)).length;
      summary.activities += (await this.listDocuments(`${categoryPath}/activities`)).length;
      summary.questions += (await this.listDocuments(`${categoryPath}/questions`)).length;
      summary.examConfig += (await this.listDocuments(`${categoryPath}/examConfig`)).length;
    }
    return summary;
  }

  firestoreDocumentsUrl(suffix = '') {
    return `https://firestore.googleapis.com/v1/projects/${this.projectId}/databases/${firestoreDatabase}/documents${suffix}`;
  }

  firestoreDocumentName(pathValue) {
    return `projects/${this.projectId}/databases/${firestoreDatabase}/documents/${pathValue}`;
  }

  request(method, url, body = null, options = {}) {
    return new Promise((resolve, reject) => {
      const target = new URL(url);
      const payload = body == null ? null : JSON.stringify(body);
      const request = https.request(
        {
          method,
          hostname: target.hostname,
          path: target.pathname + target.search,
          headers: {
            Authorization: `Bearer ${this.token}`,
            'Content-Type': 'application/json',
            'x-goog-user-project': this.projectId,
          },
        },
        (response) => {
          let data = '';
          response.on('data', (chunk) => {
            data += chunk;
          });
          response.on('end', () => {
            if (options.allowNotFound && response.statusCode === 404) {
              resolve({ __notFound: true });
              return;
            }
            const parsed = data ? JSON.parse(data) : {};
            if (response.statusCode < 200 || response.statusCode >= 300) {
              reject(new Error(parsed.error?.message ?? `HTTP ${response.statusCode}`));
              return;
            }
            resolve(parsed);
          });
        },
      );
      request.on('error', reject);
      if (payload) {
        request.write(payload);
      }
      request.end();
    });
  }
}

function toListedDocument(document) {
  return {
    name: document.name,
    id: document.name.split('/').pop(),
    fields: document.fields ?? {},
  };
}

function documentPathFromName(name) {
  const marker = '/documents/';
  const index = name.indexOf(marker);
  if (index === -1) {
    throw new Error(`Nombre de documento Firestore inválido: ${name}`);
  }
  return name.slice(index + marker.length);
}

function readFirestoreString(field) {
  return field?.stringValue ?? null;
}

function sameContentSummary(left, right) {
  return (
    left.categories === right.categories &&
    left.lessonPages === right.lessonPages &&
    left.activities === right.activities &&
    left.questions === right.questions &&
    left.examConfig === right.examConfig
  );
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
});
