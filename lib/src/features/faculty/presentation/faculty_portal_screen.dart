import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/faculty_models.dart';
import '../data/mock_faculty_repository.dart';

class FacultyPortalScreen extends StatefulWidget {
  const FacultyPortalScreen({
    super.key,
    required this.session,
    required this.onSignOut,
    this.onExitModule,
  });

  final UserSession session;
  final VoidCallback onSignOut;
  final VoidCallback? onExitModule;

  @override
  State<FacultyPortalScreen> createState() => _FacultyPortalScreenState();
}

class _FacultyPortalScreenState extends State<FacultyPortalScreen> {
  final _repository = MockFacultyRepository();
  int _currentTab = 0;

  late List<FacultyCourse> _courses;
  late List<FacultyAcademicLeaveRequest> _leaveRequests;
  late List<DepartmentNotice> _notices;

  String _selectedCourseCode = 'CS301';
  late List<StudentAttendanceItem> _activeRoster;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _courses = _repository.getCourses();
      _leaveRequests = _repository.getLeaveRequests();
      _notices = _repository.getNotices();
      _activeRoster = _repository.getRoster(_selectedCourseCode);
    });
  }

  void _createNoticeDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String target = 'All CS Students & Parents';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Color(0xFF6A1B9A)),
            SizedBox(width: 8),
            Text('Post Faculty Announcement'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Notice Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notice Content'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
            ),
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                final newNotice = DepartmentNotice(
                  id: 'NOT-${DateTime.now().millisecondsSinceEpoch % 1000}',
                  title: titleCtrl.text,
                  content: contentCtrl.text,
                  postedAt: DateTime.now(),
                  author: widget.session.displayName,
                  targetAudience: target,
                );
                _repository.addNotice(newNotice);
                _refreshData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notice published to portal!'),
                    backgroundColor: Color(0xFF6A1B9A),
                  ),
                );
              }
            },
            child: const Text('Publish Notice'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _leaveRequests.where((l) => l.status == 'Pending').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        leading: widget.onExitModule != null
            ? IconButton(
                tooltip: 'Modules Home',
                icon: const Icon(Icons.home),
                onPressed: widget.onExitModule,
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.badge, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff & Faculty Portal',
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${widget.session.displayName} • ${widget.session.departmentOrWard ?? "CS Dept"}',
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: widget.onSignOut,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildClassesAndAttendanceTab(),
          _buildAcademicApprovalsTab(),
          _buildNoticeboardTab(),
          _buildStudentDirectoryTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.swipe_outlined),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.assignment_turned_in_outlined),
            ),
            label: 'Leave Approvals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            label: 'Noticeboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Student Directory',
          ),
        ],
      ),
    );
  }

  Widget _buildClassesAndAttendanceTab() {
    final presentCount =
        _activeRoster.where((i) => i.attendanceStatus == 'Present').length;
    final absentCount =
        _activeRoster.where((i) => i.attendanceStatus == 'Absent').length;
    final odCount = _activeRoster
        .where((i) => i.attendanceStatus.contains('OD'))
        .length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Digital Attendance Sheet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Swipe cards right/left to mark attendance dynamically',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _courses.map((course) {
              final isSelected = _selectedCourseCode == course.code;
              return Container(
                width: 270,
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCourseCode = course.code;
                      _activeRoster = _repository.getRoster(course.code);
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6A1B9A)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6A1B9A)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${course.code} • ${course.section}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white70
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.name,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${course.roomNumber} (${course.totalEnrolled} Enrolled)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white70
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Swipe Instructions & Summary Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF2F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 18, color: Color(0xFF4A148C)),
                  SizedBox(width: 8),
                  Text(
                    'Interactive Swipe Attendance Controls:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_forward,
                              size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Swipe Right: ABSENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back,
                              size: 14, color: Colors.amber.shade800),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Swipe Left: OD CONSENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Counters
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Roster for $_selectedCourseCode:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                _counterBadge('Present', '$presentCount', const Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                _counterBadge('Absent', '$absentCount', const Color(0xFFD9383A)),
                const SizedBox(width: 6),
                _counterBadge('OD', '$odCount', Colors.amber.shade800),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Student Cards list with Dismissible swipe right (Absent) / swipe left (OD)
        ..._activeRoster.map((item) {
          return _SwipeableStudentCard(
            key: ValueKey(item.rollNumber + item.attendanceStatus),
            item: item,
            onStatusChanged: (newStatus) {
              setState(() {
                item.attendanceStatus = newStatus;
              });
            },
          );
        }),

        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4A148C),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Attendance submitted for $_selectedCourseCode! ($presentCount Present, $absentCount Absent, $odCount OD)'),
                backgroundColor: const Color(0xFF4A148C),
              ),
            );
          },
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text(
            'Save & Publish Attendance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _counterBadge(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAcademicApprovalsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Student Academic Leave & Duty Approvals',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Review duty leaves, lab exemptions & symposium passes',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        ..._leaveRequests.map((req) {
          final isPending = req.status == 'Pending';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isPending ? Colors.amber.shade400 : Colors.grey.shade200,
                width: isPending ? 1.5 : 1,
              ),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        req.studentName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${req.rollNumber})',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(req.status),
                        backgroundColor: isPending
                            ? Colors.amber.shade100
                            : const Color(0xFFE8F5E9),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isPending
                              ? Colors.amber.shade900
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    req.leaveType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6A1B9A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Reason: ${req.reason}'),
                  const SizedBox(height: 14),
                  if (isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () {
                              _repository.reviewLeave(req.id, false);
                              _refreshData();
                            },
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6A1B9A),
                            ),
                            onPressed: () {
                              _repository.reviewLeave(req.id, true);
                              _refreshData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Duty leave approved!'),
                                  backgroundColor: Color(0xFF6A1B9A),
                                ),
                              );
                            },
                            child: const Text('Approve Duty Leave'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNoticeboardTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Department Noticeboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Announcements broadcast to Student & Parent portals',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
              ),
              onPressed: _createNoticeDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Notice'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._notices.map((notice) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign,
                          color: Color(0xFF6A1B9A), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notice.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(notice.content),
                  const SizedBox(height: 12),
                  Text(
                    'Posted by ${notice.author} • Target: ${notice.targetAudience}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStudentDirectoryTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Student Academic Directory',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'View enrolled students and academic performance',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search student by name or roll number...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._activeRoster.map((st) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFF3E5F5),
                child: Text(
                  st.studentName.substring(0, 1),
                  style: const TextStyle(
                      color: Color(0xFF6A1B9A), fontWeight: FontWeight.w500),
                ),
              ),
              title: Text(
                st.studentName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('${st.rollNumber} • CS Dept Year 3'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Student profile loaded for ${st.studentName}'),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _SwipeableStudentCard extends StatelessWidget {
  const _SwipeableStudentCard({
    super.key,
    required this.item,
    required this.onStatusChanged,
  });

  final StudentAttendanceItem item;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(item.rollNumber + item.attendanceStatus),
        // Swipe Right (Start -> End): RED Background for ABSENT
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFD9383A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.person_remove_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'SWIPED ABSENT (RED)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        // Swipe Left (End -> Start): YELLOW Background for OD CONSENT
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.amber.shade700,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'OD CONSENTED (YELLOW)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.verified_user_rounded, color: Colors.white, size: 28),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Swiped Right -> Mark ABSENT (Red)
            onStatusChanged('Absent');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(milliseconds: 1200),
                backgroundColor: const Color(0xFFD9383A),
                content: Text('👉 ${item.studentName} marked ABSENT (Red)'),
              ),
            );
          } else if (direction == DismissDirection.endToStart) {
            // Swiped Left -> Mark OD CONSENTED (Yellow)
            item.isODConsented = true;
            onStatusChanged('On Duty (OD)');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(milliseconds: 1200),
                backgroundColor: Colors.amber.shade800,
                content: Text(
                    '👈 ${item.studentName} marked ON DUTY - OD Consented (Yellow)'),
              ),
            );
          }
          return false; // Retain card in list after state change
        },
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _borderColor(item.attendanceStatus),
              width: item.attendanceStatus != 'Present' ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              // Tap to cycle back to Present (Green)
              onStatusChanged('Present');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(milliseconds: 900),
                  backgroundColor: const Color(0xFF2E7D32),
                  content: Text('Reset ${item.studentName} to PRESENT (Green)'),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            _statusColor(item.attendanceStatus).withValues(alpha: 0.15),
                        child: Text(
                          item.studentName.substring(0, 1),
                          style: TextStyle(
                            color: _statusColor(item.attendanceStatus),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              item.rollNumber,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusPill(item),
                    ],
                  ),
                  if (item.isApprovedOD) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified,
                              size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'OD Approval Matrix: ${item.odReason ?? "Approved Leave Pass"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(StudentAttendanceItem item) {
    final (label, color, icon) = switch (item.attendanceStatus) {
      'Present' => (
          'PRESENT',
          const Color(0xFF2E7D32),
          Icons.check_circle_outline
        ),
      'Absent' => ('ABSENT', const Color(0xFFD9383A), Icons.cancel_outlined),
      _ => (
          item.isODConsented ? 'OD CONSENTED' : 'OD APPROVED',
          Colors.amber.shade800,
          Icons.verified_outlined
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'Present') return const Color(0xFF2E7D32);
    if (status == 'Absent') return const Color(0xFFD9383A);
    return Colors.amber.shade800;
  }

  Color _borderColor(String status) {
    if (status == 'Present') return const Color(0xFFC8E6C9);
    if (status == 'Absent') return const Color(0xFFFFCDD2);
    return Colors.amber.shade300;
  }
}
