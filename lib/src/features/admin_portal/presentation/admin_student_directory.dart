import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_student_repository.dart';

/// One line of the student directory: a department subheader or a student.
sealed class StudentDirectoryItem {
  const StudentDirectoryItem();
}

class StudentDirectorySubheader extends StudentDirectoryItem {
  const StudentDirectorySubheader(this.label, this.count);
  final String label;
  final int count;
}

class StudentDirectoryRow extends StudentDirectoryItem {
  const StudentDirectoryRow(
    this.student, {
    required this.isFirst,
    required this.isLast,
  });
  final ManagedStudent student;

  /// Position inside its inset group, for the rounded corners and separators.
  final bool isFirst;
  final bool isLast;
}

/// A sticky section of the directory (a year, or the search results).
class StudentDirectorySection {
  const StudentDirectorySection({
    required this.title,
    required this.count,
    required this.items,
  });
  final String title;
  final int count;
  final List<StudentDirectoryItem> items;
}

/// Year value for students whose year of study is not recorded.
const int studentYearNotSet = 0;

String studentDirectoryYearTitle(int year) {
  if (year == studentYearNotSet) return 'Year not set';
  final suffix = switch (year) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
  return '$year$suffix Year';
}

String studentInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'S';
  final first = words.first.substring(0, 1);
  final last = words.length > 1 ? words.last.substring(0, 1) : '';
  return (first + last).toUpperCase();
}

/// "B.E in Computer Science" reads as "Computer Science" in a row subtitle.
String studentCourseLabel(String department) {
  final trimmed = department.trim();
  final index = trimmed.toLowerCase().indexOf(' in ');
  return index < 0 ? trimmed : trimmed.substring(index + 4).trim();
}

bool studentMatchesQuery(ManagedStudent student, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return '${student.name} ${student.rollNumber} ${student.department} '
          '${student.email} ${student.mobileNumber} ${student.section ?? ''}'
      .toLowerCase()
      .contains(needle);
}

int _byName(ManagedStudent left, ManagedStudent right) {
  final byName = left.name.toLowerCase().compareTo(right.name.toLowerCase());
  return byName != 0 ? byName : left.rollNumber.compareTo(right.rollNumber);
}

/// Filters [students] and lays them out: by year (sticky) then department
/// (subheaders) when browsing, or as one alphabetical list while searching.
List<StudentDirectorySection> buildStudentDirectory(
  List<ManagedStudent> students, {
  String query = '',
  int? year,
  String? department,
  ManagedStudentResidency? residency,
}) {
  final wantedDepartment = department?.trim().toLowerCase();
  final rows = [
    for (final student in students)
      if ((residency == null || student.residency == residency) &&
          (year == null || (student.yearOfStudy ?? studentYearNotSet) == year) &&
          (wantedDepartment == null ||
              student.department.trim().toLowerCase() == wantedDepartment) &&
          studentMatchesQuery(student, query))
        student,
  ]..sort(_byName);
  if (rows.isEmpty) return const [];

  if (query.trim().isNotEmpty) {
    return [
      StudentDirectorySection(
        title: rows.length == 1 ? '1 Result' : '${rows.length} Results',
        count: rows.length,
        items: [
          for (var index = 0; index < rows.length; index++)
            StudentDirectoryRow(
              rows[index],
              isFirst: index == 0,
              isLast: index == rows.length - 1,
            ),
        ],
      ),
    ];
  }

  final byYear = <int, Map<String, List<ManagedStudent>>>{};
  for (final student in rows) {
    final department = student.department.trim();
    byYear
        .putIfAbsent(student.yearOfStudy ?? studentYearNotSet, () => {})
        .putIfAbsent(department.isEmpty ? 'Unassigned' : department, () => [])
        .add(student);
  }
  final years = byYear.keys.toList()
    ..sort(
      (a, b) => a == studentYearNotSet
          ? 1
          : b == studentYearNotSet
          ? -1
          : a.compareTo(b),
    );
  return [
    for (final year in years)
      () {
        final departments = byYear[year]!;
        final names = departments.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final items = <StudentDirectoryItem>[];
        var count = 0;
        for (final name in names) {
          final members = departments[name]!;
          count += members.length;
          items.add(StudentDirectorySubheader(name, members.length));
          for (var index = 0; index < members.length; index++) {
            items.add(
              StudentDirectoryRow(
                members[index],
                isFirst: index == 0,
                isLast: index == members.length - 1,
              ),
            );
          }
        }
        return StudentDirectorySection(
          title: studentDirectoryYearTitle(year),
          count: count,
          items: items,
        );
      }(),
  ];
}

/// The admin console's student list: a large title with the count, a search
/// field, a compact filter row and an inset grouped list with sticky year
/// headers. Rows are built lazily, so a campus of thousands stays smooth.
class StudentDirectoryView extends StatefulWidget {
  const StudentDirectoryView({
    super.key,
    required this.students,
    required this.onOpen,
    this.onEdit,
    this.onRefresh,
    this.busyStudentId,
    this.title = 'Students',
  });

  final List<ManagedStudent> students;

  /// Opens the student's profile (from which it can be edited).
  final ValueChanged<ManagedStudent> onOpen;

  /// Goes straight to editing; offered on long press.
  final ValueChanged<ManagedStudent>? onEdit;
  final Future<void> Function()? onRefresh;
  final String? busyStudentId;
  final String title;

  @override
  State<StudentDirectoryView> createState() => _StudentDirectoryViewState();
}

class _StudentDirectoryViewState extends State<StudentDirectoryView> {
  final _search = TextEditingController();
  String _query = '';
  int? _year;
  String? _department;
  ManagedStudentResidency? _residency;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _year != null ||
      _department != null ||
      _residency != null ||
      _query.trim().isNotEmpty;

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _year = null;
      _department = null;
      _residency = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final students = widget.students;
    final sections = buildStudentDirectory(
      students,
      query: _query,
      year: _year,
      department: _department,
      residency: _residency,
    );
    final shown = sections.fold<int>(0, (sum, section) => sum + section.count);

    final years =
        students.map((s) => s.yearOfStudy ?? studentYearNotSet).toSet().toList()
          ..sort(
            (a, b) => a == studentYearNotSet
                ? 1
                : b == studentYearNotSet
                ? -1
                : a.compareTo(b),
          );
    final departments =
        students
            .map((s) => s.department.trim())
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final scroll = CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _filtered
                      ? '$shown of ${students.length} students'
                      : students.length == 1
                      ? '1 student'
                      : '${students.length} students',
                  key: const Key('student-directory-count'),
                  style: TextStyle(fontSize: 15, color: palette.inkSecondary),
                ),
                const SizedBox(height: 12),
                _SearchField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              children: [
                _FilterMenu<int>(
                  key: const Key('student-filter-year'),
                  icon: Icons.calendar_today_outlined,
                  label: _year == null
                      ? 'Year'
                      : studentDirectoryYearTitle(_year!),
                  active: _year != null,
                  options: [
                    const _MenuOption(null, 'All years'),
                    for (final year in years)
                      _MenuOption(year, studentDirectoryYearTitle(year)),
                  ],
                  onSelected: (value) => setState(() => _year = value),
                ),
                const SizedBox(width: 8),
                _FilterMenu<String>(
                  key: const Key('student-filter-department'),
                  icon: Icons.apartment_outlined,
                  label: _department == null
                      ? 'Department'
                      : studentCourseLabel(_department!),
                  active: _department != null,
                  options: [
                    const _MenuOption(null, 'All departments'),
                    for (final department in departments)
                      _MenuOption(department, department),
                  ],
                  onSelected: (value) => setState(() => _department = value),
                ),
                const SizedBox(width: 8),
                _FilterMenu<ManagedStudentResidency>(
                  key: const Key('student-filter-residency'),
                  icon: Icons.home_work_outlined,
                  label: switch (_residency) {
                    null => 'Residency',
                    ManagedStudentResidency.dayScholar => 'Day scholars',
                    ManagedStudentResidency.hosteller => 'Hostellers',
                  },
                  active: _residency != null,
                  options: const [
                    _MenuOption(null, 'Everyone'),
                    _MenuOption(
                      ManagedStudentResidency.dayScholar,
                      'Day scholars',
                    ),
                    _MenuOption(ManagedStudentResidency.hosteller, 'Hostellers'),
                  ],
                  onSelected: (value) => setState(() => _residency = value),
                ),
                if (_filtered) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    key: const Key('student-filter-clear'),
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (sections.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              filtered: _filtered,
              onClear: _clearFilters,
            ),
          )
        else
          for (final section in sections)
            SliverMainAxisGroup(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SectionHeaderDelegate(
                    title: section.title,
                    count: section.count,
                    background: Theme.of(context).scaffoldBackgroundColor,
                    palette: palette,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverList.builder(
                    itemCount: section.items.length,
                    itemBuilder: (context, index) =>
                        switch (section.items[index]) {
                          StudentDirectorySubheader(:final label, :final count) =>
                            _Subheader(label: label, count: count),
                          final StudentDirectoryRow row => _StudentRow(
                            key: ValueKey('student-row-${row.student.id}'),
                            row: row,
                            busy: widget.busyStudentId == row.student.id,
                            onTap: () => widget.onOpen(row.student),
                            onLongPress: widget.onEdit == null
                                ? null
                                : () => widget.onEdit!(row.student),
                          ),
                        },
                  ),
                ),
              ],
            ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );

    final refresh = widget.onRefresh;
    return refresh == null
        ? scroll
        : RefreshIndicator(onRefresh: refresh, child: scroll);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        key: const Key('student-search'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 16, color: palette.ink),
        decoration: InputDecoration(
          hintText: 'Search name, roll number or email',
          isDense: true,
          filled: true,
          fillColor: palette.surfaceSunken,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: palette.inkSecondary,
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: palette.inkTertiary,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _MenuOption<T> {
  const _MenuOption(this.value, this.label);
  final T? value;
  final String label;
}

/// A compact pill that opens a menu; filled while a value is chosen.
class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool active;
  final List<_MenuOption<T>> options;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = active ? palette.brandInk : palette.ink;
    return PopupMenuButton<_MenuOption<T>>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: (option) => onSelected(option.value),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(
            value: option,
            child: Text(
              option.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? palette.brandSoft : palette.surfaceSunken,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({
    required this.title,
    required this.count,
    required this.background,
    required this.palette,
  });

  final String title;
  final int count;
  final Color background;
  final AppPalette palette;

  static const double _height = 44;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      alignment: Alignment.bottomLeft,
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: palette.ink,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(fontSize: 15, color: palette.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) =>
      oldDelegate.title != title ||
      oldDelegate.count != count ||
      oldDelegate.background != background ||
      oldDelegate.palette != palette;
}

class _Subheader extends StatelessWidget {
  const _Subheader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color: palette.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: palette.inkTertiary),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    super.key,
    required this.row,
    required this.busy,
    required this.onTap,
    this.onLongPress,
  });

  final StudentDirectoryRow row;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final student = row.student;
    const radius = Radius.circular(12);
    final shape = BorderRadius.vertical(
      top: row.isFirst ? radius : Radius.zero,
      bottom: row.isLast ? radius : Radius.zero,
    );
    final hosteller = student.residency == ManagedStudentResidency.hosteller;
    final subtitle = [
      if (student.rollNumber.trim().isNotEmpty) student.rollNumber.trim(),
      if (studentCourseLabel(student.department).isNotEmpty)
        studentCourseLabel(student.department),
    ].join(' · ');

    return Material(
      color: palette.surface,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Semantics(
          button: true,
          label: '${student.name}, ${student.residency.label}',
          excludeSemantics: false,
          child: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: palette.brandSoft,
                  foregroundColor: palette.brandInk,
                  child: Text(
                    studentInitials(student.name),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: row.isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: palette.divider,
                                width: 0.5,
                              ),
                            ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: palette.ink,
                                  ),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: palette.inkSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: hosteller
                                  ? palette.brandSoft
                                  : palette.infoSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hosteller ? 'Hosteller' : 'Day scholar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hosteller
                                    ? palette.brandInk
                                    : palette.info,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (busy)
                            const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: palette.inkTertiary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.onClear});
  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: palette.inkTertiary),
          const SizedBox(height: 12),
          Text(
            filtered ? 'No matching students' : 'No students yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          if (filtered) ...[
            const SizedBox(height: 4),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ],
      ),
    );
  }
}
