import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_facing_error.dart';
import '../data/admin_student_repository.dart';

/// Chooses the shop counters one person works, right after they are given a
/// shop captain or owner role. Without a counter their queue stays empty and
/// every scan is refused, so the choice belongs in the same flow as the role.
///
/// Resolves to true when the counters were saved.
Future<bool?> showShopCounterSheet(
  BuildContext context, {
  required AdminStudentRepository repository,
  required String userId,
  required String userName,
  String defaultRole = 'captain',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ShopCounterSheet(
      repository: repository,
      userId: userId,
      userName: userName,
      defaultRole: defaultRole,
    ),
  );
}

class ShopCounterSheet extends StatefulWidget {
  const ShopCounterSheet({
    super.key,
    required this.repository,
    required this.userId,
    required this.userName,
    this.defaultRole = 'captain',
  });

  final AdminStudentRepository repository;
  final String userId;
  final String userName;

  /// Role a newly ticked shop starts with: owner for roles that run a menu.
  final String defaultRole;

  @override
  State<ShopCounterSheet> createState() => _ShopCounterSheetState();
}

class _ShopCounterSheetState extends State<ShopCounterSheet> {
  List<ShopCounterChoice>? _shops;

  /// Shop key to `owner` / `captain` for every ticked shop.
  final Map<String, String> _chosen = {};
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final shops = await widget.repository.loadShopCounters(widget.userId);
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _chosen
          ..clear()
          ..addAll({
            for (final shop in shops)
              if (shop.role != null) shop.shopKey: shop.role!,
          });
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveShopCounters(widget.userId, _chosen);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shops = _shops;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: p.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose counters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.userName} sees orders and can scan only at the shops '
            'ticked here. Captains run the queue; owners also manage the menu.',
            style: TextStyle(fontSize: 13.5, color: p.inkSecondary),
          ),
          const SizedBox(height: 12),
          if (shops == null && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (shops != null && shops.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No shops are set up yet. Add one in Vendors & shops.',
                style: TextStyle(fontSize: 14, color: p.inkSecondary),
              ),
            )
          else if (shops != null)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final shop in shops)
                    _CounterRow(
                      shop: shop,
                      parentName: [
                        for (final other in shops)
                          if (other.shopKey == shop.parentShopKey) other.name,
                      ].firstOrNull,
                      role: _chosen[shop.shopKey],
                      onToggle: (on) => setState(() {
                        if (on) {
                          _chosen[shop.shopKey] = widget.defaultRole;
                        } else {
                          _chosen.remove(shop.shopKey);
                        }
                      }),
                      onRole: (role) =>
                          setState(() => _chosen[shop.shopKey] = role),
                    ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: p.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Later'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving || shops == null ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save counters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.shop,
    required this.role,
    required this.onToggle,
    required this.onRole,
    this.parentName,
  });

  final ShopCounterChoice shop;

  /// The canteen [shop] is a counter of, by name.
  final String? parentName;

  /// Null when this shop is not ticked.
  final String? role;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onRole;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chosen = role != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox.adaptive(
            value: chosen,
            onChanged: (value) => onToggle(value ?? false),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggle(!chosen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: TextStyle(fontSize: 15, color: p.ink)),
                  Text(
                    parentName == null
                        ? shop.category
                        : 'Counter of $parentName',
                    style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (chosen)
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 'captain', label: Text('Captain')),
                ButtonSegment(value: 'owner', label: Text('Owner')),
              ],
              selected: {role!},
              onSelectionChanged: (value) => onRole(value.first),
            ),
        ],
      ),
    );
  }
}
