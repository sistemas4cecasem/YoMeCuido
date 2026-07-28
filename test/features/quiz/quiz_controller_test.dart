import 'package:demo_yomecuido/data/models/quiz_question.dart';
import 'package:demo_yomecuido/features/quiz/quiz_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuizController', () {
    test('validates a correct multiple choice answer', () {
      final controller = QuizController(questions: _questions);

      controller.selectOption('control_passwords_threaten_messages');

      expect(controller.submitAnswer(), isTrue);
      expect(controller.isAnswerConfirmed, isTrue);
      expect(controller.isCurrentAnswerCorrect, isTrue);
      expect(controller.currentFeedback, isNotNull);
      expect(controller.correctAnswers, 1);
    });

    test('validates an incorrect multiple choice answer', () {
      final controller = QuizController(questions: _questions);

      controller.selectOption('update_application');

      expect(controller.submitAnswer(), isTrue);
      expect(controller.isCurrentAnswerCorrect, isFalse);
      expect(controller.correctAnswers, 0);
    });

    test('validates true and false answers by id', () {
      final controller = QuizController(questions: _questions);

      _answerCurrentCorrectly(controller);
      controller.goToNextActivity();

      controller.selectOption('false');
      expect(controller.submitAnswer(), isTrue);
      expect(controller.isCurrentAnswerCorrect, isTrue);

      controller.goToNextActivity();
      _answerCurrentCorrectly(controller);
      controller.goToNextActivity();
      _answerCurrentCorrectly(controller);
      controller.goToNextActivity();
      _answerCurrentCorrectly(controller);
      controller.goToNextActivity();
      _answerCurrentCorrectly(controller);
      controller.goToNextActivity();

      controller.selectOption('true');
      expect(controller.submitAnswer(), isTrue);
      expect(controller.isCurrentAnswerCorrect, isTrue);
    });

    test('accepts sextorsion with accent and surrounding spaces', () {
      final controller = _controllerAtActivity('activity_6');

      controller.updateWrittenAnswer(' Sextorsión ');

      expect(controller.submitAnswer(), isTrue);
      expect(controller.isCurrentAnswerCorrect, isTrue);
    });

    test('accepts sextorsion without accent', () {
      final controller = _controllerAtActivity('activity_6');

      controller.updateWrittenAnswer('sextorsion');

      expect(controller.submitAnswer(), isTrue);
      expect(controller.isCurrentAnswerCorrect, isTrue);
    });

    test('rejects a partial fill blank answer', () {
      final controller = _controllerAtActivity('activity_6');

      controller.updateWrittenAnswer('sextor');

      expect(controller.submitAnswer(), isTrue);
      expect(controller.isCurrentAnswerCorrect, isFalse);
    });

    test('does not submit without a valid answer', () {
      final controller = QuizController(questions: _questions);

      expect(controller.canSubmitAnswer, isFalse);
      expect(controller.submitAnswer(), isFalse);
      expect(controller.isAnswerConfirmed, isFalse);
    });

    test('increments score by one per correct answer', () {
      final controller = QuizController(questions: _questions);

      _answerCurrentCorrectly(controller);
      expect(controller.correctAnswers, 1);

      controller.goToNextActivity();
      controller.selectOption('true');
      controller.submitAnswer();

      expect(controller.correctAnswers, 1);
    });

    test('advances to the next activity after confirmation', () {
      final controller = QuizController(questions: _questions);

      _answerCurrentCorrectly(controller);

      expect(controller.goToNextActivity(), isTrue);
      expect(controller.currentIndex, 1);
      expect(controller.currentQuestionId, 'activity_2');
      expect(controller.selectedOptionId, isNull);
      expect(controller.isAnswerConfirmed, isFalse);
    });

    test('finishes after twelve answered activities', () {
      final controller = QuizController(questions: _questions);

      _answerAllCorrectly(controller);

      expect(controller.isFinished, isTrue);
      expect(controller.correctAnswers, 12);
      expect(controller.quizResult.totalQuestions, 12);
    });

    test('resets the full quiz state', () {
      final controller = QuizController(questions: _questions);

      _answerAllCorrectly(controller);
      controller.reset();

      expect(controller.currentIndex, 0);
      expect(controller.selectedOptionId, isNull);
      expect(controller.writtenAnswer, isEmpty);
      expect(controller.isAnswerConfirmed, isFalse);
      expect(controller.isCurrentAnswerCorrect, isNull);
      expect(controller.correctAnswers, 0);
      expect(controller.isFinished, isFalse);
    });

    test('calculates percentage based on twelve questions', () {
      final controller = QuizController(questions: _questions);

      for (var index = 0; index < controller.totalQuestions; index += 1) {
        if (index < 6) {
          _answerCurrentCorrectly(controller);
        } else {
          _answerCurrentIncorrectly(controller);
        }
        if (!controller.isFinished) {
          controller.goToNextActivity();
        }
      }

      expect(controller.quizResult.correctAnswers, 6);
      expect(controller.quizResult.percentage, 50);
    });
  });
}

QuizController _controllerAtActivity(String activityId) {
  final controller = QuizController(questions: _questions);

  while (controller.currentQuestionId != activityId) {
    _answerCurrentCorrectly(controller);
    controller.goToNextActivity();
  }

  return controller;
}

void _answerAllCorrectly(QuizController controller) {
  while (!controller.isFinished) {
    _answerCurrentCorrectly(controller);
    if (!controller.isFinished) {
      controller.goToNextActivity();
    }
  }
}

void _answerCurrentCorrectly(QuizController controller) {
  final question = _questions[controller.currentIndex];

  switch (controller.currentQuestionType) {
    case QuestionType.multipleChoice:
    case QuestionType.trueFalse:
      controller.selectOption(question.correctAnswer);
    case QuestionType.fillBlank:
      controller.updateWrittenAnswer(question.correctAnswer);
  }

  controller.submitAnswer();
}

void _answerCurrentIncorrectly(QuizController controller) {
  final question = _questions[controller.currentIndex];

  switch (controller.currentQuestionType) {
    case QuestionType.multipleChoice:
    case QuestionType.trueFalse:
      final incorrectOption = controller.currentOptions.firstWhere(
        (option) => option.id != question.correctAnswer,
      );
      controller.selectOption(incorrectOption.id);
    case QuestionType.fillBlank:
      controller.updateWrittenAnswer('respuesta');
  }

  controller.submitAnswer();
}

const _questions = <QuizQuestion>[
  QuizQuestion(
    id: 'activity_1',
    type: QuestionType.multipleChoice,
    statement: '¿Cuál es un ejemplo de violencia digital?',
    options: <QuizOption>[
      QuizOption(
        id: 'control_passwords_threaten_messages',
        text: 'Controlar contraseñas y amenazar por mensajes.',
      ),
      QuizOption(id: 'update_application', text: 'Actualizar una aplicación.'),
    ],
    correctAnswer: 'control_passwords_threaten_messages',
    acceptedAnswers: <String>['control_passwords_threaten_messages'],
    feedback:
        'El control, la vigilancia y las amenazas mediante tecnología son '
        'formas de violencia.',
    capacity: 'reconocer',
    difficulty: 'básica',
  ),
  QuizQuestion(
    id: 'activity_2',
    type: QuestionType.trueFalse,
    statement:
        'La víctima es responsable de una difusión íntima por haber confiado.',
    options: <QuizOption>[
      QuizOption(id: 'true', text: 'Verdadero'),
      QuizOption(id: 'false', text: 'Falso'),
    ],
    correctAnswer: 'false',
    acceptedAnswers: <String>['false'],
    feedback:
        'La responsabilidad corresponde a quien difunde o amenaza con '
        'difundir el contenido sin consentimiento.',
    capacity: 'reconocer',
    difficulty: 'básica',
  ),
  QuizQuestion(
    id: 'activity_3',
    type: QuestionType.multipleChoice,
    statement: 'Ante amenazas digitales, ¿qué conviene hacer?',
    options: <QuizOption>[
      QuizOption(
        id: 'save_evidence_seek_support',
        text: 'Guardar evidencia y buscar apoyo.',
      ),
      QuizOption(id: 'give_passwords', text: 'Entregar contraseñas.'),
    ],
    correctAnswer: 'save_evidence_seek_support',
    acceptedAnswers: <String>['save_evidence_seek_support'],
    feedback:
        'Conservar pruebas y acudir a una red de apoyo facilita la protección.',
    capacity: 'responder',
    difficulty: 'intermedia',
  ),
  QuizQuestion(
    id: 'activity_4',
    type: QuestionType.multipleChoice,
    statement: 'Una pareja exige acceso permanente a tus cuentas.',
    options: <QuizOption>[
      QuizOption(id: 'digital_control', text: 'Control digital.'),
      QuizOption(id: 'security_test', text: 'Una prueba de seguridad.'),
    ],
    correctAnswer: 'digital_control',
    acceptedAnswers: <String>['digital_control'],
    feedback:
        'El afecto no justifica la vigilancia ni la pérdida de privacidad.',
    capacity: 'reconocer',
    difficulty: 'intermedia',
  ),
  QuizQuestion(
    id: 'activity_5',
    type: QuestionType.multipleChoice,
    statement: '¿Qué es grooming?',
    options: <QuizOption>[
      QuizOption(
        id: 'adult_manipulative_approach_minor_abuse',
        text: 'El acercamiento manipulador de una persona adulta.',
      ),
      QuizOption(id: 'profile_update', text: 'La actualización de un perfil.'),
    ],
    correctAnswer: 'adult_manipulative_approach_minor_abuse',
    acceptedAnswers: <String>['adult_manipulative_approach_minor_abuse'],
    feedback: 'Puede incluir secretos, presión o sexualización progresiva.',
    capacity: 'reconocer',
    difficulty: 'intermedia',
  ),
  QuizQuestion(
    id: 'activity_6',
    type: QuestionType.fillBlank,
    statement:
        'Amenazar con publicar contenido íntimo para exigir algo se llama.',
    options: <QuizOption>[],
    correctAnswer: 'sextorsión',
    acceptedAnswers: <String>['sextorsión', 'sextorsion'],
    feedback: 'No se recomienda pagar ni enfrentar la situación en soledad.',
    capacity: 'reconocer',
    difficulty: 'intermedia',
  ),
  QuizQuestion(
    id: 'activity_7',
    type: QuestionType.trueFalse,
    statement:
        'Compartir la ubicación en tiempo real con una persona controladora '
        'puede aumentar el riesgo.',
    options: <QuizOption>[
      QuizOption(id: 'true', text: 'Verdadero'),
      QuizOption(id: 'false', text: 'Falso'),
    ],
    correctAnswer: 'true',
    acceptedAnswers: <String>['true'],
    feedback: 'La ubicación puede utilizarse para vigilancia o seguimiento.',
    capacity: 'reconocer',
    difficulty: 'intermedia',
  ),
  QuizQuestion(
    id: 'activity_8',
    type: QuestionType.multipleChoice,
    statement: '¿Cuál es una respuesta adecuada ante el ciberacoso?',
    options: <QuizOption>[
      QuizOption(
        id: 'document_block_report_support',
        text: 'Documentar, bloquear, reportar y buscar apoyo.',
      ),
      QuizOption(id: 'accept_threats', text: 'Aceptar las amenazas.'),
    ],
    correctAnswer: 'document_block_report_support',
    acceptedAnswers: <String>['document_block_report_support'],
    feedback: 'La respuesta debe reducir el contacto y conservar pruebas.',
    capacity: 'responder',
    difficulty: 'básica',
  ),
  QuizQuestion(
    id: 'activity_9',
    type: QuestionType.fillBlank,
    statement: 'Las capturas, los enlaces y las fechas pueden servir como.',
    options: <QuizOption>[],
    correctAnswer: 'evidencia',
    acceptedAnswers: <String>['evidencia'],
    feedback: 'Conviene almacenar las pruebas de manera segura.',
    capacity: 'responder',
    difficulty: 'básica',
  ),
  QuizQuestion(
    id: 'activity_10',
    type: QuestionType.multipleChoice,
    statement:
        '¿Qué debes hacer si alguien amenaza con publicar fotos íntimas?',
    options: <QuizOption>[
      QuizOption(
        id: 'do_not_pay_save_evidence_seek_specialized_support',
        text: 'No pagar, guardar pruebas y buscar apoyo especializado.',
      ),
      QuizOption(id: 'send_more_photos', text: 'Enviar más fotos.'),
    ],
    correctAnswer: 'do_not_pay_save_evidence_seek_specialized_support',
    acceptedAnswers: <String>[
      'do_not_pay_save_evidence_seek_specialized_support',
    ],
    feedback: 'Pagar no garantiza que termine la amenaza.',
    capacity: 'responder',
    difficulty: 'intermedia',
  ),
  QuizQuestion(
    id: 'activity_11',
    type: QuestionType.multipleChoice,
    statement: '¿Qué práctica ayuda a protegerse de una expareja?',
    options: <QuizOption>[
      QuizOption(
        id: 'change_passwords_review_sessions_devices',
        text: 'Cambiar contraseñas y revisar sesiones y dispositivos.',
      ),
      QuizOption(id: 'keep_shared_passwords', text: 'Mantener contraseñas.'),
    ],
    correctAnswer: 'change_passwords_review_sessions_devices',
    acceptedAnswers: <String>['change_passwords_review_sessions_devices'],
    feedback: 'Es importante recuperar el control de las cuentas.',
    capacity: 'recuperar',
    difficulty: 'intermedia',
  ),
  QuizQuestion(
    id: 'activity_12',
    type: QuestionType.multipleChoice,
    statement: '¿Qué prioridad existe cuando hay riesgo físico inmediato?',
    options: <QuizOption>[
      QuizOption(
        id: 'emergency_help_safe_place',
        text: 'Buscar ayuda de emergencia y llegar a un lugar seguro.',
      ),
      QuizOption(id: 'confront_alone', text: 'Enfrentar a la persona a solas.'),
    ],
    correctAnswer: 'emergency_help_safe_place',
    acceptedAnswers: <String>['emergency_help_safe_place'],
    feedback:
        'La seguridad física está por encima de continuar una conversación.',
    capacity: 'responder',
    difficulty: 'intermedia',
  ),
];
