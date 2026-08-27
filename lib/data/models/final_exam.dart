class FinalExamConfig {
  const FinalExamConfig({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.questionCount,
    required this.order,
  });

  final String id;
  final String categoryId;
  final String title;
  final int questionCount;
  final int order;
}

abstract final class FinalExamConfigs {
  static const relationsViolence = FinalExamConfig(
    id: 'relations_violence_final_exam',
    categoryId: 'relations_violence_digital',
    title: 'Examen final',
    questionCount: 15,
    order: 7,
  );

  static FinalExamConfig? forCategory(String categoryId) {
    return switch (categoryId) {
      'relations_violence_digital' => relationsViolence,
      _ => null,
    };
  }
}
