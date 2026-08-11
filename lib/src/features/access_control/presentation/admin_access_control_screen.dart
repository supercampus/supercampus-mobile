import 'package:flutter/material.dart';

import '../../../core/access/demo_access_control_store.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';

class AdminAccessControlScreen extends StatefulWidget {
  const AdminAccessControlScreen({
    super.key,
    required this.session,
    required this.onSignOut,
  });
  final UserSession session;
  final VoidCallback onSignOut;
  @override
  State<AdminAccessControlScreen> createState() =>
      _AdminAccessControlScreenState();
}

class _AdminAccessControlScreenState extends State<AdminAccessControlScreen> {
  final _store = DemoAccessControlStore.instance;
  final _userController = TextEditingController(text: 'abc@example.com');
  var _surface = 'app';
  var _moduleId = ModuleCatalog.examination;
  late String _featureId = ModuleCatalog.byId(_moduleId)!.features.first.id;
  final _actions = <String>{};

  ModuleDescriptor get _module => ModuleCatalog.byId(_moduleId)!;
  FeatureDescriptor get _feature => _module.feature(_featureId)!;

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  void _selectModule(String? value) {
    if (value == null) return;
    setState(() {
      _moduleId = value;
      _featureId = ModuleCatalog.byId(value)!.features.first.id;
      _actions.clear();
    });
  }

  void _selectFeature(String? value) {
    if (value == null) return;
    setState(() {
      _featureId = value;
      _actions.clear();
    });
  }

  void _save() {
    final email = _userController.text.trim().toLowerCase();
    if (email.isEmpty || _actions.isEmpty) return;
    _store.save(
      userEmail: email,
      surface: _surface,
      moduleId: _moduleId,
      featureId: _featureId,
      actions: _actions,
    );
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Access saved for $email')));
  }

  @override
  Widget build(BuildContext context) {
    final email = _userController.text.trim().toLowerCase();
    final assignments = _store.forUser(email, surface: _surface);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: const Text('Access control'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'APP ACCESS CONTROL',
            style: TextStyle(
              color: AppColors.muted,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Assign module and feature permissions to a user.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _userController,
            decoration: const InputDecoration(
              labelText: 'User email / username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _surface,
            decoration: const InputDecoration(labelText: 'Access surface'),
            items: const [
              DropdownMenuItem(value: 'app', child: Text('App access control')),
              DropdownMenuItem(
                value: 'website',
                child: Text('Website access control'),
              ),
            ],
            onChanged: (value) => setState(() => _surface = value ?? _surface),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _moduleId,
            decoration: const InputDecoration(labelText: 'Module'),
            items: [
              for (final module in ModuleCatalog.all)
                DropdownMenuItem(value: module.id, child: Text(module.title)),
            ],
            onChanged: _selectModule,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _featureId,
            decoration: const InputDecoration(labelText: 'Feature'),
            items: [
              for (final feature in _module.features)
                DropdownMenuItem(value: feature.id, child: Text(feature.label)),
            ],
            onChanged: _selectFeature,
          ),
          const SizedBox(height: 14),
          const Text(
            'CRUD / workflow permissions',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final action in _feature.actions)
                FilterChip(
                  label: Text(action.toUpperCase()),
                  selected: _actions.contains(action),
                  onSelected: (selected) => setState(
                    () => selected
                        ? _actions.add(action)
                        : _actions.remove(action),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Assign access'),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current assignments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                email.isEmpty ? 'No user' : email,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (assignments.isEmpty)
            const Text(
              'No app permissions assigned yet.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            for (final assignment in assignments)
              _AssignmentCard(
                assignment: assignment,
                onRemove: () {
                  _store.remove(assignment);
                  setState(() {});
                },
              ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment, required this.onRemove});
  final DemoAccessAssignment assignment;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final module = ModuleCatalog.byId(assignment.moduleId);
    final feature = module?.feature(assignment.featureId);
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(
          '${module?.title ?? assignment.moduleId} · ${feature?.label ?? assignment.featureId}',
        ),
        subtitle: Text(assignment.actions.join(' · ').toUpperCase()),
        trailing: IconButton(
          tooltip: 'Remove access',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}
