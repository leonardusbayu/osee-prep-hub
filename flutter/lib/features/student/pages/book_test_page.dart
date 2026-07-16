import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Book official test page — Modernized UI.
class BookTestPage extends ConsumerStatefulWidget {
  const BookTestPage({super.key});

  @override
  ConsumerState<BookTestPage> createState() => _BookTestPageState();
}

class _BookTestPageState extends ConsumerState<BookTestPage> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/student/book-test');
      setState(() {
        _data = r.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _openBooking() async {
    final urlStr = _data?['osee_booking_url'] as String? ?? 'https://osee.co.id';
    final url = Uri.parse(urlStr);
    try {
      if (!await launchUrl(url)) {
        throw Exception('Could not launch');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: StudentTheme.primary,
            content: Text('Open $url in your browser', style: StudentTheme.cardLabel(Colors.white)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: StudentTheme.primary))
        : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: StudentTheme.cardLabel(StudentTheme.textSecondary)),
                    const SizedBox(height: StudentSpacing.lg),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _buildContent(isDesktop);
  }

  Widget _buildContent(bool isDesktop) {
    final ready = _data?['ready_to_book'] as bool? ?? false;
    
    final color = ready ? StudentTheme.successGreen : StudentTheme.warningOrange;
    final bg = ready ? StudentTheme.successGreen.withValues(alpha: 0.1) : StudentTheme.warningOrange.withValues(alpha: 0.1);
    final icon = ready ? Icons.verified_rounded : Icons.hourglass_top_rounded;

    return ListView(
      padding: const EdgeInsets.all(StudentSpacing.xl),
      children: [
        StudentTopBar(
          name: 'Student',
          subtitle: 'Book Test',
          onMenuTap: isDesktop ? null : () => Scaffold.of(context).openDrawer(),
        ),
        const SizedBox(height: StudentSpacing.xxl),
        
        Container(
          padding: const EdgeInsets.all(StudentSpacing.xxl),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: StudentSpacing.xl),
              Text(
                ready ? 'You are ready to book!' : 'Not yet ready',
                style: StudentTheme.pageTitle(color),
              ),
              const SizedBox(height: 8),
              Text(
                _data?['note'] as String? ?? '',
                style: StudentTheme.cardLabel(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: StudentSpacing.xxl),
        
        if (ready) ...[
          const StudentSectionHeader(
            title: 'Official ETS Test Center',
            icon: Icons.business_rounded,
          ),
          const SizedBox(height: StudentSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: StudentTheme.surface,
              borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
              boxShadow: StudentTheme.cardShadow,
              border: Border.all(color: StudentTheme.divider),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(StudentSpacing.xl),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StudentTheme.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available_rounded, color: StudentTheme.primary, size: 28),
              ),
              title: Text('Book Official Test', style: StudentTheme.courseTitle().copyWith(fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('OSEE is an official ETS test center since 2014.', style: StudentTheme.noticeBody()),
              ),
              trailing: const Icon(Icons.open_in_new_rounded, color: StudentTheme.primary),
              onTap: _openBooking,
            ),
          ),
          const SizedBox(height: StudentSpacing.xxl),
          
          if ((_data?['available_dates'] as List?)?.isNotEmpty ?? false) ...[
            const StudentSectionHeader(
              title: 'Available Dates',
              icon: Icons.event_note_rounded,
            ),
            const SizedBox(height: StudentSpacing.lg),
            for (final d in (_data?['available_dates'] as List?) ?? <dynamic>[]) ...[
              Container(
                margin: const EdgeInsets.only(bottom: StudentSpacing.md),
                decoration: BoxDecoration(
                  color: StudentTheme.surface,
                  borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
                  boxShadow: StudentTheme.cardShadow,
                  border: Border.all(color: StudentTheme.divider),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: StudentSpacing.xl, vertical: 8),
                  title: Text(d.toString(), style: StudentTheme.courseTitle().copyWith(fontSize: 15, fontWeight: FontWeight.normal)),
                  trailing: ElevatedButton(
                    onPressed: _openBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StudentTheme.radiusButton)),
                    ),
                    child: const Text('Book'),
                  ),
                ),
              ),
            ],
          ]
        ],
      ],
    );
  }
}
