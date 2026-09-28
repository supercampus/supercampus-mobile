import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../data/accountant_wallet_repository.dart';
import '../data/canteen_models.dart';

/// The accountant's wallet desk: recharge any campus user's store wallets
/// (canteen, stationery, laundry), review the ledger and set the online
/// top-up limits.
class AccountantWalletScreen extends StatefulWidget {
  const AccountantWalletScreen({
    super.key,
    required this.repository,
    required this.accountantName,
    required this.onSignOut,
    this.onExitModule,
    this.initialAction,
  });

  final AccountantWalletRepository repository;
  final String accountantName;
  final VoidCallback onSignOut;

  /// Returns to the home dashboard; shows the back button when given.
  final VoidCallback? onExitModule;

  /// `wallet` opens the recharge directory straight away.
  final String? initialAction;

  @override
  State<AccountantWalletScreen> createState() => _AccountantWalletScreenState();
}

class _AccountantWalletScreenState extends State<AccountantWalletScreen> {
  WalletDirectoryPage? _directory;
  List<AccountantWalletTransaction>? _transactions;
  WalletTopUpSettings? _settings;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.initialAction == 'wallet') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openRecharge();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? error;
    Future<T?> guard<T>(Future<T> future) async {
      try {
        return await future;
      } catch (caught) {
        error ??= caught.toString();
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      guard(widget.repository.listWallets(limit: 1)),
      guard(widget.repository.listTransactions()),
      guard(widget.repository.getWalletTopUpSettings()),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
      _directory = results[0] as WalletDirectoryPage?;
      _transactions = results[1] as List<AccountantWalletTransaction>?;
      _settings = results[2] as WalletTopUpSettings?;
    });
  }

  Future<void> _openRecharge() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _WalletDirectoryPage(repository: widget.repository),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ready =
        _error == null &&
        _directory != null &&
        _transactions != null &&
        _settings != null;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: widget.onExitModule == null ? null : 0,
        leading: widget.onExitModule == null
            ? null
            : ModuleBackButton(onPressed: widget.onExitModule!),
        title: const Text(
          'Accounts',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
          children: [
            Text(
              'Hello, ${widget.accountantName}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recharge campus wallets, review payments and set top-up rules.',
              style: TextStyle(color: palette.inkSecondary),
            ),
            const SizedBox(height: 18),
            if (_error != null)
              _ErrorCard(
                key: const ValueKey('accounts-error'),
                title: 'Wallet desk unavailable',
                message: _error!,
                onRetry: _load,
              )
            else if (_loading && !ready)
              const SizedBox(
                height: 420,
                child: SkeletonList(rows: 4, rowHeight: 94),
              )
            else if (ready) ...[
              _OverviewCard(
                directory: _directory!,
                transactions: _transactions!,
              ),
              const SizedBox(height: 16),
              _AccountantModuleStack(
                peopleCount: _directory!.counts.all,
                transactionCount: _transactions!.length,
                settings: _settings!,
                onOpenWalletRecharge: _openRecharge,
                onOpenActivity: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        _WalletActivityPage(repository: widget.repository),
                  ),
                ),
                onOpenLimits: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => _WalletLimitSettingsPage(
                        repository: widget.repository,
                        settings: _settings!,
                      ),
                    ),
                  );
                  if (mounted) _load();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.directory, required this.transactions});

  final WalletDirectoryPage directory;
  final List<AccountantWalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = DateTime.now();
    final creditedToday = transactions
        .where((item) {
          final local = item.createdAt.toLocal();
          return item.isCredit &&
              local.year == today.year &&
              local.month == today.month &&
              local.day == today.day;
        })
        .fold<double>(0, (sum, item) => sum + item.amount);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.brandSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: palette.brandInk,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wallet overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Live across every store wallet',
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  key: const ValueKey('summary-wallet-float'),
                  label: 'Wallet float',
                  value: _money(directory.totalBalance),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryValue(
                  label: 'Credited today',
                  value: _money(creditedToday),
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryValue(
                  label: 'Campus users',
                  value: '${directory.counts.all}',
                  icon: Icons.groups_2_outlined,
                ),
              ),
            ],
          ),
          if (directory.stores.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final store in directory.stores)
                  _StorePill(
                    store: store,
                    label:
                        '${store.name} ${_money(directory.balancesByStore[store.shopKey] ?? 0)}',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountantModuleStack extends StatelessWidget {
  const _AccountantModuleStack({
    required this.peopleCount,
    required this.transactionCount,
    required this.settings,
    required this.onOpenWalletRecharge,
    required this.onOpenActivity,
    required this.onOpenLimits,
  });

  final int peopleCount;
  final int transactionCount;
  final WalletTopUpSettings settings;
  final VoidCallback onOpenWalletRecharge;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenLimits;

  @override
  Widget build(BuildContext context) {
    final modules = [
      _AccountantModuleSpec(
        key: const ValueKey('open-student-wallets'),
        title: 'Wallet Recharge',
        subtitle: 'Top up canteen, stationery or laundry',
        icon: Icons.account_balance_wallet_rounded,
        accent: AppColors.brandPurple,
        metric: '$peopleCount',
        metricLabel: 'campus users',
        actionLabel: 'Find a person',
        onTap: onOpenWalletRecharge,
      ),
      _AccountantModuleSpec(
        key: const ValueKey('open-wallet-activity'),
        title: 'Wallet Activity',
        subtitle: 'Every credit and payment, by store',
        icon: Icons.receipt_long_rounded,
        accent: AppColors.hotPinkInk,
        metric: '$transactionCount',
        metricLabel: 'recent entries',
        actionLabel: 'View ledger',
        onTap: onOpenActivity,
      ),
      _AccountantModuleSpec(
        key: const ValueKey('open-wallet-limits'),
        title: 'Top-up Rules',
        subtitle: 'Online payment limits for students',
        icon: Icons.tune_rounded,
        accent: AppColors.brandViolet,
        metric:
            '${_money(settings.minimumAmount)}–${_money(settings.maximumAmount)}',
        metricLabel: 'allowed range',
        actionLabel: 'Set limits',
        onTap: onOpenLimits,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < modules.length; index++) ...[
          _AccountantModuleCard(spec: modules[index]),
          if (index != modules.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AccountantModuleSpec {
  const _AccountantModuleSpec({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.metric,
    required this.metricLabel,
    required this.actionLabel,
    required this.onTap,
  });

  final Key key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String metric;
  final String metricLabel;
  final String actionLabel;
  final VoidCallback onTap;
}

class _AccountantModuleCard extends StatelessWidget {
  const _AccountantModuleCard({required this.spec});

  final _AccountantModuleSpec spec;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = context.isDarkTheme;
    final ink = dark ? Color.lerp(spec.accent, Colors.white, 0.55)! : spec.accent;
    final background = Color.alphaBlend(
      spec.accent.withValues(alpha: dark ? 0.16 : 0.06),
      palette.surface,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 94),
      child: Material(
        key: spec.key,
        color: Colors.transparent,
        child: InkWell(
          onTap: spec.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: spec.accent.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: spec.accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(spec.icon, color: Colors.white),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        spec.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${spec.actionLabel}  →',
                        style: TextStyle(
                          color: ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 72, maxWidth: 106),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: spec.accent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          spec.metric,
                          style: TextStyle(
                            color: ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        spec.metricLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
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

// ── Recharge directory ──────────────────────────────────────────────────────

const _directoryPageSize = 50;

class _WalletDirectoryPage extends StatefulWidget {
  const _WalletDirectoryPage({required this.repository});
  final AccountantWalletRepository repository;

  @override
  State<_WalletDirectoryPage> createState() => _WalletDirectoryPageState();
}

class _WalletDirectoryPageState extends State<_WalletDirectoryPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  WalletAudience _audience = WalletAudience.all;
  int? _year;
  List<WalletAccount> _accounts = const [];
  List<WalletStore> _stores = const [];
  WalletDirectoryCounts _counts = const WalletDirectoryCounts();
  int _total = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _loadMoreError;

  /// Discards responses to requests that a newer filter has superseded.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _loadMoreError = null;
    });
    try {
      final page = await widget.repository.listWallets(
        search: _search.text,
        audience: _audience,
        year: _year,
        limit: _directoryPageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _accounts = page.accounts;
        _stores = page.stores.isEmpty ? _stores : page.stores;
        _counts = page.counts;
        _total = page.total;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading || _loadingMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await widget.repository.listWallets(
        search: _search.text,
        audience: _audience,
        year: _year,
        offset: _accounts.length,
        limit: _directoryPageSize,
      );
      if (!mounted || generation != _generation) return;
      final known = {for (final account in _accounts) account.userId};
      setState(() {
        _accounts = [
          ..._accounts,
          ...page.accounts.where((account) => !known.contains(account.userId)),
        ];
        _total = page.total;
        _hasMore = page.hasMore && page.accounts.isNotEmpty;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadMoreError = error.toString();
        _loadingMore = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 480) {
      _loadMore();
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  void _setAudience(WalletAudience audience) {
    if (_audience == audience) return;
    setState(() {
      _audience = audience;
      if (audience == WalletAudience.staff) _year = null;
    });
    _reload();
  }

  void _setYear(int? year) {
    if (_year == year) return;
    setState(() => _year = year);
    _reload();
  }

  Future<void> _openRecharge(WalletAccount account) async {
    final credit = await showModalBottomSheet<AccountantWalletCredit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.palette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RechargeSheet(
        account: account,
        stores: _stores,
        repository: widget.repository,
      ),
    );
    if (credit == null || !mounted) return;
    setState(() {
      _accounts = [
        for (final item in _accounts)
          item.userId == account.userId
              ? item.withBalance(credit.shopKey, credit.balance)
              : item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final years = _counts.years.keys.toList()..sort();
    final showYears = _audience != WalletAudience.staff && years.isNotEmpty;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Wallet recharge',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const ValueKey('wallet-search'),
              controller: _search,
              onChanged: _searchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _debounce?.cancel();
                _reload();
              },
              decoration: InputDecoration(
                hintText: 'Search name, email, register no. or role',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: palette.surface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final audience in WalletAudience.values) ...[
                  _FilterChip(
                    key: ValueKey('audience-${audience.apiValue}'),
                    label:
                        '${_audienceLabel(audience)} ${_counts.forAudience(audience)}',
                    selected: _audience == audience,
                    onTap: () => _setAudience(audience),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          if (showYears)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                children: [
                  _FilterChip(
                    key: const ValueKey('year-filter-all'),
                    label: 'All years',
                    selected: _year == null,
                    dense: true,
                    onTap: () => _setYear(null),
                  ),
                  for (final year in years) ...[
                    const SizedBox(width: 6),
                    _FilterChip(
                      key: ValueKey('year-filter-$year'),
                      label: '${_ordinal(year)} year ${_counts.years[year]}',
                      selected: _year == year,
                      dense: true,
                      onTap: () => _setYear(year),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _loading && _accounts.isEmpty
                        ? 'Loading campus users…'
                        : 'Showing ${_accounts.length} of $_total',
                    key: const ValueKey('wallet-showing-count'),
                    style: TextStyle(
                      color: palette.inkSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'A–Z',
                  style: TextStyle(
                    color: palette.brandInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_loading && _accounts.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: _buildList(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ErrorCard(
            title: 'Could not load campus users',
            message: _error!,
            onRetry: _reload,
          ),
        ],
      );
    }
    if (_loading && _accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonList(rows: 6, rowHeight: 96),
      );
    }
    if (_accounts.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 64),
            child: Center(
              child: Text(
                _search.text.trim().isEmpty
                    ? 'No campus users here yet.'
                    : 'No one matches “${_search.text.trim()}”.',
                style: TextStyle(color: context.palette.inkSecondary),
              ),
            ),
          ),
        ],
      );
    }
    final footer = _hasMore || _loadMoreError != null;
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      itemCount: _accounts.length + (footer ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _accounts.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Column(
                      children: [
                        if (_loadMoreError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              _loadMoreError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.palette.danger),
                            ),
                          ),
                        TextButton(
                          key: const ValueKey('wallet-load-more'),
                          onPressed: _loadMore,
                          child: Text(
                            _loadMoreError != null ? 'Try again' : 'Load more',
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }
        final account = _accounts[index];
        return _WalletPersonCard(
          account: account,
          stores: _stores,
          onRecharge: () => _openRecharge(account),
        );
      },
    );
  }
}

String _audienceLabel(WalletAudience audience) => switch (audience) {
  WalletAudience.all => 'All',
  WalletAudience.students => 'Students',
  WalletAudience.staff => 'Staff',
};

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.brand : palette.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? palette.brand : palette.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 12 : 14,
              vertical: dense ? 5 : 7,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? palette.onBrand : palette.ink,
                fontSize: dense ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletPersonCard extends StatelessWidget {
  const _WalletPersonCard({
    required this.account,
    required this.stores,
    required this.onRecharge,
  });

  final WalletAccount account;
  final List<WalletStore> stores;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final details = account.isStudent
        ? [
            account.studentNumber,
            account.department,
            if (account.yearOfStudy != null)
              '${_ordinal(account.yearOfStudy!)} year',
          ]
        : [account.email];
    final roleLabels = account.isStudent
        ? const ['Student']
        : (account.roleLabels.isEmpty
              ? [account.roleLabel]
              : account.roleLabels.where((label) => label != 'Staff').isEmpty
              ? account.roleLabels
              : account.roleLabels.where((label) => label != 'Staff').toList());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onRecharge,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WalletAvatar(account: account),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final label in roleLabels.take(2))
                          _RoleChip(label: label, student: account.isStudent),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details.where((value) => value.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (stores.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final store in stores)
                            _StorePill(
                              store: store,
                              label: _money(account.balanceFor(store.shopKey)),
                              tooltip: '${store.name} wallet',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                key: ValueKey('credit-${account.userId}'),
                tooltip: 'Recharge ${account.name}',
                onPressed: onRecharge,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.student});

  final String label;
  final bool student;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: student ? palette.brandSoft : palette.infoSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: student ? palette.brandInk : palette.info,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

IconData _storeIcon(String category) => switch (category) {
  'stationery' => Icons.edit_note_rounded,
  'laundry' => Icons.local_laundry_service_rounded,
  _ => Icons.restaurant_rounded,
};

class _StorePill extends StatelessWidget {
  const _StorePill({required this.store, required this.label, this.tooltip});

  final WalletStore store;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_storeIcon(store.category), size: 12, color: palette.inkSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: palette.ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}

class _WalletAvatar extends StatelessWidget {
  const _WalletAvatar({required this.account});

  final WalletAccount account;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photoUrl = account.photoUrl?.trim();
    final fallback = Container(
      alignment: Alignment.center,
      color: palette.brandSoft,
      child: Text(
        _initials(account.name),
        style: TextStyle(color: palette.brandInk, fontWeight: FontWeight.w800),
      ),
    );
    return Container(
      key: ValueKey('wallet-avatar-${account.userId}'),
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(
          color: account.isStudent ? palette.brand : palette.info,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: photoUrl == null || photoUrl.isEmpty
            ? fallback
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

// ── Recharge sheet ──────────────────────────────────────────────────────────

class _RechargeSheet extends StatefulWidget {
  const _RechargeSheet({
    required this.account,
    required this.stores,
    required this.repository,
  });

  final WalletAccount account;
  final List<WalletStore> stores;
  final AccountantWalletRepository repository;

  @override
  State<_RechargeSheet> createState() => _RechargeSheetState();
}

class _RechargeSheetState extends State<_RechargeSheet> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  WalletStore? _store;
  String? _error;
  bool _submitting = false;
  AccountantWalletCredit? _credit;
  double? _creditedAmount;

  /// One key per attempt: a retry after a lost response cannot credit twice.
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_clearKey);
    _reference.addListener(_clearKey);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _clearKey() => _idempotencyKey = null;

  Future<void> _review() async {
    final store = _store;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (store == null) {
      setState(() => _error = 'Choose which wallet to recharge.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than ₹0.');
      return;
    }
    if (amount > 100000) {
      setState(() => _error = 'A single recharge can be at most ₹1,00,000.');
      return;
    }
    setState(() => _error = null);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm recharge'),
        content: Text(
          'Add ${_money(amount)} to ${widget.account.name}’s '
          '${store.name} wallet?',
          key: const ValueKey('wallet-recharge-confirm-text'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-wallet-recharge'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Add ${_money(amount)}'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submit(store, amount);
  }

  Future<void> _submit(WalletStore store, double amount) async {
    _idempotencyKey ??=
        'accountant-${widget.account.userId}-${store.shopKey}-'
        '${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final credit = await widget.repository.creditWallet(
        userId: widget.account.userId,
        shopKey: store.shopKey,
        amount: amount,
        idempotencyKey: _idempotencyKey!,
        reference: _reference.text,
      );
      if (!mounted) return;
      setState(() {
        _credit = AccountantWalletCredit(
          balance: credit.balance,
          shopKey: credit.shopKey.isEmpty ? store.shopKey : credit.shopKey,
          shopName: credit.shopName.isEmpty ? store.name : credit.shopName,
          replayed: credit.replayed,
        );
        _creditedAmount = amount;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 20),
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _credit == null ? _form(context) : _success(context),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final palette = context.palette;
    final account = widget.account;
    final details = account.isStudent
        ? [
            account.studentNumber,
            account.department,
            if (account.yearOfStudy != null)
              '${_ordinal(account.yearOfStudy!)} year',
          ]
        : [account.roleLabel, account.email];
    return Row(
      children: [
        _WalletAvatar(account: account),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                details.where((value) => value.isNotEmpty).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.inkSecondary, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final palette = context.palette;
    final selected = _store;
    return Column(
      key: const ValueKey('wallet-recharge-form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: palette.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _header(context),
        const SizedBox(height: 18),
        Text(
          'Which wallet?',
          style: TextStyle(
            color: palette.inkSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.stores.isEmpty)
          Text(
            'No canteen, stationery or laundry store is set up for this campus yet.',
            style: TextStyle(color: palette.danger),
          )
        else
          for (final store in widget.stores)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StoreOption(
                key: ValueKey('wallet-store-${store.shopKey}'),
                store: store,
                balance: widget.account.balanceFor(store.shopKey),
                selected: selected?.shopKey == store.shopKey,
                onTap: _submitting
                    ? null
                    : () => setState(() {
                        _store = store;
                        _error = null;
                        _idempotencyKey = null;
                      }),
              ),
            ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in const [100, 200, 500, 1000])
              ActionChip(
                key: ValueKey('wallet-quick-$value'),
                label: Text('₹$value'),
                onPressed: _submitting
                    ? null
                    : () {
                        _amount.text = '$value';
                        setState(() => _error = null);
                      },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('wallet-amount'),
          controller: _amount,
          enabled: !_submitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
            helperText: selected == null
                ? null
                : '${selected.name} balance now ${_money(widget.account.balanceFor(selected.shopKey))}',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _reference,
          enabled: !_submitting,
          decoration: const InputDecoration(
            labelText: 'Receipt or payment reference (optional)',
            prefixIcon: Icon(Icons.receipt_long_rounded),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('wallet-recharge-error'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.dangerSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: palette.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: palette.danger, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('wallet-review-recharge'),
          onPressed: _submitting || widget.stores.isEmpty ? null : _review,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_card_rounded),
          label: Text(_submitting ? 'Adding…' : 'Review recharge'),
        ),
      ],
    );
  }

  Widget _success(BuildContext context) {
    final palette = context.palette;
    final credit = _credit!;
    return Column(
      key: const ValueKey('wallet-recharge-success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.successSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: palette.success, size: 36),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${_money(_creditedAmount ?? 0)} added',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.account.name} · ${credit.shopName} wallet',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.inkSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text('New balance', style: TextStyle(color: palette.inkSecondary)),
              const Spacer(),
              Text(
                _money(credit.balance),
                key: const ValueKey('wallet-recharge-new-balance'),
                style: TextStyle(
                  color: palette.brandInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (credit.replayed) ...[
          const SizedBox(height: 8),
          Text(
            'This recharge had already been recorded; nothing was added twice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.inkSecondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey('wallet-recharge-done'),
          onPressed: () => Navigator.of(context).pop(credit),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _StoreOption extends StatelessWidget {
  const _StoreOption({
    super.key,
    required this.store,
    required this.balance,
    required this.selected,
    required this.onTap,
  });

  final WalletStore store;
  final double balance;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.brandSoft : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? palette.brand : palette.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _storeIcon(store.category),
                  color: selected ? palette.brandInk : palette.inkSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    store.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _money(balance),
                  style: TextStyle(
                    color: selected ? palette.brandInk : palette.inkSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? palette.brand : palette.inkTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ledger ──────────────────────────────────────────────────────────────────

class _WalletActivityPage extends StatefulWidget {
  const _WalletActivityPage({required this.repository});
  final AccountantWalletRepository repository;

  @override
  State<_WalletActivityPage> createState() => _WalletActivityPageState();
}

class _WalletActivityPageState extends State<_WalletActivityPage> {
  List<AccountantWalletTransaction>? _transactions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final value = await widget.repository.listTransactions(limit: 200);
      if (mounted) setState(() => _transactions = value);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.canvas,
    appBar: AppBar(
      centerTitle: false,
      titleSpacing: 0,
      title: const Text(
        'Wallet activity',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          if (_error != null)
            _ErrorCard(
              title: 'Could not load wallet activity',
              message: _error!,
              onRetry: _load,
            )
          else if (_transactions == null)
            const SizedBox(
              height: 552,
              child: SkeletonList(rows: 6, rowHeight: 82),
            )
          else if (_transactions!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Center(
                child: Text(
                  'No wallet activity yet.',
                  style: TextStyle(color: context.palette.inkSecondary),
                ),
              ),
            )
          else
            ..._transactions!.map(
              (transaction) => _TransactionCard(transaction: transaction),
            ),
        ],
      ),
    ),
  );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final AccountantWalletTransaction transaction;

  String _time(DateTime value) =>
      DateFormat('d MMM yyyy · h:mm a').format(value.toLocal());

  String get _kind => switch (transaction.transactionType) {
    'manual_top_up' => 'Recharge',
    'online_top_up' => 'Online top-up',
    'order_debit' => 'Payment',
    'refund' => 'Refund',
    _ => transaction.description,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final who = transaction.isStudent
        ? transaction.studentNumber
        : [
            transaction.roleLabel,
            transaction.email ?? '',
          ].where((value) => value.isNotEmpty).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: transaction.isCredit
                ? palette.successSoft
                : palette.surfaceSunken,
            foregroundColor: transaction.isCredit
                ? palette.success
                : palette.inkSecondary,
            child: Icon(
              transaction.isCredit
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (who.isNotEmpty)
                  Text(
                    who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.inkSecondary, fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Text(
                  [
                    _kind,
                    if (transaction.shopName.isNotEmpty)
                      '${transaction.shopName} wallet',
                    _time(transaction.createdAt),
                    if (transaction.referenceId?.isNotEmpty == true)
                      'Ref ${transaction.referenceId}',
                  ].join(' · '),
                  style: TextStyle(color: palette.inkTertiary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${transaction.isCredit ? '+' : '−'}${_money(transaction.amount.abs())}',
            style: TextStyle(
              color: transaction.isCredit ? palette.success : palette.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top-up rules ────────────────────────────────────────────────────────────

class _WalletLimitSettingsPage extends StatefulWidget {
  const _WalletLimitSettingsPage({
    required this.repository,
    required this.settings,
  });

  final AccountantWalletRepository repository;
  final WalletTopUpSettings settings;

  @override
  State<_WalletLimitSettingsPage> createState() =>
      _WalletLimitSettingsPageState();
}

class _WalletLimitSettingsPageState extends State<_WalletLimitSettingsPage> {
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _minimum = TextEditingController(
      text: widget.settings.minimumAmount.toStringAsFixed(0),
    );
    _maximum = TextEditingController(
      text: widget.settings.maximumAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minimum = double.tryParse(_minimum.text.trim());
    final maximum = double.tryParse(_maximum.text.trim());
    if (minimum == null ||
        maximum == null ||
        minimum < 1 ||
        maximum < minimum ||
        maximum > 100000) {
      setState(
        () => _error =
            'Minimum must be at least ₹1. Maximum must be higher and no more than ₹1,00,000.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateWalletTopUpSettings(
        minimumAmount: minimum,
        maximumAmount: maximum,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student top-up limits updated.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Top-up rules',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.brandSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: palette.brandInk, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Online wallet policy',
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Students can add money online only within this range. '
                        'The payment API enforces it too. Recharges made here '
                        'at the accounts desk are not limited by it.',
                        style: TextStyle(color: palette.inkSecondary, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('wallet-minimum-limit'),
                  controller: _minimum,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Minimum top-up',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('wallet-maximum-limit'),
                  controller: _maximum,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Maximum top-up',
                    prefixText: '₹ ',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: palette.danger)),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const ValueKey('save-wallet-limits'),
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save limits'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared pieces ───────────────────────────────────────────────────────────

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: palette.brandInk),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.inkSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.dangerSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.danger, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.ink,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.inkSecondary),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const ValueKey('accounts-retry'),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

String _ordinal(int n) {
  final suffix = switch (n) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
  return '$n$suffix';
}

String _money(double value) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: value == value.roundToDouble() ? 0 : 2,
).format(value);
