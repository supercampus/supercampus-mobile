import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/academics_report_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/announcement_notice_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/fees_receipt_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/food_order_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/gatepass_ticket_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/laundry_tag_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/library_slip_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/stationery_parcel_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/status_card_builder.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/status_card_carousel.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/status_card_models.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/timetable_schedule_card.dart';

void main() {
  group('Status Card Builder', () {
    test('builds all 9 distinctive status card variants with fallbacks', () {
      final cards = buildStudentStatusCards();
      expect(cards.length, 9);

      final types = cards.map((c) => c.type).toSet();
      expect(types, contains(StatusCardType.foodOrder));
      expect(types, contains(StatusCardType.gatepass));
      expect(types, contains(StatusCardType.academics));
      expect(types, contains(StatusCardType.timetable));
      expect(types, contains(StatusCardType.fees));
      expect(types, contains(StatusCardType.library));
      expect(types, contains(StatusCardType.stationery));
      expect(types, contains(StatusCardType.laundry));
      expect(types, contains(StatusCardType.announcement));
    });
  });

  group('Food Order Card Widget', () {
    testWidgets('renders order number, status pill, and dynamic message correctly', (
      tester,
    ) async {
      var tapped = false;
      const data = FoodOrderCardData(
        id: 'order-1275',
        orderNumber: '1275',
        status: CanteenOrderStatus.preparing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodOrderCard(
              data: data,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('your order #1275 is'), findsOneWidget);
      expect(find.text('preparing'), findsOneWidget);
      expect(
        find.text('please wait until your order is ready to serve'),
        findsOneWidget,
      );

      await tester.tap(find.byType(FoodOrderCard));
      expect(tapped, isTrue);
    });
  });

  group('Gatepass Ticket Card Widget', () {
    testWidgets('renders ticket with validity, status pill, and QR', (
      tester,
    ) async {
      var tapped = false;
      const data = GatepassTicketCardData(
        id: 'gp-101',
        status: ApprovalStatus.approved,
        validUntilText: 'VALID UNTIL 09:30 PM',
        destination: 'City Center',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GatepassTicketCard(
              data: data,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('your gatepass'), findsOneWidget);
      expect(find.text('approved'), findsOneWidget);
      expect(find.text('VALID UNTIL 09:30 PM'), findsOneWidget);

      await tester.tap(find.byType(GatepassTicketCard));
      expect(tapped, isTrue);
    });
  });

  group('Academics Report Card Widget', () {
    testWidgets('renders attendance percentage hero and threshold', (
      tester,
    ) async {
      const data = AcademicsReportCardData(
        id: 'acad-1',
        percentage: 82,
        attendedClasses: 49,
        totalClasses: 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademicsReportCard(
              data: data,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('82%'), findsOneWidget);
      expect(
        find.text('49 of 60 classes attended · Min 75%'),
        findsOneWidget,
      );
    });
  });

  group('Timetable Schedule Card Widget', () {
    testWidgets('renders lecture time, room, and subject', (tester) async {
      const data = TimetableScheduleCardData(
        id: 'tt-1',
        startTime: '10:00 AM',
        subject: 'Data Structures & Algorithms',
        room: 'Lab 3, CS Block',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimetableScheduleCard(
              data: data,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('Data Structures & Algorithms'), findsOneWidget);
      expect(find.text('Lab 3, CS Block'), findsOneWidget);
    });
  });

  group('Fees Receipt Card Widget', () {
    testWidgets('renders outstanding amount and receipt details', (
      tester,
    ) async {
      const data = FeesReceiptCardData(
        id: 'fee-1',
        pendingAmount: 12500,
        category: 'Semester Tuition (Term II)',
        dueDateText: 'DUE 15 OCT 2026',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeesReceiptCard(
              data: data,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('₹12500'), findsOneWidget);
      expect(find.text('Semester Tuition (Term II)'), findsOneWidget);
      expect(find.text('DUE 15 OCT 2026'), findsOneWidget);
    });
  });

  group('Library Slip Card Widget', () {
    testWidgets('renders circulation slip with return date stamp', (
      tester,
    ) async {
      const data = LibrarySlipCardData(
        id: 'lib-1',
        bookTitle: 'Clean Code: Handbook of Agile Software',
        author: 'Robert C. Martin',
        returnDateText: 'RETURN BY 28 SEP 2026',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibrarySlipCard(
              data: data,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Clean Code: Handbook of Agile Software'), findsOneWidget);
      expect(find.text('Robert C. Martin'), findsOneWidget);
      expect(find.text('RETURN BY 28 SEP 2026'), findsOneWidget);
    });
  });

  group('Stationery Parcel Card Widget', () {
    testWidgets('renders parcel label with order number and item count', (
      tester,
    ) async {
      const data = StationeryParcelCardData(
        id: 'stat-1',
        orderNumber: '0418',
        itemCount: 3,
        pickupLocation: 'Desk #2, Ground Floor',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StationeryParcelCard(
              data: data,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Your stationery order #0418'), findsOneWidget);
      expect(find.text('3 items · Desk #2, Ground Floor'), findsOneWidget);
    });
  });

  group('Laundry Tag Card Widget', () {
    testWidgets('renders claim tag with token and clothes count', (
      tester,
    ) async {
      const data = LaundryTagCardData(
        id: 'laundry-1',
        tokenNumber: 'L-204',
        clothesCount: 6,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LaundryTagCard(
              data: data,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('TOKEN #L-204'), findsOneWidget);
      expect(find.text('6 CLOTHES'), findsOneWidget);
    });
  });

  group('Announcement Notice Card Widget', () {
    testWidgets('renders pinned bulletin notice with headline and department', (
      tester,
    ) async {
      const data = AnnouncementNoticeCardData(
        id: 'ann-1',
        headline: 'Mid-term schedule published for Semester IV',
        department: 'Academic Council',
        dateText: '26 Sep 2026',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementNoticeCard(
              data: data,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('Mid-term schedule published for Semester IV'),
        findsOneWidget,
      );
      expect(find.text('COLLEGE BULLETIN · ACADEMIC COUNCIL'), findsOneWidget);
      expect(find.text('Published 26 Sep 2026'), findsOneWidget);
    });
  });

  group('Status Card Carousel Widget', () {
    testWidgets('swipes between cards and notifies tap with typed data', (
      tester,
    ) async {
      StatusCardData? selected;
      final cards = buildStudentStatusCards();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusCardCarousel(
              cards: cards,
              onCardTap: (c) => selected = c,
            ),
          ),
        ),
      );

      // Verify first card is visible
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(FoodOrderCard), findsOneWidget);

      // Tap first card
      await tester.tap(find.byType(FoodOrderCard));
      expect(selected, isNotNull);
      expect(selected!.type, StatusCardType.foodOrder);

      // Swipe to next card
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Second card (Gatepass) should now be in view
      expect(find.byType(GatepassTicketCard), findsOneWidget);
    });
  });
}
