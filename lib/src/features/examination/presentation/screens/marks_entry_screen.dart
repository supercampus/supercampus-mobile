import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../data/marks_batch_repository.dart';

enum _BatchStage { draft, advisor, hod, principal, published, returned }

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key, required this.session, this.repository});

  final UserSession session;
  final MarksBatchRepository? repository;

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  static const _fallbackSubjects = [
    'CS301 Data Structures & Algorithms',
    'CS302 Database Management Systems',
    'CS303 Operating Systems',
  ];
  static const _types = [
    'Internal',
    'Semester',
    'Practical',
    'Assignment',
    'Quiz',
  ];

  List<String> _subjects = _fallbackSubjects;
  String _subject = _fallbackSubjects.first;
  String _type = _types.first;
  double _outOf = 30;
  String? _fileName;
  int _rows = 0;
  int _invalidRows = 0;
  List<Map<String, dynamic>> _importedRecords = const [];
  List<Map<String, dynamic>> _batches = const [];
  late _BatchStage _stage;

  Set<String> get _roles => {
    widget.session.roleKey.toLowerCase(),
    ...widget.session.roleIds.map((role) => role.toLowerCase()),
  };

  String get _actor => _roles.contains('principal')
      ? 'principal'
      : _roles.contains('hod')
      ? 'hod'
      : _roles.contains('class_advisor')
      ? 'advisor'
      : 'faculty';

  @override
  void initState() {
    super.initState();
    _stage = switch (_actor) {
      'advisor' => _BatchStage.advisor,
      'hod' => _BatchStage.hod,
      'principal' => _BatchStage.principal,
      _ => _BatchStage.draft,
    };
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    final repository = widget.repository;
    if (repository == null) return;
    try {
      final values = await Future.wait([
        repository.list(),
        _actor == 'faculty' || _actor == 'advisor'
            ? repository.subjects()
            : Future<List<Map<String, dynamic>>>.value(const []),
      ]);
      final batches = values[0];
      final assignedSubjects = values[1]
          .map(
            (item) =>
                '${item['subjectCode'] ?? ''} ${item['subjectName'] ?? ''}'
                    .trim(),
          )
          .where((item) => item.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _batches = batches;
          if (assignedSubjects.isNotEmpty) {
            _subjects = assignedSubjects;
            if (!_subjects.contains(_subject)) _subject = _subjects.first;
          }
          if (_activeReviewBatch != null) {
            _stage = switch (_actor) {
              'advisor' => _BatchStage.advisor,
              'hod' => _BatchStage.hod,
              'principal' => _BatchStage.principal,
              _ => _stage,
            };
          }
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        _snack(error.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  Future<void> _download(String extension) async {
    final excel = extension == 'xlsx';
    final asset = excel
        ? 'assets/templates/supercampus_marks_upload_template.xlsx'
        : 'assets/templates/supercampus_marks_upload_template.csv';
    final data = await rootBundle.load(asset);
    await FilePicker.saveFile(
      dialogTitle: excel
          ? 'Save Excel marks template'
          : 'Save CSV / Google Sheets template',
      fileName: 'supercampus_marks_upload_template.$extension',
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    if (mounted) {
      _snack(
        excel ? 'Excel template prepared.' : 'CSV / Sheets template prepared.',
      );
    }
  }

  Future<void> _upload() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Upload marks file',
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls'],
    );
    if (file == null) return;

    var rows = 0;
    var invalid = 0;
    final extension = file.name.split('.').last.toLowerCase();
    if (extension == 'csv' || extension == 'xlsx') {
      final bytes = await file.readAsBytes();
      final records = extension == 'csv'
          ? _parseCsv(String.fromCharCodes(bytes))
          : _parseWorkbook(bytes);
      if (records.isEmpty || !_validHeaders(records.first)) {
        _snack(
          'The file columns do not match the official template.',
          error: true,
        );
        return;
      }
      final imported = <Map<String, dynamic>>[];
      String? importedSubjectCode;
      String? importedSubjectName;
      String? importedAssessmentType;
      double? importedMaximumMarks;
      for (final row in records.skip(1)) {
        if (row.every((cell) => cell.trim().isEmpty)) continue;
        rows++;
        if (!_validRow(row)) {
          invalid++;
        } else {
          importedSubjectCode ??= row[4].trim();
          importedSubjectName ??= row[5].trim();
          importedAssessmentType ??= row[3].trim();
          importedMaximumMarks ??= double.parse(row[7]);
          imported.add({
            'studentId': row[0].trim(),
            'registerNumber': row[1].trim(),
            'studentName': row[2].trim(),
            'assessmentType': row[3].trim(),
            'subjectCode': row[4].trim(),
            'subjectName': row[5].trim(),
            'marksObtained': double.parse(row[6]),
            'maximumMarks': double.parse(row[7]),
            'assessedOn': row.length > 8 ? row[8].trim() : '',
            'remarks': row.length > 9 ? row[9].trim() : '',
          });
        }
      }
      final matchingSubject = _matchingAssignedSubject(
        importedSubjectCode,
        importedSubjectName,
      );
      final matchingType = _types.cast<String?>().firstWhere(
        (value) =>
            value!.toLowerCase() == importedAssessmentType?.toLowerCase(),
        orElse: () => null,
      );
      setState(() {
        _importedRecords = imported;
        if (matchingSubject != null) _subject = matchingSubject;
        if (matchingType != null) _type = matchingType;
        if (importedMaximumMarks != null) _outOf = importedMaximumMarks;
      });
    }
    setState(() {
      _fileName = file.name;
      _rows = rows;
      _invalidRows = invalid;
      _stage = _BatchStage.draft;
    });
    _snack(
      extension == 'csv' || extension == 'xlsx'
          ? '$rows rows imported; $invalid need correction.'
          : 'Legacy .xls files must be saved as .xlsx before upload.',
      error: invalid > 0,
    );
  }

  String? _matchingAssignedSubject(String? code, String? name) {
    final normalizedCode = code?.trim().toLowerCase() ?? '';
    final normalizedName =
        name?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim() ?? '';
    for (final subject in _subjects) {
      final normalizedSubject = subject
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      if (normalizedCode.isNotEmpty &&
          normalizedSubject.startsWith('$normalizedCode ')) {
        return subject;
      }
      if (normalizedName.isNotEmpty &&
          normalizedSubject.contains(normalizedName)) {
        return subject;
      }
    }
    return null;
  }

  bool _validHeaders(List<String> row) {
    const expected = [
      'Student ID (optional)',
      'Register Number*',
      'Student Name*',
      'Assessment Type*',
      'Subject Code*',
      'Subject*',
      'Marks Obtained*',
      'Out Of*',
      'Assessment Date',
      'Remarks',
    ];
    return row.length >= expected.length &&
        Iterable<int>.generate(
          expected.length,
        ).every((index) => row[index].trim() == expected[index]);
  }

  bool _validRow(List<String> row) {
    if (row.length < 8) return false;
    if ([1, 2, 3, 4, 5, 6, 7].any((index) => row[index].trim().isEmpty)) {
      return false;
    }
    final marks = double.tryParse(row[6]);
    final outOf = double.tryParse(row[7]);
    return marks != null &&
        outOf != null &&
        marks >= 0 &&
        outOf > 0 &&
        marks <= outOf;
  }

  List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(cell.toString());
        cell = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        rows.add(row);
        row = <String>[];
        cell = StringBuffer();
      } else {
        cell.write(char);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  List<List<String>> _parseWorkbook(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return const [];
    final sheet = workbook.tables.values.first;
    return [
      for (final row in sheet.rows)
        [for (final cell in row) cell?.value?.toString() ?? ''],
    ];
  }

  Future<void> _submit() async {
    if (_fileName == null) {
      _snack('Upload a completed CSV or Excel file first.', error: true);
      return;
    }
    if (_invalidRows > 0) {
      _snack('Correct invalid rows before submission.', error: true);
      return;
    }
    final advisorUpload = _actor == 'advisor';
    final repository = widget.repository;
    if (repository != null) {
      try {
        final parts = _subject.split(' ');
        await repository.create(
          subjectCode: parts.first,
          subjectName: parts.skip(1).join(' '),
          assessmentType: _type,
          maximumMarks: _outOf,
          entries: _importedRecords,
        );
        await _loadBatches();
      } on Exception catch (error) {
        _snack(error.toString().replaceFirst('Exception: ', ''), error: true);
        return;
      }
    }
    setState(
      () => _stage = advisorUpload ? _BatchStage.hod : _BatchStage.advisor,
    );
    _snack(
      advisorUpload
          ? 'Class advisor marks sent to the HOD.'
          : 'Marks sent to the class advisor.',
    );
  }

  Future<void> _approve() async {
    final batch = _activeReviewBatch;
    if (widget.repository != null && batch != null) {
      try {
        await widget.repository!.review(batch['id'].toString(), 'approve');
        await _loadBatches();
      } on Exception catch (error) {
        _snack(error.toString().replaceFirst('Exception: ', ''), error: true);
        return;
      }
    }
    setState(() {
      _stage = switch (_stage) {
        _BatchStage.advisor => _BatchStage.hod,
        _BatchStage.hod => _BatchStage.principal,
        _BatchStage.principal => _BatchStage.published,
        final current => current,
      };
    });
    _snack(_message(_stage));
  }

  Future<void> _reject() async {
    final batch = _activeReviewBatch;
    if (widget.repository != null && batch != null) {
      try {
        await widget.repository!.review(
          batch['id'].toString(),
          'reject',
          note: 'Returned for correction',
        );
        await _loadBatches();
      } on Exception catch (error) {
        _snack(error.toString().replaceFirst('Exception: ', ''), error: true);
        return;
      }
    }
    setState(() => _stage = _BatchStage.returned);
    _snack('Returned to faculty with a correction request.', error: true);
  }

  Map<String, dynamic>? get _activeReviewBatch {
    final expected = switch (_actor) {
      'advisor' => 'submitted_to_advisor',
      'hod' => 'submitted_to_hod',
      'principal' => 'submitted_to_principal',
      _ => '',
    };
    for (final batch in _batches) {
      if (batch['status'] == expected) return batch;
    }
    return null;
  }

  bool get _canReview => switch (_actor) {
    'advisor' =>
      _stage == _BatchStage.advisor &&
          (widget.repository == null || _activeReviewBatch != null),
    'hod' =>
      _stage == _BatchStage.hod &&
          (widget.repository == null || _activeReviewBatch != null),
    'principal' =>
      _stage == _BatchStage.principal &&
          (widget.repository == null || _activeReviewBatch != null),
    _ => false,
  };

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFF9B1C1C) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final mobile = constraints.maxWidth <= 700;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 12 : 18,
          14,
          mobile ? 12 : 18,
          112,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_actor == 'faculty' || _actor == 'advisor') ...[
              _setup(mobile),
              const SizedBox(height: 14),
              _bulkUpload(),
              const SizedBox(height: 14),
            ],
            _currentBatch(),
            const SizedBox(height: 14),
            _workflow(),
            const SizedBox(height: 14),
            _history(),
          ],
        ),
      );
    },
  );

  Widget _setup(bool mobile) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.upload_file_rounded, color: AppColors.primary),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Staff marks workspace',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey('marks-subject-$_subject'),
          initialValue: _subject,
          decoration: const InputDecoration(labelText: 'Assigned subject'),
          isExpanded: true,
          items: [
            for (final subject in _subjects)
              DropdownMenuItem(
                value: subject,
                child: Text(subject, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _subject = value!),
        ),
        const SizedBox(height: 10),
        if (mobile)
          Column(
            children: [
              _assessmentField(),
              const SizedBox(height: 10),
              _outOfField(),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _assessmentField()),
              const SizedBox(width: 10),
              Expanded(child: _outOfField()),
            ],
          ),
      ],
    ),
  );

  Widget _assessmentField() => DropdownButtonFormField<String>(
    key: ValueKey('marks-type-$_type'),
    initialValue: _type,
    decoration: const InputDecoration(labelText: 'Assessment type'),
    items: [
      for (final value in _types)
        DropdownMenuItem(value: value, child: Text(value)),
    ],
    onChanged: (value) => setState(() => _type = value!),
  );

  Widget _outOfField() => TextFormField(
    key: ValueKey('marks-out-of-$_outOf'),
    initialValue: _outOf.toStringAsFixed(0),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(labelText: 'Marks out of'),
    onChanged: (value) => _outOf = double.tryParse(value) ?? _outOf,
  );

  Widget _bulkUpload() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bulk upload',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        const Text(
          'Use the official template so student, subject, marks and maximum marks validation remains reliable.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('download-marks-xlsx'),
              onPressed: () => _download('xlsx'),
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Excel (.xlsx)'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('download-marks-csv'),
              onPressed: () => _download('csv'),
              icon: const Icon(Icons.grid_on_outlined),
              label: const Text('CSV / Sheets'),
            ),
            FilledButton.icon(
              key: const ValueKey('upload-marks-file'),
              onPressed: _upload,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Upload file'),
            ),
          ],
        ),
        if (_fileName != null) ...[
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              child: Icon(Icons.description_outlined),
            ),
            title: Text(_fileName!),
            subtitle: Text(
              _rows == 0
                  ? 'Workbook ready for validation'
                  : '$_rows rows · $_invalidRows need correction',
            ),
            trailing: Icon(
              _invalidRows == 0 ? Icons.check_circle : Icons.error,
              color: _invalidRows == 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _currentBatch() {
    final reviewBatch = _activeReviewBatch;
    if (widget.repository != null &&
        reviewBatch == null &&
        (_actor == 'hod' || _actor == 'principal')) {
      return _panel(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.inbox_outlined)),
          title: Text(
            _actor == 'principal'
                ? 'No batches waiting for principal review'
                : 'No batches waiting for HOD review',
          ),
          subtitle: const Text(
            'Newly approved batches appear here automatically.',
          ),
        ),
      );
    }
    final subject = reviewBatch == null
        ? _subject
        : '${reviewBatch['subjectCode'] ?? ''} ${reviewBatch['subjectName'] ?? ''}'
              .trim();
    final type = reviewBatch?['assessmentType']?.toString() ?? _type;
    final maximumMarks = reviewBatch?['maximumMarks'] ?? _outOf;
    final studentCount = (reviewBatch?['entries'] as List?)?.length;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current marks batch',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              _chip(_label(_stage)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$type · $subject · Out of $maximumMarks${studentCount == null ? '' : ' · $studentCount students'}',
          ),
          const SizedBox(height: 14),
          if ((_actor == 'faculty' || _actor == 'advisor') &&
              {_BatchStage.draft, _BatchStage.returned}.contains(_stage))
            FilledButton.icon(
              key: const ValueKey('submit-marks-advisor'),
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded),
              label: Text(
                _actor == 'advisor'
                    ? 'Submit advisor marks to HOD'
                    : 'Submit to class advisor',
              ),
            )
          else if (_canReview)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('reject-marks-batch'),
                    onPressed: _reject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('approve-marks-batch'),
                    onPressed: _approve,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _actor == 'principal' ? 'Approve & publish' : 'Approve',
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              _message(_stage),
              style: const TextStyle(color: AppColors.muted),
            ),
        ],
      ),
    );
  }

  Widget _workflow() {
    const steps = [
      (
        _BatchStage.advisor,
        'Class advisor',
        'Verifies class, roster and totals',
      ),
      (_BatchStage.hod, 'HOD', 'Reviews department exceptions'),
      (_BatchStage.principal, 'Principal', 'Final approval and publication'),
    ];
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Approval workflow',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Every action is timestamped, scoped and retained in the audit history.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < steps.length; index++) ...[
            _step(index + 1, steps[index].$1, steps[index].$2, steps[index].$3),
            if (index < steps.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 15),
                child: SizedBox(height: 18, child: VerticalDivider(width: 1)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _step(int number, _BatchStage stage, String title, String subtitle) {
    final complete =
        _stage.index > stage.index || _stage == _BatchStage.published;
    final active = _stage == stage;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: complete || active
              ? AppColors.primary
              : const Color(0xFFE8E9EE),
          foregroundColor: complete || active ? Colors.white : AppColors.muted,
          child: complete
              ? const Icon(Icons.check, size: 17)
              : Text('$number', style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _history() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Submission history',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_batches.isEmpty)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.history_rounded),
            title: Text('No submitted marks batches yet'),
            subtitle: Text(
              'Submitted and returned batches appear here with reviewer notes.',
            ),
          ),
        for (final batch in _batches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fact_check_outlined),
            title: Text(
              '${batch['subjectCode'] ?? ''} ${batch['subjectName'] ?? ''}'
                  .trim(),
            ),
            subtitle: Text(
              '${batch['assessmentType'] ?? ''} · ${((batch['entries'] as List?)?.length ?? 0)} students',
            ),
            trailing: _chip(
              batch['status']?.toString().replaceAll('_', ' ').toUpperCase() ??
                  '',
            ),
          ),
      ],
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String _label(_BatchStage stage) => switch (stage) {
  _BatchStage.draft => 'DRAFT',
  _BatchStage.advisor => 'WITH ADVISOR',
  _BatchStage.hod => 'WITH HOD',
  _BatchStage.principal => 'WITH PRINCIPAL',
  _BatchStage.published => 'PUBLISHED',
  _BatchStage.returned => 'RETURNED',
};

String _message(_BatchStage stage) => switch (stage) {
  _BatchStage.draft => 'Complete and submit the batch.',
  _BatchStage.advisor => 'Waiting for class advisor verification.',
  _BatchStage.hod => 'Approved by advisor and waiting for HOD.',
  _BatchStage.principal => 'Approved by HOD and waiting for principal.',
  _BatchStage.published => 'Approved and published to student records.',
  _BatchStage.returned => 'Returned to faculty for correction.',
};
