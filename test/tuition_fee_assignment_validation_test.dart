import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/screens/tuition_fee/tuition_fee_screen.dart';

void main() {
  group('assign fee sheet validation', () {
    test('a complete assignment has no field errors', () {
      final errors = validateFeeAssignment(
        hasStudent: true,
        title: 'Tuition fee',
        amount: '45000',
      );
      expect(errors.isValid, isTrue);
    });

    test('each missing field is reported on that field', () {
      final errors = validateFeeAssignment(
        hasStudent: false,
        title: '   ',
        amount: '',
      );
      expect(errors.isValid, isFalse);
      expect(errors.student, isNotNull);
      expect(errors.title, isNotNull);
      expect(errors.amount, 'Enter an amount.');
    });

    test('an amount below one rupee or not a number is rejected', () {
      for (final amount in ['0', '0.5', 'abc', '-10']) {
        final errors = validateFeeAssignment(
          hasStudent: true,
          title: 'Tuition fee',
          amount: amount,
        );
        expect(errors.amount, isNotNull, reason: amount);
        expect(errors.student, isNull);
        expect(errors.title, isNull);
      }
    });
  });
}
