import 'dart:convert';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/library_lending_repository.dart';

class LibrarianLendingScreen extends StatefulWidget {
  const LibrarianLendingScreen({super.key, required this.repository});
  final LibraryLendingRepository repository;

  @override
  State<LibrarianLendingScreen> createState() => _LibrarianLendingScreenState();
}

class _LibrarianLendingScreenState extends State<LibrarianLendingScreen> {
  List<LibraryBook> _books = const [];
  List<LibraryLoan> _loans = const [];
  LibraryLendingPolicy _policy = const LibraryLendingPolicy(
    loanDays: 30,
    finePerDay: 0,
  );
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        widget.repository.catalog(),
        widget.repository.loans(),
        widget.repository.policy(),
      ]);
      if (!mounted) return;
      setState(() {
        _books = result[0] as List<LibraryBook>;
        _loans = result[1] as List<LibraryLoan>;
        _policy = result[2] as LibraryLendingPolicy;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _review(LibraryLoan loan) async {
    final decision = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review borrow request',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              loan.bookTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text('${loan.studentName} · ${loan.rollNumber}'),
            const SizedBox(height: 8),
            Text(
              'Approval starts a ${_policy.loanDays}-day loan and reserves one inventory copy.',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'rejected'),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, 'approved'),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (decision == null) return;
    try {
      await widget.repository.decide(loan.id, decision);
      await _load();
      if (mounted) _snack('Borrow request $decision.');
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    }
  }

  Future<void> _returned(LibraryLoan loan) async {
    try {
      await widget.repository.markReturned(loan.id);
      await _load();
      if (mounted) _snack('Book returned and inventory updated.');
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    }
  }

  Future<void> _editPolicy() async {
    final days = TextEditingController(text: '${_policy.loanDays}');
    final fine = TextEditingController(text: '${_policy.finePerDay}');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrowing policy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Loan duration (days)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fine,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Fine per overdue day',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) {
      final loanDays = int.tryParse(days.text.trim());
      final finePerDay = double.tryParse(fine.text.trim());
      if (loanDays == null || finePerDay == null) {
        _snack('Enter a valid duration and fine amount.', error: true);
      } else {
        try {
          await widget.repository.updatePolicy(
            loanDays: loanDays,
            finePerDay: finePerDay,
          );
          await _load();
          if (mounted) _snack('Borrowing policy updated.');
        } catch (error) {
          if (mounted) _snack(_message(error), error: true);
        }
      }
    }
    days.dispose();
    fine.dispose();
  }

  Future<void> _import() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Upload library inventory',
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
    );
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();
      final rows = extension == 'csv'
          ? _parseCsv(utf8.decode(bytes, allowMalformed: true))
          : _parseWorkbook(bytes);
      final books = _bookRows(rows);
      final count = await widget.repository.importBooks(books);
      await _load();
      if (mounted) _snack('$count books imported from ${file.name}.');
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    }
  }

  Future<void> _addBook() async {
    final title = TextEditingController();
    final author = TextEditingController();
    final isbn = TextEditingController();
    final accession = TextEditingController();
    final category = TextEditingController();
    final shelf = TextEditingController();
    final copies = TextEditingController(text: '1');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add inventory book'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Book title *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: author,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: isbn,
                  decoration: const InputDecoration(labelText: 'ISBN'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accession,
                  decoration: const InputDecoration(
                    labelText: 'Accession number',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: shelf,
                  decoration: const InputDecoration(labelText: 'Shelf code'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: copies,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total copies *',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add book'),
          ),
        ],
      ),
    );
    if (save == true) {
      final copyCount = int.tryParse(copies.text.trim());
      if (title.text.trim().isEmpty ||
          copyCount == null ||
          copyCount < 1 ||
          (isbn.text.trim().isEmpty && accession.text.trim().isEmpty)) {
        _snack(
          'Enter a title, copy count, and ISBN or accession number.',
          error: true,
        );
      } else {
        try {
          await widget.repository.importBooks([
            LibraryBookImport(
              title: title.text.trim(),
              author: author.text.trim(),
              isbn: isbn.text.trim(),
              accessionNumber: accession.text.trim(),
              category: category.text.trim(),
              shelfCode: shelf.text.trim(),
              totalCopies: copyCount,
            ),
          ]);
          await _load();
          if (mounted) _snack('Book added to the inventory.');
        } catch (error) {
          if (mounted) _snack(_message(error), error: true);
        }
      }
    }
    for (final controller in [
      title,
      author,
      isbn,
      accession,
      category,
      shelf,
      copies,
    ]) {
      controller.dispose();
    }
  }

  List<LibraryBookImport> _bookRows(List<List<String>> rows) {
    if (rows.isEmpty) {
      throw const FormatException('The inventory file is empty.');
    }
    final headers = rows.first
        .map(
          (value) =>
              value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
        )
        .toList();
    int column(String name) => headers.indexOf(name);
    final title = column('title');
    final author = column('author');
    final isbn = column('isbn');
    final accession = column('accessionnumber');
    final category = column('category');
    final shelf = column('shelfcode');
    final copies = column('totalcopies');
    if (title < 0 || copies < 0 || (isbn < 0 && accession < 0)) {
      throw const FormatException(
        'Required columns: Title, Total Copies, and ISBN or Accession Number.',
      );
    }
    String value(List<String> row, int index) =>
        index >= 0 && index < row.length ? row[index].trim() : '';
    final result = <LibraryBookImport>[];
    for (final row in rows.skip(1)) {
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      final count = int.tryParse(value(row, copies));
      final bookTitle = value(row, title);
      if (bookTitle.isEmpty || count == null || count < 1) {
        throw FormatException(
          'Invalid title or copy count on row ${result.length + 2}.',
        );
      }
      result.add(
        LibraryBookImport(
          title: bookTitle,
          author: value(row, author),
          isbn: value(row, isbn),
          accessionNumber: value(row, accession),
          category: value(row, category),
          shelfCode: value(row, shelf),
          totalCopies: count,
        ),
      );
    }
    return result;
  }

  List<List<String>> _parseWorkbook(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return const [];
    return [
      for (final row in workbook.tables.values.first.rows)
        [for (final cell in row) cell?.value?.toString() ?? ''],
    ];
  }

  List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var quoted = false;
    for (var index = 0; index < text.length; index++) {
      final char = text[index];
      if (char == '"') {
        if (quoted && index + 1 < text.length && text[index + 1] == '"') {
          cell.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(cell.toString());
        cell = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' &&
            index + 1 < text.length &&
            text[index + 1] == '\n') {
          index++;
        }
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Book lending'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(_error!),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.policy_outlined,
                          color: AppColors.gateBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_policy.loanDays} days · ₹${_policy.finePerDay.toStringAsFixed(2)} per overdue day',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _editPolicy,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _addBook,
                        icon: const Icon(Icons.add),
                        label: const Text('Add book'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _import,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Import CSV / Excel'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _title(
                  'Borrow requests',
                  _loans.where((loan) => loan.status == 'requested').length,
                ),
                for (final loan in _loans.where(
                  (loan) => loan.status == 'requested',
                ))
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(loan.bookTitle),
                      subtitle: Text(
                        '${loan.studentName} · ${loan.rollNumber}\nRequested ${DateFormat('d MMM, h:mm a').format(loan.requestedAt)}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _review(loan),
                    ),
                  ),
                const SizedBox(height: 20),
                _title(
                  'Active loans',
                  _loans.where((loan) => loan.status == 'approved').length,
                ),
                for (final loan in _loans.where(
                  (loan) => loan.status == 'approved',
                ))
                  Card(
                    child: ListTile(
                      leading: Icon(
                        loan.overdueDays > 0
                            ? Icons.warning_amber_rounded
                            : Icons.menu_book_outlined,
                      ),
                      title: Text(loan.bookTitle),
                      subtitle: Text(
                        '${loan.studentName} · ${loan.rollNumber}\nDue ${DateFormat('d MMM yyyy').format(loan.dueAt!)}${loan.overdueDays > 0 ? ' · ₹${loan.fineAmount.toStringAsFixed(2)} fine' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () => _returned(loan),
                        child: const Text('Return'),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                _title('Inventory', _books.length),
                for (final book in _books)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: Text(book.title),
                      subtitle: Text(
                        '${book.author}${book.shelfCode.isEmpty ? '' : ' · Shelf ${book.shelfCode}'}',
                      ),
                      trailing: Text(
                        '${book.availableCopies}/${book.totalCopies}',
                      ),
                    ),
                  ),
                for (final loan in _loans.where(
                  (loan) => loan.status == 'approved',
                ))
                  Card(
                    child: ListTile(
                      title: Text(loan.bookTitle),
                      subtitle: Text(
                        '${loan.studentName} · ${loan.rollNumber}\nDue ${DateFormat('d MMM yyyy').format(loan.dueAt!)}${loan.overdueDays > 0 ? ' · ₹${loan.fineAmount.toStringAsFixed(2)} fine' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () => _returned(loan),
                        child: const Text('Returned'),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                _title('Inventory', _books.length),
                if (_books.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No books yet. Import a CSV or Excel file to begin.',
                      ),
                    ),
                  ),
                for (final book in _books)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: Text(book.title),
                      subtitle: Text(
                        '${book.author}${book.shelfCode.isEmpty ? '' : ' · Shelf ${book.shelfCode}'}',
                      ),
                      trailing: Text(
                        '${book.availableCopies}/${book.totalCopies}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );

  Widget _title(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
        Chip(label: Text('$count')),
      ],
    ),
  );
  String _message(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('FormatException: ', '');
  void _snack(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
}
