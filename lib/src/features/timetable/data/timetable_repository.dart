import 'timetable_models.dart';

abstract interface class TimetableRepository {
  TimetableConfig getConfig();
  void updateConfig(TimetableConfig config);

  List<String> getAvailableClasses();
  List<FacultyMember> getFacultyList();
  List<FacultySubjectQuota> getFacultyQuotas();
  void addFacultyQuota(FacultySubjectQuota quota);
  void updateFacultyQuota(FacultySubjectQuota quota);
  void deleteFacultyQuota(String id);
  void importFacultyQuotas(List<FacultySubjectQuota> quotas);

  List<TimetableVersion> getVersions();
  TimetableVersion? getActiveVersion(String className);

  List<TimetableEntry> getEntriesForClass(String className);
  List<TimetableEntry> getEntriesForFaculty(String facultyName);

  void addEntry(TimetableEntry entry);
  void updateEntry(TimetableEntry entry);
  void deleteEntry(String entryId);

  List<ConflictItem> getConflicts();
  List<ConflictItem> runConflictDetection(List<TimetableEntry> entries);
  void resolveConflict(String conflictId);

  TimetableVersion publishTimetable(String versionId);
  TimetableVersion saveNewVersion(String title, List<TimetableEntry> entries);

  List<DisruptionAlert> getDisruptionAlerts();
  void resolveDisruptionAlert(String alertId, String chosenSubstitute);

  List<FacultySubstitution> getSubstitutions();
  void requestSubstitution(FacultySubstitution sub);
  void approveSubstitution(String subId);
  void rejectSubstitution(String subId);

  List<TimetableEntry> generateAiCandidate(TimetableConfig config);
}
