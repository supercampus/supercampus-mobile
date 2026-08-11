import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  final String _selectedRoll = '2026CS101';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchHeader(isMobile),
              const SizedBox(height: 14),
              _buildTranscriptDocumentCard(isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader(bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Academic Transcript Generator',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Downloading official Transcript PDF...'),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text(
                  'Download Official PDF',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Official Academic Transcript Generator',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Generate digitally signed official transcripts with cryptographic QR verification.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Downloading official Transcript PDF...'),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Download Official PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptDocumentCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUPERCAMPUS UNIVERSITY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'Office of the Controller of Examinations',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Transcript ID: SC-TR-2026-9041 • Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUPERCAMPUS UNIVERSITY',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Office of the Controller of Examinations',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Official Academic Record & Transcript of Marks',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Transcript ID: SC-TR-2026-9041',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Issue Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          const Divider(height: 24, thickness: 1.5),

          // Student Details Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student Name: Alex Johnson',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                Text(
                  'Roll Number: $_selectedRoll • B.Tech CSE',
                  style: const TextStyle(fontSize: 11),
                ),
                const Text(
                  'Standing: Distinction',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Semester Grades Table Preview
          const Text(
            'Semester Academic Performance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: AppColors.border, width: 1),
              children: const [
                TableRow(
                  decoration: BoxDecoration(color: AppColors.canvas),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Subject Code & Title',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Credits',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Grade',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'GP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'CS301 Data Structures & Algorithms',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('4', style: TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'O',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('10', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'CS302 Database Management Systems',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('4', style: TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'A+',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('9', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'CS303 Operating Systems',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('3', style: TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('8', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Footer & Digital Signature
          Row(
            children: [
              QrImageView(
                data: 'VERIFY-TRANSCRIPT-SC-TR-2026-9041-HASH-e9f3b2a0',
                version: QrVersions.auto,
                size: isMobile ? 65.0 : 80.0,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Digital Signature Verified',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'SHA-256 Hash Verified',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                    Text(
                      'https://supercampus.edu/verify',
                      style: TextStyle(fontSize: 10, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
