enum LibraryPassStatus { upcoming, active, inside, used, expired, cancelled }

class LibraryVisitPass {
  const LibraryVisitPass({
    required this.id,
    required this.date,
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.status,
    required this.qrToken,
    this.checkInAt,
    this.checkOutAt,
  });

  final String id;
  final DateTime date;
  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final LibraryPassStatus status;
  final String qrToken;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;

  LibraryVisitPass copyWith({
    LibraryPassStatus? status,
    DateTime? checkInAt,
    DateTime? checkOutAt,
  }) => LibraryVisitPass(
    id: id,
    date: date,
    start: start,
    end: end,
    durationMinutes: durationMinutes,
    status: status ?? this.status,
    qrToken: qrToken,
    checkInAt: checkInAt ?? this.checkInAt,
    checkOutAt: checkOutAt ?? this.checkOutAt,
  );
}

extension LibraryPassStatusLabel on LibraryPassStatus {
  String get label => switch (this) {
    LibraryPassStatus.upcoming => 'Upcoming',
    LibraryPassStatus.active => 'Active',
    LibraryPassStatus.inside => 'Inside',
    LibraryPassStatus.used => 'Completed',
    LibraryPassStatus.expired => 'Expired',
    LibraryPassStatus.cancelled => 'Cancelled',
  };
}
