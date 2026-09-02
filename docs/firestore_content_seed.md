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

El seed lee `categories.json` y descubre automáticamente todos los archivos de
contenido bajo `tool/seed/content/`:

- `tool/seed/content/categories.json`
- `tool/seed/content/*_lesson.json`
- `tool/seed/content/*_activities.json`
- `tool/seed/content/*_questions.json`

Las lecciones se relacionan con cada categoría mediante `lessonId`. Las
actividades y preguntas se relacionan mediante `categoryId`, y cada pregunta
conserva su `activityId`.

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
- 48 páginas teóricas.
- 48 actividades.
- 480 preguntas.
- 8 configuraciones de examen final.

El script usa operaciones `set` mediante `batchWrite`, por lo que una segunda
ejecución actualiza los mismos paths y no crea duplicados.

Antes de escribir, valida localmente que cada categoría tenga 6 cápsulas, 6
actividades, 60 preguntas, 10 preguntas por actividad, referencias válidas y
respuestas correctas coherentes con el tipo de pregunta.

## Verificación

Después de una escritura real, el script lee Firestore y muestra el conteo de:

- categorías;
- páginas teóricas;
- actividades;
- preguntas;
- configuraciones de examen.

El script no elimina documentos desconocidos y no toca `users/{uid}` ni datos de
progreso, intentos o resultados.
