import 'package:flutter/material.dart';

import '../models/task.dart';

const double pxPerHour = 60;
const double _minCardHeight = 40;
const double _maxCardHeight = 200;
const Color dullRed = Color(0xFFB98A8A);
const Color dullGreen = Color(0xFF8FAE8F);

bool isTaskOverdue(Task task, {required DateTime today}) {
  final due = task.dueDate;
  if (due == null) return false;
  return DateTime(due.year, due.month, due.day).isBefore(today);
}

class TaskCardStyle {
  final Color color;
  final double height;

  const TaskCardStyle({required this.color, required this.height});
}

/// Style for a task card in the unscheduled list: color communicates
/// overdue/estimate status, height is proportional to the time estimate
/// (clamped so cards stay usable in a scrolling list).
TaskCardStyle taskCardStyle(Task task, {required DateTime today}) {
  final overdue = isTaskOverdue(task, today: today);
  final hasEstimate = task.timeEstimate != null;

  final Color color;
  if (task.isCompleted) {
    color = dullGreen;
  } else if (overdue) {
    color = hasEstimate ? Colors.red : dullRed;
  } else {
    color = hasEstimate ? Colors.blue : Colors.grey;
  }

  double height = _minCardHeight;
  if (hasEstimate) {
    final hours = task.timeEstimate!.inMinutes / 60.0;
    height = (hours * pxPerHour).clamp(_minCardHeight, _maxCardHeight);
  }

  return TaskCardStyle(color: color, height: height);
}

/// Height for a task's block on the calendar, at the same px/hour scale as
/// the calendar grid. Unlike [taskCardStyle]'s height, this is not clamped
/// to a max so a block's size reflects its real duration.
double taskBlockHeight(Task task) {
  final estimate = task.timeEstimate;
  if (estimate == null) return _minCardHeight;
  return (estimate.inMinutes / 60.0) * pxPerHour;
}
