import 'dart:convert';
import 'dart:io';

import 'package:demo_yomecuido/data/firestore/educational_content_seed.dart';
import 'package:demo_yomecuido/data/models/category.dart';
import 'package:demo_yomecuido/data/models/final_exam.dart';
import 'package:demo_yomecuido/data/models/learning_activity.dart';
import 'package:demo_yomecuido/data/models/lesson_page.dart';
import 'package:demo_yomecuido/data/models/quiz_question.dart';

const _categoriesPath = 'assets/data/categories.json';
const _lessonPath = 'assets/data/relations_violence_lesson.json';
const _activitiesPath = 'assets/data/relations_violence_activities.json';
const _questionsPath = 'assets/data/relations_violence_questions.json';
const _defaultDatabaseId = '(default)';
const _relationsViolenceCategoryId = 'relations_violence_digital';

Future<void> main(List<String> arguments) async {
  try {
    final options = _SeedOptions.parse(arguments);
    if (options.showHelp) {
      _printUsage();
      return;
    }

    final projectId = options.projectId ?? await _readDefaultProjectId();
    final databaseId = options.databaseId ?? _defaultDatabaseId;
    final bundle = await _loadSeedBundle();
    final plan = EducationalContentSeedBuilder.build(bundle);

    _printPlanSummary(plan, mode: options.write ? 'write' : 'dry-run');

    if (!options.write) {
      _printDryRunPaths(plan);
      return;
    }

    final token = options.accessToken ?? await _readAccessToken();
    final client = _FirestoreRestClient(
      projectId: projectId,
      databaseId: databaseId,
      accessToken: token,
    );

    await client.write(plan.documents);
    final remoteSummary = await client.readSummary(
      categoryIds: bundle.categories.map((category) => category.id).toList(),
    );
    _printRemoteSummary(remoteSummary);
    _assertRemoteSummary(plan, remoteSummary);
    stdout.writeln('Seed completado y verificado.');
  } on Object catch (error) {
    stderr.writeln('Seed fallido: $error');
    exitCode = 1;
  }
}

Future<EducationalContentSeedBundle> _loadSeedBundle() async {
  final categories = await _loadList(
    path: _categoriesPath,
    listKey: 'categories',
    parser: Category.fromJson,
  );
  final lessonPages = await _loadList(
    path: _lessonPath,
    listKey: 'lessonPages',
    parser: LessonPage.fromJson,
  );
  final activities = await _loadList(
    path: _activitiesPath,
    listKey: 'activities',
    parser: LearningActivity.fromJson,
  );
  final questions = await _loadList(
    path: _questionsPath,
    listKey: 'questions',
    parser: QuizQuestion.fromJson,
  );

  return EducationalContentSeedBundle(
    categories: categories,
    lessonPagesByCategory: <String, List<LessonPage>>{
      _relationsViolenceCategoryId: lessonPages,
    },
    activitiesByCategory: _groupByCategory(activities),
    questionsByCategory: _groupByCategory(questions),
    examConfigsByCategory: <String, FinalExamConfig>{
      FinalExamConfigs.relationsViolence.categoryId:
          FinalExamConfigs.relationsViolence,
    },
  );
}

Future<List<T>> _loadList<T>({
  required String path,
  required String listKey,
  required T Function(Map<String, Object?> json) parser,
}) async {
  final source = await File(path).readAsString();
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$path must contain a JSON object.');
  }
  final list = decoded[listKey];
  if (list is! List<Object?>) {
    throw FormatException('$path must contain a "$listKey" list.');
  }

  return list
      .map((item) {
        if (item is Map<String, Object?>) {
          return parser(item);
        }
        throw FormatException('$path contains a malformed "$listKey" item.');
      })
      .toList(growable: false);
}

Map<String, List<T>> _groupByCategory<T>(Iterable<T> items) {
  final grouped = <String, List<T>>{};
  for (final item in items) {
    final categoryId = switch (item) {
      LearningActivity() => item.categoryId,
      QuizQuestion() => item.categoryId,
      _ => throw ArgumentError('Unsupported content item "$item".'),
    };
    grouped.putIfAbsent(categoryId, () => <T>[]).add(item);
  }
  return grouped;
}

Future<String> _readDefaultProjectId() async {
  final firebaseRc = File('.firebaserc');
  if (await firebaseRc.exists()) {
    final decoded = jsonDecode(await firebaseRc.readAsString());
    if (decoded is Map<String, Object?>) {
      final projects = decoded['projects'];
      if (projects is Map<String, Object?>) {
        final projectId = projects['default'];
        if (projectId is String && projectId.trim().isNotEmpty) {
          return projectId;
        }
      }
    }
  }

  final firebaseJson = File('firebase.json');
  if (await firebaseJson.exists()) {
    final decoded = jsonDecode(await firebaseJson.readAsString());
    if (decoded is Map<String, Object?>) {
      final flutter = decoded['flutter'];
      if (flutter is Map<String, Object?>) {
        final platforms = flutter['platforms'];
        if (platforms is Map<String, Object?>) {
          final android = platforms['android'];
          if (android is Map<String, Object?>) {
            final defaults = android['default'];
            if (defaults is Map<String, Object?>) {
              final projectId = defaults['projectId'];
              if (projectId is String && projectId.trim().isNotEmpty) {
                return projectId;
              }
            }
          }
        }
      }
    }
  }

  throw const FormatException(
    'No Firebase project id found. Pass --project-id=<id>.',
  );
}

Future<String> _readAccessToken() async {
  final envToken = Platform.environment['FIRESTORE_ACCESS_TOKEN'];
  if (envToken != null && envToken.trim().isNotEmpty) {
    return envToken.trim();
  }

  final result = await Process.run('gcloud', <String>[
    'auth',
    'application-default',
    'print-access-token',
  ]);
  if (result.exitCode == 0) {
    final token = result.stdout.toString().trim();
    if (token.isNotEmpty) {
      return token;
    }
  }

  throw const FormatException(
    'No access token available. Set FIRESTORE_ACCESS_TOKEN or run '
    'gcloud auth application-default login.',
  );
}

void _printPlanSummary(
  EducationalContentSeedPlan plan, {
  required String mode,
}) {
  stdout.writeln('Modo: $mode');
  stdout.writeln('Categorías: ${plan.categoryCount}');
  stdout.writeln('Lesson pages: ${plan.lessonPageCount}');
  stdout.writeln('Actividades: ${plan.activityCount}');
  stdout.writeln('Preguntas: ${plan.questionCount}');
  stdout.writeln('Exam configs: ${plan.examConfigCount}');
}

void _printDryRunPaths(EducationalContentSeedPlan plan) {
  stdout.writeln('Operaciones preparadas: ${plan.documents.length}');
  for (final path in plan.paths) {
    stdout.writeln('set $path');
  }
  stdout.writeln('Dry-run completado. No se escribió en Firestore.');
}

void _printRemoteSummary(_FirestoreSeedSummary summary) {
  stdout.writeln('Verificación remota:');
  stdout.writeln('Categorías: ${summary.categories}');
  stdout.writeln('Lesson pages: ${summary.lessonPages}');
  stdout.writeln('Actividades: ${summary.activities}');
  stdout.writeln('Preguntas: ${summary.questions}');
  stdout.writeln('Exam configs: ${summary.examConfigs}');
}

void _assertRemoteSummary(
  EducationalContentSeedPlan plan,
  _FirestoreSeedSummary summary,
) {
  if (summary.categories < plan.categoryCount ||
      summary.lessonPages < plan.lessonPageCount ||
      summary.activities < plan.activityCount ||
      summary.questions < plan.questionCount ||
      summary.examConfigs < plan.examConfigCount) {
    throw const FormatException(
      'Remote verification returned fewer documents than expected.',
    );
  }
}

void _printUsage() {
  stdout.writeln('Uso: dart run tool/seed_educational_content.dart [opciones]');
  stdout.writeln('');
  stdout.writeln('Opciones:');
  stdout.writeln(
    '  --dry-run              Valida y lista operaciones sin escribir.',
  );
  stdout.writeln(
    '  --write                Escribe usando IDs estables con batchWrite.',
  );
  stdout.writeln('  --project-id=<id>      Sobrescribe el proyecto Firebase.');
  stdout.writeln('  --database-id=<id>     Sobrescribe la base de datos.');
  stdout.writeln('  --access-token=<token> Usa un token OAuth ya emitido.');
}

class _SeedOptions {
  const _SeedOptions({
    required this.write,
    required this.showHelp,
    this.projectId,
    this.databaseId,
    this.accessToken,
  });

  final bool write;
  final bool showHelp;
  final String? projectId;
  final String? databaseId;
  final String? accessToken;

  static _SeedOptions parse(List<String> arguments) {
    final showHelp = arguments.contains('--help') || arguments.contains('-h');
    final write = arguments.contains('--write');
    final dryRun = arguments.contains('--dry-run');
    if (write && dryRun) {
      throw const FormatException('Use --write or --dry-run, not both.');
    }

    return _SeedOptions(
      write: write,
      showHelp: showHelp,
      projectId: _readOption(arguments, '--project-id'),
      databaseId: _readOption(arguments, '--database-id'),
      accessToken: _readOption(arguments, '--access-token'),
    );
  }

  static String? _readOption(List<String> arguments, String key) {
    final prefix = '$key=';
    for (final argument in arguments) {
      if (argument.startsWith(prefix)) {
        final value = argument.substring(prefix.length).trim();
        if (value.isEmpty) {
          throw FormatException('$key cannot be empty.');
        }
        return value;
      }
    }
    return null;
  }
}

class _FirestoreRestClient {
  const _FirestoreRestClient({
    required this.projectId,
    required this.databaseId,
    required this.accessToken,
  });

  final String projectId;
  final String databaseId;
  final String accessToken;

  Future<void> write(List<EducationalContentSeedDocument> documents) async {
    const maxBatchSize = 500;
    for (var index = 0; index < documents.length; index += maxBatchSize) {
      final batch = documents.skip(index).take(maxBatchSize).toList();
      await _postJson(_documentsUri('documents:batchWrite'), <String, Object?>{
        'writes': batch
            .map((document) {
              return <String, Object?>{
                'update': <String, Object?>{
                  'name': _documentName(document.path),
                  'fields': _toFirestoreFields(document.data),
                },
              };
            })
            .toList(growable: false),
      });
    }
  }

  Future<_FirestoreSeedSummary> readSummary({
    required List<String> categoryIds,
  }) async {
    final categories = await _readCollection('categories');
    var lessonPages = 0;
    var activities = 0;
    var questions = 0;
    var examConfigs = 0;

    for (final categoryId in categoryIds) {
      lessonPages += await _readCollection(
        'categories/$categoryId/lessonPages',
      );
      activities += await _readCollection('categories/$categoryId/activities');
      questions += await _readCollection('categories/$categoryId/questions');
      examConfigs += await _readCollection('categories/$categoryId/examConfig');
    }

    return _FirestoreSeedSummary(
      categories: categories,
      lessonPages: lessonPages,
      activities: activities,
      questions: questions,
      examConfigs: examConfigs,
    );
  }

  Future<int> _readCollection(String path) async {
    final response = await _getJson(_documentsUri(_encodePath(path)));
    final documents = response['documents'];
    if (documents == null) {
      return 0;
    }
    if (documents is List<Object?>) {
      return documents.length;
    }
    throw FormatException('Malformed Firestore response for "$path".');
  }

  Future<void> _postJson(Uri uri, Map<String, Object?> body) async {
    final response = await _sendJson('POST', uri, body: body);
    final writeResults = response['writeResults'];
    if (writeResults is! List<Object?>) {
      throw const FormatException(
        'Firestore batchWrite response is malformed.',
      );
    }
  }

  Future<Map<String, Object?>> _getJson(Uri uri) {
    return _sendJson('GET', uri);
  }

  Future<Map<String, Object?>> _sendJson(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Firestore request failed with ${response.statusCode}: $responseBody',
          uri: uri,
        );
      }
      if (responseBody.trim().isEmpty) {
        return <String, Object?>{};
      }
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      throw const FormatException('Firestore response must be a JSON object.');
    } finally {
      client.close(force: true);
    }
  }

  Uri _documentsUri(String suffix) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/'
      '${Uri.encodeComponent(databaseId)}/documents/$suffix',
    );
  }

  String _documentName(String path) {
    return 'projects/$projectId/databases/$databaseId/documents/$path';
  }

  static String _encodePath(String path) {
    return path.split('/').map(Uri.encodeComponent).join('/');
  }
}

class _FirestoreSeedSummary {
  const _FirestoreSeedSummary({
    required this.categories,
    required this.lessonPages,
    required this.activities,
    required this.questions,
    required this.examConfigs,
  });

  final int categories;
  final int lessonPages;
  final int activities;
  final int questions;
  final int examConfigs;
}

Map<String, Object?> _toFirestoreFields(Map<String, Object?> data) {
  return data.map((key, value) {
    return MapEntry(key, _toFirestoreValue(value));
  });
}

Map<String, Object?> _toFirestoreValue(Object? value) {
  if (value == null) {
    return <String, Object?>{'nullValue': 'NULL_VALUE'};
  }
  if (value is String) {
    return <String, Object?>{'stringValue': value};
  }
  if (value is bool) {
    return <String, Object?>{'booleanValue': value};
  }
  if (value is int) {
    return <String, Object?>{'integerValue': value.toString()};
  }
  if (value is double) {
    return <String, Object?>{'doubleValue': value};
  }
  if (value is List<Object?>) {
    return <String, Object?>{
      'arrayValue': <String, Object?>{
        if (value.isNotEmpty)
          'values': value.map(_toFirestoreValue).toList(growable: false),
      },
    };
  }
  if (value is Map<String, Object?>) {
    return <String, Object?>{
      'mapValue': <String, Object?>{'fields': _toFirestoreFields(value)},
    };
  }
  throw FormatException('Unsupported Firestore value "$value".');
}
