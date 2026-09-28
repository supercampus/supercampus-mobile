import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../data/security_gate_repository.dart';

/// Registers a visitor who arrived without an invitation and records their
/// gate-in at once. Pops the recorded movement.
class WalkInVisitorScreen extends StatefulWidget {
  const WalkInVisitorScreen({
    super.key,
    required this.repository,
    required this.checkpoint,
  });

  final SecurityGateRepository repository;
  final String checkpoint;

  @override
  State<WalkInVisitorScreen> createState() => _WalkInVisitorScreenState();
}

class _WalkInVisitorScreenState extends State<WalkInVisitorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _purpose = TextEditingController();
  final _host = TextEditingController();
  final _idNote = TextEditingController();
  final _vehicle = TextEditingController();
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _phone, _purpose, _host, _idNote, _vehicle]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final movement = await widget.repository.registerWalkIn(
        WalkInVisitorDraft(
          name: _name.text,
          phone: _phone.text,
          purpose: _purpose.text,
          hostName: _host.text,
          idNote: _idNote.text,
          vehicleNumber: _vehicle.text,
          checkpoint: widget.checkpoint,
        ),
      );
      if (mounted) Navigator.of(context).pop(movement);
    } on SecurityGateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The visitor could not be registered. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.surface,
      appBar: AppBar(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Walk-in visitor',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Text(
                'Register a visitor without a pass. Gate-in is recorded at ${widget.checkpoint} when you save.',
                style: TextStyle(color: p.inkSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              _field(
                key: 'walk-in-name',
                controller: _name,
                label: 'Visitor name',
                icon: Icons.person_outline_rounded,
                validator: WalkInValidation.name,
                capitalization: TextCapitalization.words,
              ),
              _field(
                key: 'walk-in-phone',
                controller: _phone,
                label: 'Phone number',
                icon: Icons.phone_outlined,
                validator: WalkInValidation.phone,
                keyboardType: TextInputType.phone,
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()\-]')),
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
              _field(
                key: 'walk-in-purpose',
                controller: _purpose,
                label: 'Purpose of visit',
                icon: Icons.assignment_outlined,
                validator: WalkInValidation.purpose,
                capitalization: TextCapitalization.sentences,
              ),
              _field(
                key: 'walk-in-host',
                controller: _host,
                label: 'Meeting (person or office)',
                icon: Icons.meeting_room_outlined,
                validator: WalkInValidation.host,
                capitalization: TextCapitalization.words,
              ),
              _field(
                key: 'walk-in-id-note',
                controller: _idNote,
                label: 'ID note (optional)',
                hint: 'e.g. Aadhaar shown, ends 4821',
                icon: Icons.badge_outlined,
                validator: WalkInValidation.idNote,
              ),
              _field(
                key: 'walk-in-vehicle',
                controller: _vehicle,
                label: 'Vehicle number (optional)',
                icon: Icons.directions_car_outlined,
                validator: WalkInValidation.vehicle,
                capitalization: TextCapitalization.characters,
                action: TextInputAction.done,
              ),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: p.dangerSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_error!, style: TextStyle(color: p.danger)),
                ),
              ],
              const SizedBox(height: 6),
              FilledButton(
                key: const ValueKey('walk-in-submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: p.brand,
                  foregroundColor: p.onBrand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _submitting ? 'Registering…' : 'Register and gate in',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FormFieldValidator<String> validator,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
  }) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        enabled: !_submitting,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        textCapitalization: capitalization,
        textInputAction: action,
        onFieldSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: p.surfaceSunken,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.brand, width: 1.5),
          ),
        ),
      ),
    );
  }
}
