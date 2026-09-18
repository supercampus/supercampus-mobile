import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/gatepass_models.dart';

class ApplyOutpassSheet extends StatefulWidget {
  const ApplyOutpassSheet({
    super.key,
    required this.onSubmit,
    required this.passKind,
    required this.student,
  });

  final Future<GatepassRequest> Function(GatepassRequestDraft draft) onSubmit;
  final GatepassPassKind passKind;
  final GatepassStudent student;

  @override
  State<ApplyOutpassSheet> createState() => _ApplyOutpassSheetState();
}

class _ApplyOutpassSheetState extends State<ApplyOutpassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tooltipKey = GlobalKey<TooltipState>();
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
    final leave = widget.passKind == GatepassPassKind.leavePass;
    _type = leave
        ? GatepassRequestType.medical
        : GatepassRequestType.localOuting;
    _departure = leave
        ? now.add(const Duration(minutes: 15))
        : DateTime(now.year, now.month, now.day + 1, 16);
    _returnAt = leave
        ? _departure.add(const Duration(hours: 2))
        : _departure.add(const Duration(hours: 4));
    if (leave) {
      _destination.text = widget.student.residency == StudentResidency.hosteller
          ? 'Hostel'
          : 'Home';
    }
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
    if (!_returnAt.isAfter(_departure)) {
      setState(
        () => _error = widget.passKind == GatepassPassKind.leavePass
            ? 'The "To" time must be after the "From" time.'
            : 'Return time must be after departure time.',
      );
      return;
    }
    if (widget.passKind == GatepassPassKind.leavePass &&
        (_departure.year != _returnAt.year ||
            _departure.month != _returnAt.month ||
            _departure.day != _returnAt.day)) {
      setState(
        () => _error =
            'Leave pass must start and finish on the same college day.',
      );
      return;
    }
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
          passKind: widget.passKind,
          residency: widget.student.residency,
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
    final isLeavePass = widget.passKind == GatepassPassKind.leavePass;
    final infoMessage = isLeavePass
        ? 'Advisor / HOD approval is followed by principal approval. Security scans the QR before you exit. Hostellers go to the hostel; day scholars go home.'
        : 'Outpass is only for hostellers. Parent consent is followed by warden approval before the gate QR is generated.';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Apply for ${widget.passKind.label.toLowerCase()}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              key: _tooltipKey,
              message: infoMessage,
              triggerMode: TooltipTriggerMode.tap,
              preferBelow: true,
              showDuration: const Duration(seconds: 6),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _tooltipKey.currentState?.ensureTooltipVisible();
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
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
                  if (widget.passKind == GatepassPassKind.outpass) ...[
                    Text(
                      'Outpass type',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 9),
                    DropdownButtonFormField<GatepassRequestType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.route),
                      ),
                      items:
                          const [
                                GatepassRequestType.localOuting,
                                GatepassRequestType.homeVisit,
                              ]
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
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeField(
                          label: isLeavePass ? 'From' : 'Departure',
                          value: _departure,
                          onTap: () => _pickDateTime(departure: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateTimeField(
                          label: isLeavePass ? 'To' : 'Return',
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
                  if (widget.passKind == GatepassPassKind.outpass) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _guardianPhone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Guardian phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) =>
                          RegExp(r'^\+?\d{8,15}$').hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Enter a valid phone number.',
                    ),
                  ],
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
