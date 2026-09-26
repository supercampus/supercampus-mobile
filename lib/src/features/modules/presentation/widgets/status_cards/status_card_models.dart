import 'package:flutter/material.dart';

import '../../../../canteen/data/canteen_models.dart';
import '../../../../gatepass/data/gatepass_models.dart';
import 'academics_report_card.dart';
import 'announcement_notice_card.dart';
import 'fees_receipt_card.dart';
import 'food_order_card.dart';
import 'gatepass_ticket_card.dart';
import 'laundry_tag_card.dart';
import 'library_slip_card.dart';
import 'stationery_parcel_card.dart';
import 'timetable_schedule_card.dart';

/// Supported card types for the distinct module status cards.
enum StatusCardType {
  gatepass,
  foodOrder,
  academics,
  timetable,
  fees,
  library,
  stationery,
  laundry,
  announcement,
}

/// Base contract for all distinct status card view models.
abstract class StatusCardData {
  const StatusCardData();

  String get id;
  StatusCardType get type;
  String get moduleId;
  String? get action;

  Widget buildCard(BuildContext context, {required VoidCallback onTap});
}

// =============================================================================
// 1. GATEPASS TICKET MODEL
// =============================================================================
class GatepassTicketCardData extends StatusCardData {
  const GatepassTicketCardData({
    required this.id,
    this.title = 'your gatepass',
    required this.status,
    required this.validUntilText,
    this.qrPayload,
    this.destination,
    this.action = 'outpass',
  });

  @override
  final String id;
  final String title;
  final ApprovalStatus status;
  final String validUntilText;
  final String? qrPayload;
  final String? destination;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.gatepass;

  @override
  String get moduleId => 'gatepass';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      GatepassTicketCard(data: this, onTap: onTap);
}

// =============================================================================
// 2. FOOD ORDER TICKET MODEL
// =============================================================================
class FoodOrderCardData extends StatusCardData {
  const FoodOrderCardData({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.customMessage,
    this.imageUrl,
    this.itemName,
    this.action = 'orders',
  });

  @override
  final String id;
  final String orderNumber;
  final CanteenOrderStatus status;
  final String? customMessage;
  final String? imageUrl;
  final String? itemName;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.foodOrder;

  @override
  String get moduleId => 'canteen';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      FoodOrderCard(data: this, onTap: onTap);
}

// =============================================================================
// 3. ACADEMICS REPORT CARD MODEL
// =============================================================================
class AcademicsReportCardData extends StatusCardData {
  const AcademicsReportCardData({
    required this.id,
    required this.percentage,
    this.attendedClasses = 42,
    this.totalClasses = 60,
    this.requiredThreshold = 75,
    this.subtitle,
    this.action,
  });

  @override
  final String id;
  final int percentage;
  final int attendedClasses;
  final int totalClasses;
  final int requiredThreshold;
  final String? subtitle;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.academics;

  @override
  String get moduleId => 'academics';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      AcademicsReportCard(data: this, onTap: onTap);
}

// =============================================================================
// 4. TIMETABLE SCHEDULE MODEL
// =============================================================================
class TimetableScheduleCardData extends StatusCardData {
  const TimetableScheduleCardData({
    required this.id,
    required this.startTime,
    required this.subject,
    required this.room,
    this.faculty = '',
    this.isOngoing = false,
    this.isCompletedToday = false,
    this.countdownText,
    this.action,
  });

  @override
  final String id;
  final String startTime;
  final String subject;
  final String room;
  final String faculty;
  final bool isOngoing;
  final bool isCompletedToday;
  final String? countdownText;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.timetable;

  @override
  String get moduleId => 'timetable';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      TimetableScheduleCard(data: this, onTap: onTap);
}

// =============================================================================
// 5. FEES RECEIPT MODEL
// =============================================================================
class FeesReceiptCardData extends StatusCardData {
  const FeesReceiptCardData({
    required this.id,
    required this.pendingAmount,
    required this.category,
    required this.dueDateText,
    this.isOverdue = false,
    this.receiptNumber = 'REC-MEC-8492',
    this.action = 'dues',
  });

  @override
  final String id;
  final double pendingAmount;
  final String category;
  final String dueDateText;
  final bool isOverdue;
  final String receiptNumber;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.fees;

  @override
  String get moduleId => 'tuition_fee';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      FeesReceiptCard(data: this, onTap: onTap);
}

// =============================================================================
// 6. LIBRARY SLIP MODEL
// =============================================================================
enum LibrarySlipStatus { borrowed, dueSoon, overdue, returned }

class LibrarySlipCardData extends StatusCardData {
  const LibrarySlipCardData({
    required this.id,
    required this.bookTitle,
    required this.author,
    required this.returnDateText,
    this.status = LibrarySlipStatus.borrowed,
    this.coverUrl,
    this.action,
  });

  @override
  final String id;
  final String bookTitle;
  final String author;
  final String returnDateText;
  final LibrarySlipStatus status;
  final String? coverUrl;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.library;

  @override
  String get moduleId => 'library';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      LibrarySlipCard(data: this, onTap: onTap);
}

// =============================================================================
// 7. STATIONERY PARCEL MODEL
// =============================================================================
enum StationeryParcelStatus { processing, readyForPickup, collected }

class StationeryParcelCardData extends StatusCardData {
  const StationeryParcelCardData({
    required this.id,
    required this.orderNumber,
    required this.itemCount,
    required this.pickupLocation,
    this.status = StationeryParcelStatus.readyForPickup,
    this.trackingCode = 'PKG-MEC-4910',
    this.action = 'orders',
  });

  @override
  final String id;
  final String orderNumber;
  final int itemCount;
  final String pickupLocation;
  final StationeryParcelStatus status;
  final String trackingCode;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.stationery;

  @override
  String get moduleId => 'canteen';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      StationeryParcelCard(data: this, onTap: onTap);
}

// =============================================================================
// 8. LAUNDRY TAG MODEL
// =============================================================================
enum LaundryTagStatus { received, washing, ready, collected }

class LaundryTagCardData extends StatusCardData {
  const LaundryTagCardData({
    required this.id,
    required this.tokenNumber,
    required this.clothesCount,
    this.status = LaundryTagStatus.ready,
    this.pickupDeadline = 'Ready today by 5 PM',
    this.action = 'laundry',
  });

  @override
  final String id;
  final String tokenNumber;
  final int clothesCount;
  final LaundryTagStatus status;
  final String pickupDeadline;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.laundry;

  @override
  String get moduleId => 'canteen';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      LaundryTagCard(data: this, onTap: onTap);
}

// =============================================================================
// 9. ANNOUNCEMENT NOTICE MODEL
// =============================================================================
enum NoticeUrgency { normal, important, urgent }

class AnnouncementNoticeCardData extends StatusCardData {
  const AnnouncementNoticeCardData({
    required this.id,
    required this.headline,
    required this.department,
    required this.dateText,
    this.urgency = NoticeUrgency.normal,
    this.action,
  });

  @override
  final String id;
  final String headline;
  final String department;
  final String dateText;
  final NoticeUrgency urgency;
  @override
  final String? action;

  @override
  StatusCardType get type => StatusCardType.announcement;

  @override
  String get moduleId => 'library';

  @override
  Widget buildCard(BuildContext context, {required VoidCallback onTap}) =>
      AnnouncementNoticeCard(data: this, onTap: onTap);
}
