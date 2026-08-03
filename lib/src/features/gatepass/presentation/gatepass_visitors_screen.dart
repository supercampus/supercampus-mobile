import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/gatepass_models.dart';
import 'widgets/gatepass_ui.dart';

class GatepassVisitorsScreen extends StatelessWidget {
  const GatepassVisitorsScreen({
    super.key,
    required this.visitors,
    required this.onInvite,
  });

  final List<VisitorInvitation> visitors;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              GatepassPageHeader(
                title: 'Visitors',
                subtitle: 'Pre-schedule a campus visit',
                trailing: IconButton.filled(
                  tooltip: 'Invite visitor',
                  onPressed: onInvite,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.gateBlue,
                  ),
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF171719),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.gateLime,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Visitors must carry a government ID. Security verifies every approved invitation at entry.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final visitor in visitors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _VisitorCard(visitor: visitor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  const _VisitorCard({required this.visitor});

  final VisitorInvitation visitor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8E8EC)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: visitor.qrPayload == null ? null : () => _showPass(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFF1F0FF),
                    child: Text(
                      visitor.visitorName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.gateBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visitor.visitorName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(visitor.relationship),
                      ],
                    ),
                  ),
                  ApprovalPill(status: visitor.status),
                  if (visitor.qrPayload != null) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${formatShortDate(visitor.visitAt)}, ${formatTime(visitor.visitAt)}',
              ),
              const SizedBox(height: 5),
              Text(visitor.purpose),
              const SizedBox(height: 8),
              Text(
                visitor.id,
                style: const TextStyle(color: AppColors.gateBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPass(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF171719),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              visitor.visitorName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatShortDate(visitor.visitAt)}, ${formatTime(visitor.visitAt)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(data: visitor.qrPayload!, size: 210),
            ),
            const SizedBox(height: 14),
            Text(
              visitor.id,
              style: const TextStyle(
                color: AppColors.gateLime,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Share this pass with the visitor. Security will verify it with their ID at the gate.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class InviteVisitorSheet extends StatefulWidget {
  const InviteVisitorSheet({super.key, required this.onSubmit});

  final Future<VisitorInvitation> Function(VisitorInvitationDraft draft)
  onSubmit;

  @override
  State<InviteVisitorSheet> createState() => _InviteVisitorSheetState();
}

class _InviteVisitorSheetState extends State<InviteVisitorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relationship = TextEditingController();
  final _purpose = TextEditingController();
  late DateTime _visitAt;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visitAt = DateTime(now.year, now.month, now.day + 1, 11);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _pickVisitAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_visitAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _visitAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final invitation = await widget.onSubmit(
        VisitorInvitationDraft(
          visitorName: _name.text,
          phone: _phone.text,
          relationship: _relationship.text,
          purpose: _purpose.text,
          visitAt: _visitAt,
        ),
      );
      if (mounted) Navigator.of(context).pop(invitation);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Invite visitor'),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Visitor name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) =>
                        RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Enter a 10-digit phone number.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _relationship,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _purpose,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Purpose of visit',
                      alignLabelWithHint: true,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickVisitAt,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Visit date and time',
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(
                        '${formatShortDate(_visitAt)}, ${formatTime(_visitAt)}',
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gateBlue,
                    ),
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send invitation request'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'This field is required.' : null;
}
