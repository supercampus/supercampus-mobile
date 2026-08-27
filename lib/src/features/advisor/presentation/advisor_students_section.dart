import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton_loading.dart';
import '../data/advisor_students_repository.dart';

class AdvisorStudentsSection extends StatefulWidget {
  const AdvisorStudentsSection({super.key, required this.source});

  final AdvisorStudentsSource source;

  @override
  State<AdvisorStudentsSection> createState() => _AdvisorStudentsSectionState();
}

class _AdvisorStudentsSectionState extends State<AdvisorStudentsSection> {
  List<AdvisorStudent>? _students;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final students = await widget.source.loadStudents();
      if (mounted) setState(() => _students = students);
    } catch (_) {
      if (mounted) setState(() => _error = 'Your student list is unavailable.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Your students',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (students != null)
                Text(
                  '${students.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(_error!),
          )
        else if (students == null)
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) => const SkeletonBox(
                width: 126,
                height: 142,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          )
        else if (students.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('No students are assigned to you yet.'),
          )
        else
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _StudentMiniCard(
                student: students[index],
                onTap: () =>
                    _showStudent(context, widget.source, students[index]),
              ),
            ),
          ),
      ],
    );
  }
}

class _StudentMiniCard extends StatelessWidget {
  const _StudentMiniCard({required this.student, required this.onTap});

  final AdvisorStudent student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 126,
    child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentAvatar(student: student, radius: 26),
              const Spacer(),
              Text(
                student.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                student.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                student.departmentCode,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({required this.student, required this.radius});
  final AdvisorStudent student;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = student.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundImage: url == null ? null : NetworkImage(url),
      child: url == null
          ? Text(
              student.name
                  .split(RegExp(r'\s+'))
                  .where((part) => part.isNotEmpty)
                  .take(2)
                  .map((part) => part[0])
                  .join()
                  .toUpperCase(),
            )
          : null,
    );
  }
}

void _showStudent(
  BuildContext context,
  AdvisorStudentsSource source,
  AdvisorStudent student,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .82,
      minChildSize: .5,
      maxChildSize: .94,
      builder: (context, controller) => _StudentDetailsSheet(
        source: source,
        student: student,
        controller: controller,
      ),
    ),
  );
}

class _StudentDetailsSheet extends StatefulWidget {
  const _StudentDetailsSheet({
    required this.source,
    required this.student,
    required this.controller,
  });

  final AdvisorStudentsSource source;
  final AdvisorStudent student;
  final ScrollController controller;

  @override
  State<_StudentDetailsSheet> createState() => _StudentDetailsSheetState();
}

class _StudentDetailsSheetState extends State<_StudentDetailsSheet> {
  List<AdvisorAssessment>? _assessments;
  String? _assessmentError;

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    try {
      final values = await widget.source.loadAssessments(
        widget.student.studentId,
      );
      if (mounted) {
        setState(() {
          _assessments = values;
          _assessmentError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _assessmentError = 'Assessment marks are unavailable.');
      }
    }
  }

  Future<void> _editAssessment({
    AdvisorAssessment? assessment,
    AdvisorAssessmentKind? kind,
  }) async {
    final input = await showDialog<AdvisorAssessmentInput>(
      context: context,
      builder: (context) =>
          _AssessmentEditorDialog(assessment: assessment, initialKind: kind),
    );
    if (input == null || !mounted) return;
    try {
      final saved = await widget.source.saveAssessment(
        widget.student.studentId,
        input,
        assessmentId: assessment?.id,
      );
      if (!mounted) return;
      setState(() {
        final values = [...?_assessments];
        final index = values.indexWhere((value) => value.id == saved.id);
        if (index == -1) {
          values.insert(0, saved);
        } else {
          values[index] = saved;
        }
        _assessments = values;
        _assessmentError = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Assessment marks saved.')));
    } on AdvisorStudentsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save assessment marks.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      children: [
        Center(child: _StudentAvatar(student: student, radius: 54)),
        const SizedBox(height: 14),
        Text(
          student.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          '${student.number} • ${student.departmentCode}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 22),
        _Detail('Email', student.email),
        _Detail('Mobile number', student.phone),
        _Detail('Department', student.departmentName),
        _Detail('Programme', student.programmeName),
        _Detail('Section', student.sectionName),
        _Detail('Academic year', student.academicYear),
        _Detail('Campus', student.campusName),
        _Detail('Status', student.status),
        for (final entry in student.profile.entries)
          if (!_hiddenProfileKeys.contains(entry.key) &&
              (entry.value?.toString().trim().isNotEmpty ?? false))
            _Detail(_label(entry.key), _profileValue(entry.value)),
        const Divider(height: 36),
        Text(
          'Academic assessments',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Add or update marks for this student.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  _editAssessment(kind: AdvisorAssessmentKind.semester),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Semester marks'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _editAssessment(kind: AdvisorAssessmentKind.internal),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Internal marks'),
            ),
            FilledButton.tonalIcon(
              onPressed: () =>
                  _editAssessment(kind: AdvisorAssessmentKind.test),
              icon: const Icon(Icons.add),
              label: const Text('Other test'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_assessmentError != null)
          Row(
            children: [
              Expanded(child: Text(_assessmentError!)),
              TextButton(
                onPressed: _loadAssessments,
                child: const Text('Retry'),
              ),
            ],
          )
        else if (_assessments == null)
          const Column(
            children: [
              SkeletonListRow(height: 72),
              SizedBox(height: 8),
              SkeletonListRow(height: 72),
              SizedBox(height: 8),
              SkeletonListRow(height: 72),
            ],
          )
        else if (_assessments!.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No assessment marks recorded yet.'),
          )
        else
          for (final assessment in _assessments!)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _editAssessment(assessment: assessment),
                leading: CircleAvatar(
                  child: Icon(_assessmentIcon(assessment.kind)),
                ),
                title: Text(assessment.title),
                subtitle: Text(
                  [
                    _assessmentKindLabel(assessment.kind),
                    if (assessment.semester != null)
                      'Semester ${assessment.semester}',
                    if (assessment.notes != null) assessment.notes!,
                  ].join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${_mark(assessment.marksObtained)} / '
                  '${_mark(assessment.maximumMarks)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
      ],
    );
  }
}

class _AssessmentEditorDialog extends StatefulWidget {
  const _AssessmentEditorDialog({this.assessment, this.initialKind});

  final AdvisorAssessment? assessment;
  final AdvisorAssessmentKind? initialKind;

  @override
  State<_AssessmentEditorDialog> createState() =>
      _AssessmentEditorDialogState();
}

class _AssessmentEditorDialogState extends State<_AssessmentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late AdvisorAssessmentKind _kind;
  late final TextEditingController _title;
  late final TextEditingController _semester;
  late final TextEditingController _obtained;
  late final TextEditingController _maximum;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final assessment = widget.assessment;
    _kind =
        assessment?.kind ??
        widget.initialKind ??
        AdvisorAssessmentKind.internal;
    _title = TextEditingController(
      text: assessment?.title ?? _defaultAssessmentTitle(_kind),
    );
    _semester = TextEditingController(
      text: assessment?.semester?.toString() ?? '',
    );
    _obtained = TextEditingController(
      text: assessment == null ? '' : _mark(assessment.marksObtained),
    );
    _maximum = TextEditingController(
      text: assessment == null ? '' : _mark(assessment.maximumMarks),
    );
    _notes = TextEditingController(text: assessment?.notes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _semester.dispose();
    _obtained.dispose();
    _maximum.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      AdvisorAssessmentInput(
        kind: _kind,
        title: _title.text,
        semester: int.tryParse(_semester.text),
        marksObtained: double.parse(_obtained.text),
        maximumMarks: double.parse(_maximum.text),
        notes: _notes.text,
        assessedOn: widget.assessment?.assessedOn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.assessment == null ? 'Add assessment' : 'Edit assessment',
    ),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AdvisorAssessmentKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Assessment type'),
                items: AdvisorAssessmentKind.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_assessmentKindLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final oldDefault = _defaultAssessmentTitle(_kind);
                  setState(() {
                    _kind = value;
                    if (_title.text.isEmpty || _title.text == oldDefault) {
                      _title.text = _defaultAssessmentTitle(value);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: _kind == AdvisorAssessmentKind.test
                      ? 'Test name'
                      : 'Assessment name',
                  hintText: _kind == AdvisorAssessmentKind.test
                      ? 'Example: Weekly quiz 3'
                      : null,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an assessment name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _semester,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Semester (optional)',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final semester = int.tryParse(value);
                  return semester == null || semester < 1 || semester > 12
                      ? 'Enter a semester from 1 to 12'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _obtained,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Marks'),
                      validator: (value) {
                        final mark = double.tryParse(value ?? '');
                        return mark == null || mark < 0
                            ? 'Enter valid marks'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maximum,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Out of'),
                      validator: (value) {
                        final maximum = double.tryParse(value ?? '');
                        final obtained = double.tryParse(_obtained.text);
                        if (maximum == null || maximum <= 0) {
                          return 'Enter maximum';
                        }
                        if (obtained != null && obtained > maximum) {
                          return 'Below marks';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save marks')),
    ],
  );
}

String _defaultAssessmentTitle(AdvisorAssessmentKind kind) => switch (kind) {
  AdvisorAssessmentKind.semester => 'Semester examination',
  AdvisorAssessmentKind.internal => 'Internal assessment',
  AdvisorAssessmentKind.test => '',
};

String _assessmentKindLabel(AdvisorAssessmentKind kind) => switch (kind) {
  AdvisorAssessmentKind.semester => 'Semester',
  AdvisorAssessmentKind.internal => 'Internal',
  AdvisorAssessmentKind.test => 'Other test',
};

IconData _assessmentIcon(AdvisorAssessmentKind kind) => switch (kind) {
  AdvisorAssessmentKind.semester => Icons.school_outlined,
  AdvisorAssessmentKind.internal => Icons.fact_check_outlined,
  AdvisorAssessmentKind.test => Icons.edit_note_outlined,
};

String _mark(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

const _hiddenProfileKeys = {
  'photoUrl',
  'dept',
  'department',
  'roll',
  'phone',
  'team',
};

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value!),
    );
  }
}

String _label(String value) => value
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _profileValue(Object? value) {
  final text = value?.toString() ?? '';
  if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(text)) return text;
  return _label(text);
}
