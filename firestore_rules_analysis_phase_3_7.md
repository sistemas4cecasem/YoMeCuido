# Analisis de reglas Firestore - examen final

## Cambio evaluado

Se agrego persistencia para examenes finales por categoria en:

- `users/{uid}/categoryProgress/{categoryId}/exams/{examId}`
- `users/{uid}/categoryProgress/{categoryId}/exams/{examId}/attempts/{attemptId}`

Los intentos de actividad siguen viviendo bajo `activities/{activityId}/attempts`.

## Validaciones aplicadas

- Solo el usuario propietario puede leer o escribir su progreso.
- No se permite listar ni leer perfiles de otros usuarios.
- Los documentos de resumen de examen aceptan unicamente los campos esperados.
- `examId` debe coincidir con el ID del documento.
- `attemptCount` no puede disminuir en actualizaciones.
- Los intentos de actividad requieren `type == activity`, `activityId` valido y `examId == null`.
- Los intentos de examen requieren `type == exam`, `examId` valido y `activityId == null`.
- `questionIds`, `answers`, `correctAnswers`, `totalQuestions` y `percentage` mantienen los limites existentes.
- `answers` solo puede contener claves presentes en `questionIds`.
- `startedAt` permanece inmutable y `completedAt` solo puede ser `null`, `request.time` o su valor previo.

## Revision critica

La regla no enumera IDs de contenido local porque las preguntas se cargan desde assets Flutter y no existe una fuente remota canonica de preguntas en Firestore. Eso mantiene la demo flexible, pero tambien significa que las reglas validan forma y propiedad, no exactitud pedagogica del banco local.

El campo `completedActivityIds` sigue validandose por cantidad y no por una lista fija de seis IDs, porque esa lista pertenece al contenido local. El desbloqueo exacto del examen se controla en la app verificando todos los IDs de actividad cargados.

## Riesgo residual

Una app cliente modificada por el usuario propietario podria escribir porcentajes o respuestas con forma valida. Para una demo esto protege aislamiento entre usuarios y evita estructuras inesperadas, pero no reemplaza validacion server-side para un producto final.
