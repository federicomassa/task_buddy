import '../models/task.dart';
import '../models/user_settings.dart';

enum EisenhowerQuadrant { importantUrgent, urgentOnly, importantOnly, neither }

EisenhowerQuadrant quadrantOf(Task task) {
  if (task.isImportant && task.isUrgent) return EisenhowerQuadrant.importantUrgent;
  if (task.isUrgent) return EisenhowerQuadrant.urgentOnly;
  if (task.isImportant) return EisenhowerQuadrant.importantOnly;
  return EisenhowerQuadrant.neither;
}

int priorityWeight(EisenhowerQuadrant quadrant, WsjfWeights weights) {
  switch (quadrant) {
    case EisenhowerQuadrant.importantUrgent:
      return weights.importantUrgent;
    case EisenhowerQuadrant.urgentOnly:
      return weights.urgentOnly;
    case EisenhowerQuadrant.importantOnly:
      return weights.importantOnly;
    case EisenhowerQuadrant.neither:
      return weights.neither;
  }
}

/// Weighted Shortest Job First score: priority weight divided by duration in
/// minutes, so higher-priority and shorter tasks score higher. Null if the
/// task has no time estimate yet, since the score is undefined until then.
double? wsjfScore(Task task, WsjfWeights weights) {
  final estimate = task.timeEstimate;
  if (estimate == null || estimate.inMinutes <= 0) return null;
  return priorityWeight(quadrantOf(task), weights) / estimate.inMinutes;
}
