import '../../../../authentication/data/auth_repository.dart';
import '../../../../canteen/data/canteen_models.dart';
import '../../../../gatepass/data/gatepass_models.dart';
import '../../../../library/data/librarian_repository.dart';
import '../../today_glance.dart';
import 'status_card_models.dart';

/// Pure mapping builder that transforms live store, glance facts, and announcements
/// into strongly typed [StatusCardData] instances for the student status carousel.
List<StatusCardData> buildStudentStatusCards({
  CanteenStore? store,
  GlanceFacts? glance,
  List<LibraryAnnouncement>? announcements,
  UserSession? session,
}) {
  final cards = <StatusCardData>[];

  // ---------------------------------------------------------------------------
  // 1. Food Orders (Kitchen Order Slip)
  // ---------------------------------------------------------------------------
  if (store != null && store.orders.isNotEmpty) {
    final activeOrders = store.orders.where((o) => o.status.isActive).toList();
    if (activeOrders.isNotEmpty) {
      for (final order in activeOrders.take(2)) {
        cards.add(
          FoodOrderCardData(
            id: 'order-${order.id}',
            orderNumber: order.displayId,
            status: order.status,
            itemName: order.lines.firstOrNull?.item.name,
            imageUrl: order.lines.firstOrNull?.item.imageUrl,
          ),
        );
      }
    } else {
      final latest = store.orders.first;
      cards.add(
        FoodOrderCardData(
          id: 'order-${latest.id}',
          orderNumber: latest.displayId,
          status: latest.status,
          itemName: latest.lines.firstOrNull?.item.name,
          imageUrl: latest.lines.firstOrNull?.item.imageUrl,
        ),
      );
    }
  } else {
    // Default preview order matching reference design
    cards.add(
      const FoodOrderCardData(
        id: 'order-1275',
        orderNumber: '1275',
        status: CanteenOrderStatus.preparing,
        itemName: 'Classic Thali',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Gatepass (Admission / Exit Ticket)
  // ---------------------------------------------------------------------------
  final gpActivity = glance?.activities
      .where((a) => a.kind == StudentActivityKind.gatepass)
      .firstOrNull;

  final qrPayload = glance?.gatepassQr ?? 'MEC-GP-PASS-8842';
  if (gpActivity != null) {
    cards.add(
      GatepassTicketCardData(
        id: gpActivity.id,
        title: gpActivity.title.toLowerCase().contains('gatepass')
            ? gpActivity.title.toLowerCase()
            : 'your gatepass',
        status: gpActivity.statusLabel?.toLowerCase().contains('pending') == true
            ? ApprovalStatus.pending
            : ApprovalStatus.approved,
        validUntilText: gpActivity.supporting.isNotEmpty
            ? gpActivity.supporting.toUpperCase()
            : 'VALID UNTIL 09:30 PM',
        destination: 'Campus Exit',
        qrPayload: qrPayload,
      ),
    );
  } else {
    cards.add(
      GatepassTicketCardData(
        id: 'gp-current',
        title: 'your gatepass',
        status: ApprovalStatus.approved,
        validUntilText: 'VALID UNTIL 09:30 PM',
        destination: 'City Center',
        qrPayload: qrPayload,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Academics (Report Card / Marksheet)
  // ---------------------------------------------------------------------------
  final standing = glance?.standing;
  if (standing != null && !standing.isUnrecorded) {
    final pct = standing.percentage;
    final sub = pct >= 75
        ? 'Good standing (above 75%)'
        : '${((75 * standing.total - 100 * standing.attended) / 25).ceil().clamp(1, 20)} classes needed for 75%';
    cards.add(
      AcademicsReportCardData(
        id: 'acad-standing',
        percentage: pct,
        attendedClasses: standing.attended,
        totalClasses: standing.total,
        requiredThreshold: 75,
        subtitle: sub,
      ),
    );
  } else {
    cards.add(
      const AcademicsReportCardData(
        id: 'acad-demo',
        percentage: 82,
        attendedClasses: 49,
        totalClasses: 60,
        requiredThreshold: 75,
        subtitle: 'Above the 75% threshold',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Timetable (Digital Schedule Display)
  // ---------------------------------------------------------------------------
  final todayClass = glance?.classes.firstOrNull;
  final ttActivity = glance?.activities
      .where((a) => a.kind == StudentActivityKind.timetable)
      .firstOrNull;

  if (todayClass != null) {
    cards.add(
      TimetableScheduleCardData(
        id: 'tt-${todayClass.timetableEntryId}',
        startTime: todayClass.periodLabel.isNotEmpty
            ? todayClass.periodLabel
            : '10:00 AM',
        subject: todayClass.subject,
        room: todayClass.section.isNotEmpty
            ? 'Room ${todayClass.section}'
            : 'Lecture Hall 2',
        isOngoing: !todayClass.rollTaken,
        countdownText: todayClass.rollTaken ? 'Completed' : 'Next up',
      ),
    );
  } else if (ttActivity != null) {
    cards.add(
      TimetableScheduleCardData(
        id: ttActivity.id,
        startTime: '10:00 AM',
        subject: ttActivity.title,
        room: ttActivity.supporting.isNotEmpty
            ? ttActivity.supporting
            : 'Room 304',
        countdownText: ttActivity.statusLabel,
      ),
    );
  } else {
    cards.add(
      const TimetableScheduleCardData(
        id: 'tt-demo',
        startTime: '10:00 AM',
        subject: 'Data Structures & Algorithms',
        room: 'Lab 3, CS Block',
        faculty: 'Dr. Ramesh Kumar',
        countdownText: 'Starts in 15 mins',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Fees (Printed Cashier Receipt)
  // ---------------------------------------------------------------------------
  final feeActivity = glance?.activities
      .where((a) => a.kind == StudentActivityKind.fees)
      .firstOrNull;

  if (feeActivity != null) {
    cards.add(
      FeesReceiptCardData(
        id: feeActivity.id,
        pendingAmount: 12500,
        category: feeActivity.title,
        dueDateText: feeActivity.supporting.isNotEmpty
            ? feeActivity.supporting
            : 'DUE 15 OCT 2026',
        receiptNumber: 'REC-MEC-8492',
      ),
    );
  } else {
    cards.add(
      const FeesReceiptCardData(
        id: 'fee-demo',
        pendingAmount: 12500,
        category: 'Semester Tuition (Term II)',
        dueDateText: 'DUE 15 OCT 2026',
        receiptNumber: 'REC-MEC-8492',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Library (Paper Circulation Slip)
  // ---------------------------------------------------------------------------
  final libActivity = glance?.activities
      .where((a) => a.kind == StudentActivityKind.library)
      .firstOrNull;

  if (libActivity != null) {
    cards.add(
      LibrarySlipCardData(
        id: libActivity.id,
        bookTitle: libActivity.title,
        author: libActivity.supporting.isNotEmpty
            ? libActivity.supporting
            : 'MEC Central Library',
        returnDateText: libActivity.statusLabel ?? 'RETURN BY 28 SEP',
        status: LibrarySlipStatus.borrowed,
      ),
    );
  } else {
    cards.add(
      const LibrarySlipCardData(
        id: 'lib-demo',
        bookTitle: 'Clean Code: Handbook of Agile Software',
        author: 'Robert C. Martin',
        returnDateText: 'RETURN BY 28 SEP 2026',
        status: LibrarySlipStatus.borrowed,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Stationery (Parcel Shipping Label)
  // ---------------------------------------------------------------------------
  final stationeryOrder = store?.orders
      .where(
        (o) => o.lines.any(
          (l) =>
              l.item.store == MenuStore.stationery ||
              l.item.shopKey == 'stationery',
        ),
      )
      .firstOrNull;

  if (stationeryOrder != null) {
    final totalItems = stationeryOrder.lines.fold<int>(
      0,
      (sum, l) => sum + l.quantity,
    );
    cards.add(
      StationeryParcelCardData(
        id: 'stat-${stationeryOrder.id}',
        orderNumber: stationeryOrder.displayId,
        itemCount: totalItems,
        pickupLocation: 'Desk #1, Stationery Store',
        status: stationeryOrder.status == CanteenOrderStatus.ready
            ? StationeryParcelStatus.readyForPickup
            : StationeryParcelStatus.processing,
      ),
    );
  } else {
    cards.add(
      const StationeryParcelCardData(
        id: 'stat-demo',
        orderNumber: '0418',
        itemCount: 3,
        pickupLocation: 'Desk #2, Ground Floor',
        status: StationeryParcelStatus.readyForPickup,
        trackingCode: 'PKG-MEC-4910',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. Laundry (Dry-cleaner Claim Tag)
  // ---------------------------------------------------------------------------
  final unpaidCharge = store?.laundryCharges
          .where((c) => c.status != LaundryChargeStatus.paid)
          .firstOrNull ??
      store?.laundryCharges.firstOrNull;

  if (unpaidCharge != null) {
    cards.add(
      LaundryTagCardData(
        id: 'laundry-${unpaidCharge.id}',
        tokenNumber:
            'L-${unpaidCharge.id.substring(0, unpaidCharge.id.length.clamp(0, 4)).toUpperCase()}',
        clothesCount: unpaidCharge.quantity.toInt().clamp(1, 99),
        status: unpaidCharge.status == LaundryChargeStatus.paid
            ? LaundryTagStatus.ready
            : LaundryTagStatus.washing,
        pickupDeadline: 'Ready today by 5 PM',
      ),
    );
  } else {
    cards.add(
      const LaundryTagCardData(
        id: 'laundry-demo',
        tokenNumber: 'L-204',
        clothesCount: 6,
        status: LaundryTagStatus.ready,
        pickupDeadline: 'Ready today by 5 PM',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 9. Announcement (Pinned Bulletin Notice)
  // ---------------------------------------------------------------------------
  final ann = announcements?.firstOrNull;
  if (ann != null) {
    cards.add(
      AnnouncementNoticeCardData(
        id: 'ann-${ann.id}',
        headline: ann.title,
        department: ann.createdByName.isNotEmpty
            ? ann.createdByName
            : 'Dean of Academics',
        dateText:
            '${ann.announcementDate.day}/${ann.announcementDate.month}/${ann.announcementDate.year}',
        urgency: NoticeUrgency.important,
      ),
    );
  } else {
    cards.add(
      const AnnouncementNoticeCardData(
        id: 'ann-demo',
        headline: 'Mid-term schedule published for Semester IV',
        department: 'Academic Council',
        dateText: '26 Sep 2026',
        urgency: NoticeUrgency.important,
      ),
    );
  }

  return cards;
}
