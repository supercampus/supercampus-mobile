import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/library_lending_repository.dart';
import '../data/library_repository.dart';
import 'library_visit_slots_section.dart';

class LibraryLendingScreen extends StatefulWidget {
  const LibraryLendingScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.slotRepository,
    required this.onExitModule,
  });

  final UserSession session;
  final LibraryLendingRepository repository;
  final LibraryRepository slotRepository;
  final VoidCallback onExitModule;

  @override
  State<LibraryLendingScreen> createState() => _LibraryLendingScreenState();
}

class _LibraryLendingScreenState extends State<LibraryLendingScreen> {
  final _search = TextEditingController();
  List<LibraryBook> _books = const [];
  List<LibraryLoan> _loans = const [];
  LibraryLendingPolicy _policy = const LibraryLendingPolicy(
    loanDays: 30,
    finePerDay: 0,
  );
  bool _loading = true;
  bool _favouritesOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.catalog(),
        widget.repository.loans(),
        widget.repository.policy(),
      ]);
      if (!mounted) return;
      setState(() {
        _books = values[0] as List<LibraryBook>;
        _loans = values[1] as List<LibraryLoan>;
        _policy = values[2] as LibraryLendingPolicy;
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

  List<LibraryBook> get _visibleBooks {
    final query = _search.text.trim().toLowerCase();
    return _books
        .where((book) {
          if (_favouritesOnly && !book.isFavourite) return false;
          return query.isEmpty ||
              book.title.toLowerCase().contains(query) ||
              book.author.toLowerCase().contains(query) ||
              book.category.toLowerCase().contains(query) ||
              (book.isbn ?? '').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  List<LibraryLoan> get _openLoans => _loans
      .where((loan) => loan.status != 'returned' && loan.status != 'rejected')
      .toList(growable: false);

  Future<void> _borrow(LibraryBook book) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Borrow book',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            TextField(
              readOnly: true,
              controller: TextEditingController(
                text: widget.session.idNumber ?? '',
              ),
              decoration: const InputDecoration(
                labelText: 'Roll number',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.menu_book_outlined),
              ),
              title: Text(book.title),
              subtitle: Text(
                book.author.isEmpty ? 'Author not specified' : book.author,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${_policy.loanDays}-day loan · ₹${_money(_policy.finePerDay)} per overdue day. '
                'You can renew before the due date.',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send borrow request'),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.requestBorrow(book.id);
      await _load();
      if (mounted) _snack('Borrow request sent to the librarian.');
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    }
  }

  Future<void> _toggleFavourite(LibraryBook book) async {
    try {
      await widget.repository.setFavourite(book.id, !book.isFavourite);
      await _load();
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    }
  }

  Future<void> _renew(LibraryLoan loan) async {
    try {
      await widget.repository.renew(loan.id);
      await _load();
      if (mounted) _snack('Loan renewed for another ${_policy.loanDays} days.');
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: ModuleBackButton(onPressed: widget.onExitModule),
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          ModuleHomeButton(onPressed: widget.onExitModule),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                      children: [
                        Text(
                          'Find and borrow books',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your roll number is verified from your account. Requests need librarian approval.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        LibraryVisitSlotsSection(
                          repository: widget.slotRepository,
                        ),
                        if (_openLoans.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _Heading(
                            label: 'My borrowed books',
                            count: _openLoans.length,
                          ),
                          const SizedBox(height: 8),
                          for (final loan in _openLoans)
                            _LoanCard(loan: loan, onRenew: () => _renew(loan)),
                        ],
                        const SizedBox(height: 22),
                        _Heading(label: 'Book inventory', count: _books.length),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: 'Search title, author, category or ISBN',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            selected: _favouritesOnly,
                            onSelected: (value) =>
                                setState(() => _favouritesOnly = value),
                            avatar: const Icon(
                              Icons.favorite_outline,
                              size: 18,
                            ),
                            label: const Text('Favourites'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_visibleBooks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 44),
                            child: Center(
                              child: Text('No books match this search.'),
                            ),
                          ),
                        for (final book in _visibleBooks)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colors.primaryContainer,
                                    child: const Icon(
                                      Icons.auto_stories_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (book.author.isNotEmpty)
                                          Text(book.author),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${book.availableCopies} of ${book.totalCopies} available'
                                          '${book.shelfCode.isEmpty ? '' : ' · Shelf ${book.shelfCode}'}',
                                          style: TextStyle(
                                            color: book.isAvailable
                                                ? AppColors.success
                                                : colors.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        FilledButton.tonal(
                                          onPressed: book.isAvailable
                                              ? () => _borrow(book)
                                              : null,
                                          child: const Text('Borrow book'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: book.isFavourite
                                        ? 'Remove favourite'
                                        : 'Add favourite',
                                    onPressed: () => _toggleFavourite(book),
                                    icon: Icon(
                                      book.isFavourite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                    color: book.isFavourite
                                        ? colors.error
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
  String _money(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(2);
  void _snack(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.titleLarge),
      ),
      Chip(label: Text('$count')),
    ],
  );
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.onRenew});
  final LibraryLoan loan;
  final VoidCallback onRenew;
  @override
  Widget build(BuildContext context) {
    final approved = loan.status == 'approved';
    final overdue = loan.overdueDays > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          overdue ? Icons.warning_amber_rounded : Icons.menu_book_outlined,
        ),
        title: Text(loan.bookTitle),
        subtitle: Text(
          approved
              ? 'Due ${DateFormat('d MMM yyyy').format(loan.dueAt!)}${overdue ? ' · ${loan.overdueDays} days overdue · ₹${loan.fineAmount.toStringAsFixed(2)} fine' : ''}'
              : 'Waiting for librarian approval',
        ),
        trailing: approved && !overdue
            ? TextButton(onPressed: onRenew, child: const Text('Renew'))
            : Chip(label: Text(loan.status.toUpperCase())),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 50),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
