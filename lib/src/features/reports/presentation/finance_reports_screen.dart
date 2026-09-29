import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/app_theme.dart';
import '../data/finance_report.dart';
import '../data/finance_report_repository.dart';
import '../services/finance_report_exporter.dart';

/// Saves a generated file. The web starts a browser download; Android and
/// iOS open the system save sheet (Files / Downloads / Drive). Returns false
/// when the person cancelled.
typedef ReportFileSaver =
    Future<bool> Function({
      required String fileName,
      required Uint8List bytes,
      required String extension,
    });

/// Loads the PDF fonts; null falls back to the base font.
typedef ReportFontLoader =
    Future<({pw.Font regular, pw.Font medium})?> Function();

Future<bool> saveReportFile({
  required String fileName,
  required Uint8List bytes,
  required String extension,
}) async {
  final saved = await FilePicker.saveFile(
    dialogTitle: 'Save report',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: bytes,
  );
  // Null is a cancel on native platforms only; the web has no answer.
  return saved != null || kIsWeb;
}

Future<({pw.Font regular, pw.Font medium})?> _defaultFonts() async {
  try {
    return await FinanceReportExporter.loadFonts();
  } catch (_) {
    return null;
  }
}

/// "Report Kind": every finance report the campus can generate, as a grid.
/// Choosing one opens its parameters, then PDF or CSV.
class FinanceReportsScreen extends StatefulWidget {
  const FinanceReportsScreen({
    super.key,
    required this.repository,
    this.saveFile = saveReportFile,
    this.loadFonts = _defaultFonts,
  });

  final FinanceReportRepository repository;
  final ReportFileSaver saveFile;
  final ReportFontLoader loadFonts;

  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen> {
  /// Shops and menu items, fetched once for every kind's parameters.
  Future<ReportOptions>? _options;

  Future<ReportOptions> _loadOptions() =>
      _options ??= widget.repository.options().catchError((Object error) {
        _options = null;
        throw error;
      });

  void _open(ReportKindSpec kind) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportParametersScreen(
          kind: kind,
          repository: widget.repository,
          options: _loadOptions,
          saveFile: widget.saveFile,
          loadFonts: widget.loadFonts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.surfaceSunken,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _PageHeader(
                title: 'Reports',
                subtitle: 'Choose what type of report to generate',
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 164,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final kind = ReportKindSpec.all[index];
                  return _KindCard(kind: kind, onTap: () => _open(kind));
                }, childCount: ReportKindSpec.all.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.ink),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: palette.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _tone(BuildContext context, Color color) =>
    context.isDarkTheme ? Color.lerp(color, Colors.white, 0.35)! : color;

class _KindCard extends StatelessWidget {
  const _KindCard({required this.kind, required this.onTap});

  final ReportKindSpec kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      key: Key('report-kind-${kind.key}'),
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  kind.icon,
                  size: 19,
                  color: _tone(context, kind.color),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                kind.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  kind.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: palette.inkSecondary,
                  ),
                ),
              ),
              Row(
                children: [
                  const _FormatChip('PDF'),
                  const SizedBox(width: 6),
                  const _FormatChip('CSV'),
                  if (!kind.recorded) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Not recorded',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.inkTertiary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: palette.inkSecondary,
        ),
      ),
    );
  }
}

// =============================================================================
// Parameters, generation and download
// =============================================================================

enum _Preset { today, yesterday, last7, thisMonth, lastMonth, custom }

extension on _Preset {
  String get label => switch (this) {
    _Preset.today => 'Today',
    _Preset.yesterday => 'Yesterday',
    _Preset.last7 => 'Last 7 days',
    _Preset.thisMonth => 'This month',
    _Preset.lastMonth => 'Last month',
    _Preset.custom => 'Custom',
  };
}

class ReportParametersScreen extends StatefulWidget {
  const ReportParametersScreen({
    super.key,
    required this.kind,
    required this.repository,
    required this.options,
    this.saveFile = saveReportFile,
    this.loadFonts = _defaultFonts,
  });

  final ReportKindSpec kind;
  final FinanceReportRepository repository;
  final Future<ReportOptions> Function() options;
  final ReportFileSaver saveFile;
  final ReportFontLoader loadFonts;

  @override
  State<ReportParametersScreen> createState() => _ReportParametersScreenState();
}

class _ReportParametersScreenState extends State<ReportParametersScreen> {
  ReportOptions? _options;
  String? _optionsError;

  late DateTime _today;
  _Preset _preset = _Preset.today;
  late DateTimeRange _range;
  late DateTime _month;
  ReportShop? _shop;
  final Set<String> _items = {};

  bool _generating = false;
  String? _error;
  FinanceReport? _report;
  String? _saving;

  ReportKindSpec get kind => widget.kind;

  bool get _usesShop => kind.shop != ReportShopMode.none;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _setToday(DateTime(now.year, now.month, now.day));
    if (_usesShop || kind.pickItems) _loadOptions();
  }

  void _setToday(DateTime today) {
    _today = today;
    _month = DateTime(today.year, today.month);
    _range = _presetRange(_preset);
  }

  Future<void> _loadOptions() async {
    setState(() => _optionsError = null);
    try {
      final options = await widget.options();
      if (!mounted) return;
      setState(() {
        _options = options;
        // The campus calendar decides "today", not the device's clock.
        if (options.today != null) {
          final t = options.today!;
          _setToday(DateTime(t.year, t.month, t.day));
        }
      });
    } catch (error) {
      if (mounted) setState(() => _optionsError = error.toString());
    }
  }

  DateTimeRange _presetRange(_Preset preset) {
    final today = _today;
    return switch (preset) {
      _Preset.today => DateTimeRange(start: today, end: today),
      _Preset.yesterday => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today.subtract(const Duration(days: 1)),
      ),
      _Preset.last7 => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      _Preset.thisMonth => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      ),
      _Preset.lastMonth => DateTimeRange(
        start: DateTime(today.year, today.month - 1),
        end: DateTime(today.year, today.month, 0),
      ),
      _Preset.custom => _range,
    };
  }

  int get _rangeDays => _range.end.difference(_range.start).inDays + 1;

  String? get _validation {
    if (kind.shop == ReportShopMode.required && _shop == null) {
      return 'Choose a shop';
    }
    if (!kind.monthly && _rangeDays > kind.maxDays) {
      return 'Choose a range of at most ${kind.maxDays} days';
    }
    return null;
  }

  void _changed(VoidCallback update) => setState(() {
    update();
    _report = null;
    _error = null;
  });

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_today.year - 3),
      lastDate: _today,
      initialDateRange: _range,
      helpText: 'Report period',
    );
    if (picked == null) return;
    _changed(() {
      _preset = _Preset.custom;
      _range = DateTimeRange(
        start: DateUtils.dateOnly(picked.start),
        end: DateUtils.dateOnly(picked.end),
      );
    });
  }

  Future<void> _pickShop() async {
    final options = _options;
    if (options == null) return;
    final picked = await showModalBottomSheet<ReportShop?>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ShopSheet(
        shops: options.shops,
        selected: _shop,
        allowAll: kind.shop == ReportShopMode.optional,
      ),
    );
    if (!mounted || picked == null) return;
    _changed(() {
      _shop = picked.shopKey.isEmpty ? null : picked;
      // Items from another shop no longer apply.
      if (_shop != null) {
        final inShop = {
          for (final item in options.menuItems)
            if (item.shopKey == _shop!.shopKey) item.id,
        };
        _items.retainAll(inShop);
      }
    });
  }

  Future<void> _pickItems() async {
    final options = _options;
    if (options == null) return;
    final items = [
      for (final item in options.menuItems)
        if (_shop == null || item.shopKey == _shop!.shopKey) item,
    ];
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ItemsSheet(items: items, selected: _items),
    );
    if (picked == null) return;
    _changed(() {
      _items
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _generate() async {
    if (_validation != null) return;
    setState(() {
      _generating = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await widget.repository.generate(
        ReportRequest(
          kind: kind.key,
          from: kind.monthly ? null : _range.start,
          to: kind.monthly ? null : _range.end,
          month: kind.monthly ? _month : null,
          shopKey: _shop?.shopKey,
          itemIds: kind.pickItems ? _items.toList() : const [],
        ),
      );
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _download(String extension) async {
    final report = _report;
    if (report == null || _saving != null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = extension);
    try {
      final Uint8List bytes;
      if (extension == 'csv') {
        bytes = FinanceReportExporter.csvBytes(report);
      } else {
        final fonts = await widget.loadFonts();
        bytes = await FinanceReportExporter.pdf(
          report,
          regular: fonts?.regular,
          medium: fonts?.medium,
        );
      }
      final fileName = '${report.fileStem}.$extension';
      final saved = await widget.saveFile(
        fileName: fileName,
        bytes: bytes,
        extension: extension,
      );
      if (!saved) return;
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Saved $fileName')));
    } on ReportTooLargeForPdf catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the report. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final validation = _validation;
    return Scaffold(
      backgroundColor: palette.surfaceSunken,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            _PageHeader(title: kind.title, subtitle: kind.subtitle),
            if (!kind.recorded)
              _Section(
                child: _Notice(
                  icon: Icons.info_outline_rounded,
                  text:
                      'This platform keeps no record of this, so the report '
                      'will be empty. It can still be generated for your files.',
                ),
              ),
            _SectionLabel(kind.monthly ? 'Month' : 'Period'),
            _Section(
              child: kind.monthly
                  ? _monthPicker(context)
                  : _rangePicker(context),
            ),
            if (_usesShop || kind.pickItems) ...[
              _SectionLabel('Filters'),
              _Section(padding: EdgeInsets.zero, child: _filters(context)),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                key: const Key('report-generate'),
                onPressed: _generating || validation != null ? null : _generate,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _generating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text(
                        'Generate report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            if (validation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  validation,
                  style: TextStyle(fontSize: 13, color: palette.inkSecondary),
                ),
              ),
            if (_error != null)
              _Section(
                child: _Notice(
                  icon: Icons.error_outline_rounded,
                  text: _error!,
                  color: palette.danger,
                ),
              ),
            if (_report != null) ..._result(context, _report!),
          ],
        ),
      ),
    );
  }

  Widget _rangePicker(BuildContext context) {
    final palette = context.palette;
    final format = DateFormat('d MMM yyyy');
    final label = _range.start == _range.end
        ? format.format(_range.start)
        : '${format.format(_range.start)} – ${format.format(_range.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _Preset.values)
              ChoiceChip(
                key: Key('report-preset-${preset.name}'),
                label: Text(preset.label),
                selected: _preset == preset,
                showCheckmark: false,
                onSelected: (_) {
                  if (preset == _Preset.custom) {
                    _pickCustomRange();
                  } else {
                    _changed(() {
                      _preset = preset;
                      _range = _presetRange(preset);
                    });
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 18,
              color: palette.inkSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                key: const Key('report-range-label'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: palette.ink,
                ),
              ),
            ),
            Text(
              _rangeDays == 1 ? '1 day' : '$_rangeDays days',
              style: TextStyle(fontSize: 13, color: palette.inkSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _monthPicker(BuildContext context) {
    final palette = context.palette;
    final atLatest = _month.year == _today.year && _month.month == _today.month;
    return Row(
      children: [
        IconButton(
          key: const Key('report-month-previous'),
          tooltip: 'Previous month',
          onPressed: () =>
              _changed(() => _month = DateTime(_month.year, _month.month - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(_month),
            key: const Key('report-month-label'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        ),
        IconButton(
          key: const Key('report-month-next'),
          tooltip: 'Next month',
          onPressed: atLatest
              ? null
              : () => _changed(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _filters(BuildContext context) {
    final palette = context.palette;
    if (_options == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _optionsError == null
            ? Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading shops…',
                    style: TextStyle(color: palette.inkSecondary),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      _optionsError!,
                      style: TextStyle(color: palette.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadOptions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
      );
    }
    final itemsLabel = _items.isEmpty
        ? 'All items'
        : _items.length == 1
        ? '1 item'
        : '${_items.length} items';
    return Column(
      children: [
        if (_usesShop)
          _FilterRow(
            key: const Key('report-shop'),
            icon: Icons.storefront_rounded,
            label: 'Shop',
            value:
                _shop?.name ??
                (kind.shop == ReportShopMode.required
                    ? 'Choose a shop'
                    : 'All shops'),
            onTap: _pickShop,
          ),
        if (_usesShop && kind.pickItems)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 52,
            color: palette.divider,
          ),
        if (kind.pickItems)
          _FilterRow(
            key: const Key('report-items'),
            icon: Icons.restaurant_menu_rounded,
            label: 'Menu items',
            value: itemsLabel,
            onTap: _pickItems,
          ),
      ],
    );
  }

  List<Widget> _result(BuildContext context, FinanceReport report) {
    final palette = context.palette;
    return [
      _SectionLabel('Report ready'),
      _Section(
        child: Column(
          key: const Key('report-result'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [
                report.periodLabel,
                report.shopName ?? (_usesShop ? 'All shops' : ''),
              ].where((part) => part.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 13, color: palette.inkSecondary),
            ),
            if (report.summary.isNotEmpty) ...[
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: [
                      for (final stat in report.summary)
                        SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.inkSecondary,
                                ),
                              ),
                              Text(
                                FinanceReportExporter.display(
                                  stat.value,
                                  stat.format,
                                ),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: palette.ink,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            Text(
              report.isEmpty
                  ? (report.available
                        ? 'No records in this period.'
                        : 'No records exist for this report.')
                  : report.rowCount == 1
                  ? '1 row'
                  : '${NumberFormat.decimalPattern('en_IN').format(report.rowCount)} rows',
              key: const Key('report-row-count'),
              style: TextStyle(fontSize: 13, color: palette.inkSecondary),
            ),
            for (final note in report.notes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: palette.inkSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _DownloadButton(
                key: const Key('report-download-pdf'),
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                busy: _saving == 'pdf',
                onPressed: _saving == null ? () => _download('pdf') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DownloadButton(
                key: const Key('report-download-csv'),
                icon: Icons.table_chart_rounded,
                label: 'CSV',
                busy: _saving == 'csv',
                onPressed: _saving == null ? () => _download('csv') : null,
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 18, 32, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: context.palette.inkSecondary,
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.palette.inkSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.35, color: tone),
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.brandInk),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 15, color: palette.ink)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: palette.inkSecondary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.inkTertiary),
          ],
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    super.key,
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      backgroundColor: context.palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 19),
    label: Text(
      'Download $label',
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
}

class _ShopSheet extends StatelessWidget {
  const _ShopSheet({
    required this.shops,
    required this.selected,
    required this.allowAll,
  });

  final List<ReportShop> shops;
  final ReportShop? selected;
  final bool allowAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget tile(ReportShop shop, bool isSelected) => ListTile(
      key: Key(
        'report-shop-option-${shop.shopKey.isEmpty ? 'all' : shop.shopKey}',
      ),
      title: Text(shop.name),
      subtitle: shop.category.isEmpty
          ? null
          : Text(shop.category[0].toUpperCase() + shop.category.substring(1)),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: palette.brandInk)
          : null,
      onTap: () => Navigator.of(context).pop(shop),
    );
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (allowAll)
            tile(
              const ReportShop(shopKey: '', name: 'All shops'),
              selected == null,
            ),
          for (final shop in shops)
            tile(shop, selected?.shopKey == shop.shopKey),
          if (shops.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No shops are set up yet.',
                style: TextStyle(color: palette.inkSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemsSheet extends StatefulWidget {
  const _ItemsSheet({required this.items, required this.selected});

  final List<ReportMenuItem> items;
  final Set<String> selected;

  @override
  State<_ItemsSheet> createState() => _ItemsSheetState();
}

class _ItemsSheetState extends State<_ItemsSheet> {
  late final Set<String> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final item in widget.items)
        if (query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.shopName.toLowerCase().contains(query))
          item,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Menu items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(_selected.clear),
                  child: const Text('Clear'),
                ),
                FilledButton(
                  key: const Key('report-items-done'),
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search items',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selected.isEmpty
                    ? 'None selected: every item is included'
                    : '${_selected.length} selected',
                style: TextStyle(fontSize: 12.5, color: palette.inkSecondary),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'No menu items',
                      style: TextStyle(color: palette.inkSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return CheckboxListTile(
                        key: Key('report-item-${item.id}'),
                        value: _selected.contains(item.id),
                        title: Text(item.name),
                        subtitle: Text(item.shopName),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _selected.add(item.id);
                          } else {
                            _selected.remove(item.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
