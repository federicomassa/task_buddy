import 'package:flutter/material.dart';

/// Shows a date picker, then a time picker, defaulting to 23:59 (end of day)
/// if no explicit time is chosen — so an unqualified due date means "end of
/// day", not midnight at the start of it.
Future<DateTime?> pickDueDateWithDefaultTime(
  BuildContext context, {
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime nowForTimeDefault,
}) async {
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: initialDate ?? nowForTimeDefault,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (pickedDate == null) return null;
  if (!context.mounted) return null;

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: initialDate != null
        ? TimeOfDay.fromDateTime(initialDate)
        : TimeOfDay.fromDateTime(nowForTimeDefault),
  );

  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime?.hour ?? 23,
    pickedTime?.minute ?? 59,
  );
}
