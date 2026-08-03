import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/gatepass_models.dart';

class ApplyOutpassSheet extends StatefulWidget {
  const ApplyOutpassSheet({super.key, required this.onSubmit});

  final Future<GatepassRequest> Function(GatepassRequestDraft draft) onSubmit;

  @override
  State<ApplyOutpassSheet> createState() => _ApplyOutpassSheetState();
}

class _ApplyOutpassSheetState extends State<ApplyOutpassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _destination = TextEditingController();
  final _reason = TextEditingController();
  final _guardianPhone = TextEditingController(text: '9876543210');
  var _type = GatepassRequestType.localOuting;
  late DateTime _departure;
  late DateTime _returnAt;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _departure = DateTime(now.year, now.month, now.day + 1, 16);
    _returnAt = _departure.add(const Duration(hours: 4));
  }

  @override
  void dispose() {
    _destination.dispose();
    _reason.dispose();
    _guardianPhone.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool departure}) async {
    final initial = departure ? _departure : _returnAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (departure) {
        _departure = value;
        if (!_returnAt.isAfter(value)) {
          _returnAt = value.add(const Duration(hours: 2));
        }
      } else {
        _returnAt = value;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final request = await widget.onSubmit(
        GatepassRequestDraft(
          type: _type,
          departureAt: _departure,
          returnAt: _returnAt,
          destination: _destination.text,
          reason: _reason.text,
          guardianPhone: _guardianPhone.text,
        ),
      );
      if (mounted) Navigator.of(context).pop(request);
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
        title: const Text('Apply for outpass'),
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
                  Text(
                    'Pass type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<GatepassRequestType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.route),
                    ),
                    items: GatepassRequestType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _type = value ?? _type),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeField(
                          label: 'Departure',
                          value: _departure,
                          onTap: () => _pickDateTime(departure: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateTimeField(
                          label: 'Return',
                          value: _returnAt,
                          onTap: () => _pickDateTime(departure: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _destination,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter your destination.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reason,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 8
                        ? 'Enter at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _guardianPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Guardian phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) =>
                        RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Enter a 10-digit phone number.',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F0FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.gateBlue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your request is sent to the assigned approver. A gate QR is generated only after approval.',
                          ),
                        ),
                      ],
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
                        : const Text('Submit for approval'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
        ),
        child: Text('${formatShortDate(value)}\n${formatTime(value)}'),
      ),
    );
  }
}
