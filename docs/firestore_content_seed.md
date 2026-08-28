# Seed de contenido educativo

Esta herramienta migra el contenido educativo local hacia Cloud Firestore sin
usar Firebase Console y sin ejecutarse desde la app Flutter.

## Requisitos

- Firebase CLI o credenciales administrativas locales con acceso al proyecto.
- Proyecto Firebase configurado en `.firebaserc` o parámetro `--project-id`.
- Para escritura real, un token OAuth disponible mediante
  `FIRESTORE_ACCESS_TOKEN`, `--access-token` o
  `gcloud auth application-default login`.

## Fuente

El seed lee los archivos actuales:

- `tool/seed/content/categories.json`
- `tool/seed/content/relations_violence_lesson.json`
- `tool/seed/content/relations_violence_activities.json`
- `tool/seed/content/relations_violence_questions.json`

## Comandos

Validar y listar operaciones sin escribir:

```bash
dart run tool/seed_educational_content.dart --dry-run
```

Escribir en Firestore con IDs estables:

```bash
dart run tool/seed_educational_content.dart --write
```

Comparar los conteos esperados con Firestore sin escribir:

```bash
dart run tool/seed_educational_content.dart --verify
```

Opcionalmente:

```bash
dart run tool/seed_educational_content.dart --write --project-id=yomecuido-1dc1a
```

## Resultado esperado

La ejecución prepara documentos solo bajo `categories/...`:

- 8 categorías.
- 4 páginas teóricas.
- 6 actividades.
- 12 preguntas existentes.
- 1 configuración de examen final.

El script usa operaciones `set` mediante `batchWrite`, por lo que una segunda
ejecución actualiza los mismos paths y no crea duplicados.

## Verificación

Después de una escritura real, el script lee Firestore y muestra el conteo de:

- categorías;
- páginas teóricas;
- actividades;
- preguntas;
- configuraciones de examen.

El script no elimina documentos desconocidos y no toca `users/{uid}` ni datos de
progreso, intentos o resultados.
