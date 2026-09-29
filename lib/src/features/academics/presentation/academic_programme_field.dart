import 'package:flutter/material.dart';

import '../data/academic_models.dart';

/// A programme picker fed by the institution's academic catalog, for forms
/// that place a student (Student Master edit, imports). Choosing a programme
/// also settles the department: save `programme.departmentId` as the
/// student's `departmentId` and `programme.name` as the display label.
///
/// [initialProgrammeId] wins; otherwise the student's current department
/// link picks the programme ([AcademicCatalog.programmeForDepartment]).
class AcademicProgrammeField extends StatelessWidget {
  const AcademicProgrammeField({
    super.key,
    required this.catalog,
    required this.onChanged,
    this.initialProgrammeId,
    this.currentDepartmentId,
    this.currentDepartmentLabel = '',
    this.enabled = true,
  });

  final AcademicCatalog catalog;
  final ValueChanged<AcademicProgramme> onChanged;
  final String? initialProgrammeId;
  final String? currentDepartmentId;
  final String currentDepartmentLabel;
  final bool enabled;

  /// The programme the field starts on, or null when nothing matches.
  static AcademicProgramme? initialFor(
    AcademicCatalog catalog, {
    String? programmeId,
    String? departmentId,
    String departmentLabel = '',
  }) =>
      catalog.programmeById(programmeId) ??
      catalog.programmeForDepartment(
        departmentId,
        departmentLabel: departmentLabel,
      );

  @override
  Widget build(BuildContext context) {
    final initial = initialFor(
      catalog,
      programmeId: initialProgrammeId,
      departmentId: currentDepartmentId,
      departmentLabel: currentDepartmentLabel,
    );
    // Active programmes, plus the student's current one even if it was
    // deactivated, so opening the form never silently changes it.
    final options = [
      ...catalog.activeProgrammes,
      if (initial != null && !initial.active) initial,
    ];
    return DropdownButtonFormField<String>(
      initialValue: initial?.id,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Programme'),
      items: [
        for (final programme in options)
          DropdownMenuItem(
            value: programme.id,
            child: Text(programme.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (value) => value == null ? 'Choose a programme' : null,
      onChanged: enabled
          ? (value) {
              final programme = catalog.programmeById(value);
              if (programme != null) onChanged(programme);
            }
          : null,
    );
  }
}
