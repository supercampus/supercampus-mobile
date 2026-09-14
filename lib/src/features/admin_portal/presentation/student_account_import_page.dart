import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../data/admin_student_repository.dart';

const studentAccountHeaders = [
  'Name',
  'Roll No',
  'Email',
  'Mobile number',
  'Department',
  'Year',
  'Section',
  'Password',
];

/// Strict CSV parsing, including quoted commas, escaped quotes and newlines.
List<List<String>> parseStudentCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  var value = '';
  var quoted = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (c == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        value += '"';
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      row.add(value);
      value = '';
    } else if ((c == '\n' || c == '\r') && !quoted) {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(value);
      if (row.any((s) => s.trim().isNotEmpty)) rows.add(row);
      row = [];
      value = '';
    } else {
      value += c;
    }
  }
  if (quoted) throw const FormatException('Unclosed quote in CSV file.');
  row.add(value);
  if (row.any((s) => s.trim().isNotEmpty)) rows.add(row);
  return rows;
}

List<Map<String, dynamic>> parseStudentAccounts(List<List<String>> table) {
  if (table.length < 2) {
    throw const FormatException(
      'Add student rows below the template headings.',
    );
  }
  if (table.first.length != studentAccountHeaders.length ||
      List.generate(
        studentAccountHeaders.length,
        (i) =>
            table.first[i].replaceFirst('\uFEFF', '').trim().toLowerCase() ==
            studentAccountHeaders[i].toLowerCase(),
      ).contains(false)) {
    throw const FormatException(
      'Use the downloaded template without changing its headings.',
    );
  }
  if (table.length > 1001) {
    throw const FormatException('Upload at most 1000 students per file.');
  }
  final emails = <String>{};
  final rolls = <String>{};
  final result = <Map<String, dynamic>>[];
  for (var i = 1; i < table.length; i++) {
    final r = table[i];
    final number = i + 1;
    if (r.length != 8 || r.any((s) => s.trim().isEmpty)) {
      throw FormatException('Row $number: all eight fields are required.');
    }
    final email = r[2].trim().toLowerCase();
    final year = int.tryParse(r[5].trim());
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw FormatException('Row $number: invalid email.');
    }
    if (year == null || year < 1 || year > 6) {
      throw FormatException(
        'Row $number: year must be 1–6. Use 1 for first-year students.',
      );
    }
    if (r[7].runes.length < 8 || utf8.encode(r[7]).length > 72) {
      throw FormatException(
        'Row $number: password must be at least 8 characters and at most 72 bytes.',
      );
    }
    if (!emails.add(email) || !rolls.add(r[1].trim().toLowerCase())) {
      throw FormatException('Row $number: duplicate email or roll number.');
    }
    result.add({
      'name': r[0].trim(),
      'rollNo': r[1].trim(),
      'email': email,
      'mobileNumber': r[3].trim(),
      'department': r[4].trim(),
      'year': year,
      'section': r[6].trim(),
      'password': r[7],
    });
  }
  return result;
}

class StudentAccountImportPage extends StatefulWidget {
  const StudentAccountImportPage({super.key, required this.repository});
  final AdminStudentRepository repository;
  @override
  State<StudentAccountImportPage> createState() =>
      _StudentAccountImportPageState();
}

class _StudentAccountImportPageState extends State<StudentAccountImportPage> {
  List<Map<String, dynamic>> _rows = [];
  final List<Map<String, dynamic>> _results = [];
  String? _error;
  bool _busy = false;
  bool _finished = false;
  Future<void> _template() async {
    try {
      await FilePicker.saveFile(
        fileName: 'student-accounts-template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(
          utf8.encode('${studentAccountHeaders.join(',')}\r\n'),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pick() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('Choose a file smaller than 5 MB.');
      }
      final table = file.name.toLowerCase().endsWith('.csv')
          ? parseStudentCsv(utf8.decode(bytes))
          : Excel.decodeBytes(bytes).tables.values.first.rows
                .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
                .where((r) => r.any((s) => s.trim().isNotEmpty))
                .toList();
      final rows = parseStudentAccounts(table);
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
          _results.clear();
          _finished = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _rows = [];
        });
      }
    }
  }

  Future<void> _import() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create student accounts?'),
        content: Text(
          'Create ${_rows.length} student accounts with Student access. Existing accounts will not be overwritten. Keep the password file private and share each password only with its owner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create accounts'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _results.clear();
    });
    try {
      for (var start = 0; start < _rows.length; start += 25) {
        final batch = _rows.sublist(
          start,
          start + 25 > _rows.length ? _rows.length : start + 25,
        );
        final results = await widget.repository.importStudentAccounts(batch);
        if (!mounted) return;
        setState(() => _results.addAll(results));
      }
      if (mounted) setState(() => _finished = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Import stopped. ${_results.length} rows processed. You may safely retry the same file. $e',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Bulk upload students')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'New student accounts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            '1. Download the template.\n2. Fill one student per row; use Year = 1 for first year.\n3. Choose the file, review, then create accounts.\n\nUse the existing department code (for example CSE) and section. Keep roll numbers and mobile numbers as text in Excel. Use a different strong password for every student. Photos are optional and can be added later by the student or administrator.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _template,
                icon: const Icon(Icons.download),
                label: const Text('Download CSV template'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose CSV / Excel'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('${_rows.length} students · preview (passwords hidden)'),
            ..._rows
                .take(10)
                .map(
                  (r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['name']} · ${r['rollNo']}'),
                    subtitle: Text(
                      '${r['email']}\n${r['department']} · Year ${r['year']} · Section ${r['section']}',
                    ),
                  ),
                ),
            FilledButton(
              onPressed: _busy || _finished ? null : _import,
              child: Text(
                _busy
                    ? 'Processing ${_results.length} / ${_rows.length}…'
                    : 'Create student accounts',
              ),
            ),
          ],
          if (_busy) const LinearProgressIndicator(),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${_results.where((r) => r['status'] == 'created').length} created · ${_results.where((r) => r['status'] == 'already_imported').length} already imported · ${_results.where((r) => r['status'] == 'failed').length} failed',
            ),
            ..._results
                .where((r) => r['status'] == 'failed')
                .map(
                  (r) => ListTile(
                    title: Text('${r['email']}'),
                    subtitle: Text('${r['message']}'),
                  ),
                ),
          ],
        ],
      ),
    ),
  );
}
