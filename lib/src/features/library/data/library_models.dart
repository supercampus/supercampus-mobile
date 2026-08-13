import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

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
    this.zoneName = 'Central Library - Reading Hall',
    this.seatNumber,
    this.description,
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
  final String zoneName;
  final String? seatNumber;
  final String? description;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;

  LibraryVisitPass copyWith({
    LibraryPassStatus? status,
    String? zoneName,
    String? seatNumber,
    String? description,
    DateTime? checkInAt,
    DateTime? checkOutAt,
  }) =>
      LibraryVisitPass(
        id: id,
        date: date,
        start: start,
        end: end,
        durationMinutes: durationMinutes,
        status: status ?? this.status,
        qrToken: qrToken,
        zoneName: zoneName ?? this.zoneName,
        seatNumber: seatNumber ?? this.seatNumber,
        description: description ?? this.description,
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

  Color get badgeColor => switch (this) {
    LibraryPassStatus.upcoming => AppColors.amber,
    LibraryPassStatus.active => AppColors.success,
    LibraryPassStatus.inside => AppColors.primary,
    LibraryPassStatus.used => AppColors.muted,
    LibraryPassStatus.expired => const Color(0xFFB71C1C),
    LibraryPassStatus.cancelled => const Color(0xFFB71C1C),
  };

  Color get badgeBackground => switch (this) {
    LibraryPassStatus.upcoming => const Color(0xFFFFF3D9),
    LibraryPassStatus.active => const Color(0xFFE8F5E9),
    LibraryPassStatus.inside => const Color(0xFFE3F2FD),
    LibraryPassStatus.used => const Color(0xFFF5F5F5),
    LibraryPassStatus.expired => const Color(0xFFFFEBEE),
    LibraryPassStatus.cancelled => const Color(0xFFFFEBEE),
  };

  Color get badgeColorDark => switch (this) {
    LibraryPassStatus.upcoming => const Color(0xFFFFD54F),
    LibraryPassStatus.active => const Color(0xFF81C784),
    LibraryPassStatus.inside => const Color(0xFF64B5F6),
    LibraryPassStatus.used => const Color(0xFF9E9E9E),
    LibraryPassStatus.expired => const Color(0xFFEF5350),
    LibraryPassStatus.cancelled => const Color(0xFFEF5350),
  };

  Color get badgeBackgroundDark => switch (this) {
    LibraryPassStatus.upcoming => const Color(0xFF3E2723),
    LibraryPassStatus.active => const Color(0xFF1B5E20).withValues(alpha: 0.3),
    LibraryPassStatus.inside => const Color(0xFF0D47A1).withValues(alpha: 0.3),
    LibraryPassStatus.used => const Color(0xFF424242).withValues(alpha: 0.3),
    LibraryPassStatus.expired => const Color(0xFFB71C1C).withValues(alpha: 0.3),
    LibraryPassStatus.cancelled => const Color(0xFFB71C1C).withValues(alpha: 0.3),
  };
}

class LibraryBookingSlot {
  const LibraryBookingSlot({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.zoneName = 'Central Library - Reading Hall',
    this.totalCapacity = 500,
    this.bookedCount = 0,
  });

  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String zoneName;
  final int totalCapacity;
  final int bookedCount;

  int get availableCount => (totalCapacity - bookedCount).clamp(0, totalCapacity);
  bool get isFull => availableCount <= 0;
}
