import 'academic_models.dart';

class MockAcademicRepository {
  final programmes = <AcademicProgramme>[
    const AcademicProgramme(
      code: 'BTECH-CSE',
      name: 'B.Tech Computer Science',
      duration: '4 years',
      status: 'Active',
    ),
    const AcademicProgramme(
      code: 'BBA',
      name: 'Bachelor of Business Administration',
      duration: '3 years',
      status: 'Active',
    ),
  ];
  final subjects = <AcademicSubject>[
    const AcademicSubject(
      code: 'CS601',
      name: 'Distributed Systems',
      credits: 4,
      programme: 'B.Tech Computer Science',
    ),
    const AcademicSubject(
      code: 'CS602',
      name: 'Machine Learning',
      credits: 4,
      programme: 'B.Tech Computer Science',
    ),
    const AcademicSubject(
      code: 'CS603',
      name: 'Cloud Computing Lab',
      credits: 2,
      programme: 'B.Tech Computer Science',
    ),
  ];
  final batches = <AcademicBatch>[
    const AcademicBatch(
      name: 'CSE 2023',
      programme: 'B.Tech Computer Science',
      section: 'A',
      students: 62,
    ),
    const AcademicBatch(
      name: 'CSE 2023',
      programme: 'B.Tech Computer Science',
      section: 'B',
      students: 58,
    ),
    const AcademicBatch(
      name: 'BBA 2024',
      programme: 'Bachelor of Business Administration',
      section: 'A',
      students: 48,
    ),
  ];
}
