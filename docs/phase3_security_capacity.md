# Fase 3: seguridad y capacidad estimada

## Flujo protegido

Las actividades reservan un intento, comprometen un `answerSubmission` y crean
un resultado semántico antes del batch de cuatro agregados. El examen reserva
también sus 15 IDs. Su submission es inmutable; dos proofs inmutables (8 y 7)
validan las respuestas frente al answer key protegido, y el resultado semántico
se crea antes del batch de examen y categoría. La prueba de 15 respuestas en
una sola Rule alcanzó el límite de 1.000 expresiones en Emulator Suite. La
división 8+7 pasó con 15 respuestas reales. El examen nunca modifica puntos,
ranking ni conjuntos de puntuación.

El contenido público conserva `correctAnswer` y `acceptedAnswers` para la
retroalimentación local. No es autoridad para Firestore. El seeder deriva las
claves protegidas de las mismas preguntas. El nuevo answer key de examen debe
incluirse cuando se autorice un futuro despliegue de contenido y reglas; en
esta subfase no se escribió contenido remoto ni se migraron usuarios.

## Operaciones aproximadas del flujo central

| Flujo normal | Lecturas SDK | Escrituras SDK |
| --- | ---: | ---: |
| Actividad: cargar 10 preguntas | 10 | 0 |
| Actividad: reserva | 1 | 1 |
| Actividad: responder | 0 | 0 |
| Actividad: submission, attempt y cuatro agregados | 4 | 6 |
| **Actividad completa** | **15** | **7** |
| Examen: cargar banco para selección equilibrada | 60 | 0 |
| Examen: reserva | 1 | 1 |
| Examen: responder | 0 | 0 |
| Examen: submission, proofs, attempt y dos agregados | ~11 | 6 |
| Examen: refrescar categoría tras confirmar | ~8 | 0 |
| **Examen completo** | **~80** | **7** |

Las lecturas finales del examen incluyen el resumen del examen, categoría,
perfil, seis progresos de actividad y el progreso de examen consultado para
decidir el estado final. La consulta de configuración, Home, Profile, Ranking
y los chequeos de conectividad son sobrecarga variable adicional. Ranking
mantiene su consulta limitada a diez entradas. Durante recovery se leen de
nuevo las etapas existentes y los agregados; un documento ya creado puede
causar un intento de escritura rechazado antes de la lectura de conciliación.
No hay consultas periódicas para sincronización.

Las Security Rules hacen accesos auxiliares a reservas, answer keys,
submissions, proofs e intentos, y durante el batch a los documentos vinculados.
Estos accesos no están incluidos en las lecturas del SDK de la tabla. El
emulador valida el límite de expresiones, pero esta estimación no equivale a
una medición de facturación de esos accesos.

| Escenario, solo actividades centrales | Lecturas SDK | Escrituras SDK |
| --- | ---: | ---: |
| 100 DAU × 1 actividad | ~1.500 | ~700 |
| 500 DAU × 1 actividad | ~7.500 | ~3.500 |
| 500 DAU × 2 actividades | ~15.000 | ~7.000 |
| 1.000 DAU × 1 actividad | ~15.000 | ~7.000 |
| 1.000 DAU × 2 actividades | ~30.000 | ~14.000 |

Estas multiplicaciones no garantizan capacidad para una cantidad concreta de
usuarios. El examen sigue cargando 60 documentos porque la selección actual
equilibra actividad, dificultad, capacidad y tipo; un manifest de solo IDs no
conservaría esa selección. Se mantiene esa lectura hasta disponer de una
optimización que preserve el comportamiento.

## Riesgos residuales

- Un cliente modificado puede inspeccionar las respuestas públicas utilizadas
  por la app oficial.
- Las Rules validan la consistencia de intentos, progreso y puntos, pero no
  demuestran que una persona respondió sin automatización.
- Las Rules verifican que los 15 IDs del examen son válidos, únicos e
  inmutables. Sin backend confiable no prueban aleatoriedad frente a un cliente
  modificado.

App Check puede ser una defensa futura en profundidad; no sustituye las Rules.
