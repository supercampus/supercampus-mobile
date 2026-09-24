import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../library/data/librarian_repository.dart';
import 'dashboard_nav_bar.dart';
import 'student_reports_page.dart';

class CampusWallNotice {
  const CampusWallNotice({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.author,
    required this.date,
    this.attachmentName,
    this.attachmentUrl,
    this.isUrgent = false,
  });

  final String id;
  final String category;
  final String title;
  final String content;
  final String author;
  final DateTime date;
  final String? attachmentName;
  final String? attachmentUrl;
  final bool isUrgent;
}

class CampusWallScreen extends StatefulWidget {
  const CampusWallScreen({
    super.key,
    this.announcementRepository,
    this.session,
    this.onOpenModule,
    this.onNavSelect,
  });

  final LibrarianRepository? announcementRepository;
  final UserSession? session;
  final ValueChanged<String>? onOpenModule;
  final ValueChanged<String>? onNavSelect;

  @override
  State<CampusWallScreen> createState() => _CampusWallScreenState();
}

class _CampusWallScreenState extends State<CampusWallScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  List<CampusWallNotice> _notices = [];

  final List<String> _filters = const [
    'All',
    'Circulars',
    'Announcements',
    'Examinations',
    'Events',
    'Academics',
    'Administrative',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _isLoading = true);
    final items = <CampusWallNotice>[];

    // 1. Resolve repository (either passed in or constructed from session)
    var repo = widget.announcementRepository;
    if (repo == null && widget.session?.jwtToken != null) {
      repo = LibrarianRepository(
        baseUrl: const String.fromEnvironment(
          'SUPERCAMPUS_API_BASE_URL',
          defaultValue: 'https://api.supercampus.ai',
        ),
        accessToken: widget.session!.jwtToken,
      );
    }

    if (repo != null) {
      try {
        final repoAnnouncements = await repo.announcements();
        for (final item in repoAnnouncements) {
          final authorDisplay = _resolveAuthor(item);
          items.add(
            CampusWallNotice(
              id: item.id,
              category: _mapCategory(item.type),
              title: item.title,
              content: item.message,
              author: authorDisplay,
              date: item.announcementDate,
              attachmentName: item.attachmentName,
              attachmentUrl: item.attachmentUrl,
              isUrgent: item.type.toLowerCase().contains('urgent') ||
                  item.type.toLowerCase().contains('exam'),
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to load campus announcements: $e');
      }
    }

    // Sort newest first
    items.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _notices = items;
        _isLoading = false;
      });
    }
  }

  String _resolveAuthor(LibraryAnnouncement item) {
    if (item.createdByEmail != null && item.createdByEmail!.isNotEmpty) {
      final email = item.createdByEmail!.trim().toLowerCase();
      if (email == 'admin@mec.local') return 'admin@mec.local';
      return item.createdByEmail!;
    }
    final name = item.createdByName.trim();
    if (name.toLowerCase() == 'admin@mec.local' ||
        name.toLowerCase() == 'arun iyer' ||
        name.toLowerCase().contains('admin')) {
      return 'admin@mec.local';
    }
    return name.isNotEmpty ? name : 'admin@mec.local';
  }

  String _mapCategory(String type) {
    final lower = type.toLowerCase().trim();
    if (lower.contains('circular') || lower.contains('order')) return 'Circulars';
    if (lower.contains('announcement') || lower == 'general' || lower == 'news') {
      return 'Announcements';
    }
    if (lower.contains('exam') ||
        lower.contains('result') ||
        lower.contains('test') ||
        lower.contains('assessment')) {
      return 'Examinations';
    }
    if (lower.contains('event') ||
        lower.contains('fest') ||
        lower.contains('sports') ||
        lower.contains('cultural') ||
        lower.contains('celebration')) {
      return 'Events';
    }
    if (lower.contains('acad') ||
        lower.contains('course') ||
        lower.contains('class') ||
        lower.contains('syllabus')) {
      return 'Academics';
    }
    return 'Administrative';
  }

  List<CampusWallNotice> get _filteredNotices {
    return _notices.where((notice) {
      final matchesFilter = _selectedFilter == 'All' ||
          notice.category.toLowerCase() == _selectedFilter.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          notice.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          notice.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          notice.author.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF141416) : const Color(0xFFF7F7F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = const Color(0xFF8E8E93);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Material(
              color: isDark ? const Color(0xFF2A2A2E) : Colors.white,
              shape: const CircleBorder(),
              elevation: isDark ? 0 : 1,
              shadowColor: Colors.black.withValues(alpha: 0.04),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: textColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Column(
          children: [
            Text(
              'Campus Wall',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Announcements & Circulars',
              style: TextStyle(
                color: mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotices,
        child: CustomScrollView(
          slivers: [
            // Search Bar & Filter Strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222226) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2C2C30)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search notices, circulars, tags...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: mutedColor,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: mutedColor,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Chips
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final filter = _filters[idx];
                          final isSelected = _selectedFilter == filter;
                          return ChoiceChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? const Color(0xFFD1D1D6)
                                        : const Color(0xFF48484A)),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF4F46E5),
                            backgroundColor: isDark
                                ? const Color(0xFF222226)
                                : Colors.white,
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF4F46E5)
                                  : (isDark
                                      ? const Color(0xFF2C2C30)
                                      : const Color(0xFFE5E7EB)),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            onSelected: (_) {
                              setState(() => _selectedFilter = filter);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Wall feed items
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: ThinkingOrbLoading(size: 80),
                ),
              )
            else if (_filteredNotices.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.feed_outlined,
                        size: 48,
                        color: mutedColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No announcements found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Official notices and circulars published by admin@mec.local will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: mutedColor),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _filteredNotices[index];
                      return _NoticeCard(
                        notice: item,
                        isDark: isDark,
                        textColor: textColor,
                        mutedColor: mutedColor,
                        onTap: () => _showNoticeDetail(context, item),
                      );
                    },
                    childCount: _filteredNotices.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: DashboardNavBar(
        selectedId: 'wall',
        onSelect: _handleNavSelect,
      ),
    );
  }

  void _handleNavSelect(String id) {
    if (widget.onNavSelect != null) {
      widget.onNavSelect!(id);
      return;
    }
    switch (id) {
      case 'wall':
        // Already on wall
        break;
      case 'analysis':
        if (widget.session != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => StudentReportsPage(
                session: widget.session!,
                onOpenModule: widget.onOpenModule,
                announcementRepository: widget.announcementRepository,
              ),
            ),
          );
        }
        break;
      case 'acads':
        Navigator.of(context).pop();
        widget.onOpenModule?.call(ModuleCatalog.academics);
        break;
      case 'gatepass':
        Navigator.of(context).pop();
        widget.onOpenModule?.call(ModuleCatalog.gatepass);
        break;
    }
  }

  void _showNoticeDetail(BuildContext context, CampusWallNotice notice) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF222226) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.94,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF38383E) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _categoryColor(notice.category).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notice.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _categoryColor(notice.category),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(notice.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                notice.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_pin_circle_outlined,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Issued by: ${notice.author}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 14),
              Text(
                notice.content,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              if (notice.attachmentName != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C30)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF38383E)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFFEF4444),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notice.attachmentName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Official attachment document',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final value = notice.attachmentUrl;
                          if (value != null && value.isNotEmpty) {
                            final uri = Uri.tryParse(value);
                            if (uri != null &&
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                )) {
                              return;
                            }
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Viewing ${notice.attachmentName}...',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  static Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'circulars':
        return const Color(0xFF2563EB); // Blue
      case 'announcements':
        return const Color(0xFF7C3AED); // Purple
      case 'examinations':
        return const Color(0xFFDC2626); // Red
      case 'events':
        return const Color(0xFFD97706); // Amber
      case 'academics':
        return const Color(0xFF059669); // Emerald
      default:
        return const Color(0xFF4F46E5); // Indigo
    }
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  final CampusWallNotice notice;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catColor = _CampusWallScreenState._categoryColor(notice.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222226) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFF0F0F2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header: Author & Tag
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: catColor.withValues(alpha: 0.12),
                      child: Icon(
                        _iconForCategory(notice.category),
                        size: 15,
                        color: catColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          Text(
                            _CampusWallScreenState._formatDate(notice.date),
                            style: TextStyle(
                              fontSize: 11,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notice.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  notice.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Excerpt
                Text(
                  notice.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: mutedColor,
                    height: 1.4,
                  ),
                ),

                // PDF / Attachment pill if present
                if (notice.attachmentName != null) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final isPdf = notice.attachmentName!.toLowerCase().endsWith('.pdf') ||
                          (notice.attachmentUrl?.toLowerCase().contains('.pdf') ?? false);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPdf
                              ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.18 : 0.08)
                              : isDark
                              ? const Color(0xFF2C2C30)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: isPdf
                              ? Border.all(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPdf
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.attachment_rounded,
                              size: 14,
                              color: isPdf
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                notice.attachmentName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isPdf
                                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                                      : const Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'circulars':
        return Icons.description_rounded;
      case 'announcements':
        return Icons.campaign_rounded;
      case 'examinations':
        return Icons.assignment_turned_in_rounded;
      case 'events':
        return Icons.celebration_rounded;
      case 'academics':
        return Icons.school_rounded;
      default:
        return Icons.apartment_rounded;
    }
  }
}
