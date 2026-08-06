import 'package:flutter/material.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../insight.dart';
import '../insight_source.dart';

/// Canteen wallet balance, weighted by how close it is to empty and by
/// whether it is nearly lunchtime — the same balance matters far more at
/// 12:30 than at 9pm.
class WalletBalanceSource implements InsightSource {
  const WalletBalanceSource({
    this.lowThreshold = 150,
    this.currencySymbol = '₹',
  });

  /// Below this the balance is treated as a problem worth surfacing.
  final double lowThreshold;
  final String currencySymbol;

  @override
  String get id => 'wallet_balance';

  @override
  bool isAvailable(EffectivePermissions permissions) => permissions.can(
    ModuleCatalog.canteen,
    'wallet',
    ModuleActions.read,
  );

  @override
  Insight? evaluate(InsightContext context) {
    final balance = context.walletBalance;
    if (balance == null) return null;

    final comfortable = lowThreshold * 3;
    final hour = context.now.hour;
    final nearLunch = hour >= 11 && hour < 14;

    var relevance = (1 - balance / comfortable).clamp(0.1, 0.95);
    if (nearLunch) relevance = (relevance + 0.15).clamp(0.0, 1.0);

    final tone = switch (balance) {
      final b when b < lowThreshold * 0.4 => InsightTone.urgent,
      final b when b < lowThreshold => InsightTone.caution,
      _ => InsightTone.neutral,
    };

    final String headline;
    if (balance < lowThreshold * 0.4) {
      headline = 'Wallet almost empty';
    } else if (balance < lowThreshold) {
      headline = nearLunch
          ? 'Low balance — top up before lunch'
          : 'Low balance in your canteen wallet';
    } else {
      headline = nearLunch ? 'Wallet ready for lunch' : 'Canteen wallet topped up';
    }

    final rounded = balance.round();

    return Insight(
      sourceId: id,
      relevance: relevance,
      headline: headline,
      supporting: '$currencySymbol$rounded available to spend',
      metric: InsightMetric(
        value: (balance / comfortable).clamp(0.0, 1.0),
        label: '$currencySymbol$rounded',
      ),
      icon: Icons.account_balance_wallet_outlined,
      tone: tone,
      signature: rounded.toString(),
    );
  }
}
