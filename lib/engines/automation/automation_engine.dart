/// Captured Hive workflows that can be listed or replayed later.
class AutomationRecipe {
  AutomationRecipe({
    required this.id,
    required this.name,
    required this.steps,
    required this.artifactFileName,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now().toUtc();

  final String id;
  final String name;
  final List<String> steps;
  final String artifactFileName;
  final DateTime recordedAt;
}

/// Automation engine: records finished multi-agent build workflows.
class AutomationEngine {
  final List<AutomationRecipe> _recipes = [];

  List<AutomationRecipe> get recipes => List.unmodifiable(_recipes);

  void record(AutomationRecipe recipe) {
    _recipes.removeWhere((existing) => existing.id == recipe.id);
    _recipes.add(
      AutomationRecipe(
        id: recipe.id,
        name: recipe.name,
        steps: recipe.steps,
        artifactFileName: recipe.artifactFileName,
        recordedAt: recipe.recordedAt,
      ),
    );
  }
}
