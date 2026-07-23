String formatEstimate(Duration estimate) {
  final days = estimate.inDays;
  final hours = estimate.inHours % 24;
  final minutes = estimate.inMinutes % 60;
  final parts = <String>[
    if (days > 0) '${days}d',
    if (hours > 0) '${hours}h',
    if (minutes > 0) '${minutes}m',
  ];
  return parts.isEmpty ? '0m' : parts.join(' ');
}
