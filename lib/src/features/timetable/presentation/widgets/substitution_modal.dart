import 'package:flutter/material.dart';

import '../../data/timetable_models.dart';

class SubstitutionModal extends StatefulWidget {
  const SubstitutionModal({
    super.key,
    required this.className,
    required this.onRequestSubmitted,
  });

  final String className;
  final ValueChanged<FacultySubstitution> onRequestSubmitted;

  @override
  State<SubstitutionModal> createState() => _SubstitutionModalState();
}

class _SubstitutionModalState extends State<SubstitutionModal> {
  final _formKey = GlobalKey<FormState>();
  final _origFacultyCtrl = TextEditingController(text: 'Prof. Alan Turing');
  final _subFacultyCtrl = TextEditingController(text: 'Prof. Donald Knuth');
  final _subjectCodeCtrl = TextEditingController(text: 'CS302');
  final _subjectNameCtrl = TextEditingController(text: 'Operating Systems');
  final _timeSlotCtrl = TextEditingController(text: '09:30 - 10:20 AM');
  final _reasonCtrl = TextEditingController(text: 'Attending Academic Seminar');
  String _selectedDay = 'Monday';

  @override
  void dispose() {
    _origFacultyCtrl.dispose();
    _subFacultyCtrl.dispose();
    _subjectCodeCtrl.dispose();
    _subjectNameCtrl.dispose();
    _timeSlotCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final sub = FacultySubstitution(
      id: 'SUB-${DateTime.now().millisecondsSinceEpoch % 10000}',
      date: DateTime.now(),
      originalFaculty: _origFacultyCtrl.text.trim(),
      substituteFaculty: _subFacultyCtrl.text.trim(),
      className: widget.className,
      subjectCode: _subjectCodeCtrl.text.trim(),
      subjectName: _subjectNameCtrl.text.trim(),
      timeSlot: _timeSlotCtrl.text.trim(),
      dayOfWeek: _selectedDay,
      reason: _reasonCtrl.text.trim(),
      status: 'Pending',
    );

    widget.onRequestSubmitted(sub);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz, color: Color(0xFF00695C)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Request Faculty Substitution',
              softWrap: true,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _origFacultyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Original Faculty',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v!.isEmpty ? 'Enter original faculty' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _subFacultyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Substitute Faculty',
                  prefixIcon: Icon(Icons.person_add_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Enter substitute faculty' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subjectCodeCtrl,
                      decoration: const InputDecoration(labelText: 'Subject Code'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _subjectNameCtrl,
                      decoration: const InputDecoration(labelText: 'Subject Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDay,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday'
                      ]
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDay = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _timeSlotCtrl,
                      decoration: const InputDecoration(labelText: 'Time Slot'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for Substitution',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Enter reason' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00695C),
          ),
          onPressed: _submit,
          child: const Text('Submit Request'),
        ),
      ],
    );
  }
}
