import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:osee_prep_hub/core/api_client.dart';
import 'package:osee_prep_hub/design/tokens.dart';
import 'package:osee_prep_hub/design/components.dart';

/// Live class landing page — T12 (Wave 2) skeleton.
///
/// Shows upcoming live classes + join button. Real impl uses
/// livekit_client package + the JWT returned from /api/live-classes/:id/join.
class LiveClassPage extends ConsumerStatefulWidget {
  const LiveClassPage({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<LiveClassPage> createState() => _LiveClassPageState();
}

class _LiveClassPageState extends ConsumerState<LiveClassPage> {
  String? _livekitToken;
  String? _livekitUrl;
  String? _roomName;
  bool _joining = false;
  String? _joinError;

  Future<void> _joinLiveClass() async {
    setState(() {
      _joining = true;
      _joinError = null;
    });
    try {
      final dio = ApiClient.create();
      final resp = await dio.post('/live-classes/${widget.classId}/join');
      setState(() {
        _livekitToken = resp.data['token'] as String?;
        _livekitUrl = resp.data['url'] as String?;
        _roomName = resp.data['roomName'] as String?;
      });
      // Real impl would now connect to LiveKit using livekit_client:
      // final room = LiveKitRoom();
      // await room.connect(_livekitUrl!, _livekitToken!);
      // For now, we just show the token + URL so the user can verify.
    } on DioException catch (e) {
      setState(() => _joinError = e.response?.data['error']?['message'] ?? e.message);
    } catch (e) {
      setState(() => _joinError = e.toString());
} finally {
        if (mounted) setState(() => _joining = false);
      }
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Class', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        backgroundColor: MagazineColors.paperCream,
        elevation: 0,
      ),
      backgroundColor: MagazineColors.paperCream,
      body: _joining
          ? const Center(child: CircularProgressIndicator(color: MagazineColors.mastheadGold))
          : SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(MagazineSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(MagazineSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: MagazineColors.mastheadGold, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MagazineColors.mastheadGold.withValues(alpha: 0.15),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.videocam, size: 40, color: MagazineColors.mastheadGold),
                  ),
                  const SizedBox(height: MagazineSpacing.lg),
                  Text('IELTS Writing Live Q&A', textAlign: TextAlign.center, style: magazineDisplay()),
                  const SizedBox(height: MagazineSpacing.sm),
                  Text('Scheduled · 60 min · 24 attendees', style: magazineCaption()),
                  const SizedBox(height: MagazineSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(MagazineSpacing.base),
                    decoration: BoxDecoration(color: MagazineColors.surfaceMuted),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CLASSROOM LIVE', style: magazineOverline()),
                        const SizedBox(height: MagazineSpacing.xs),
                        const Text(
                          'WebRTC video via LiveKit + Yjs-synced whiteboard + real-time polls + AI summary post-class.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MagazineSpacing.lg),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: MagazineColors.mastheadGold, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                    onPressed: _joinLiveClass,
                    child: const Text('JOIN LIVE', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  ),
                  if (_joinError != null) ...[
                    const SizedBox(height: MagazineSpacing.md),
                    Text(_joinError!, style: TextStyle(color: MagazineColors.errorRed, fontSize: 12)),
                  ],
                  if (_livekitToken != null) ...[
                    const SizedBox(height: MagazineSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(MagazineSpacing.base),
                      decoration: BoxDecoration(color: MagazineColors.surfaceMuted),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LIVEKIT TOKEN (T12 stub — not yet connected)', style: magazineOverline()),
                          const SizedBox(height: MagazineSpacing.xs),
                          SelectableText('Room: $_roomName\nURL: $_livekitUrl\nToken: ${_livekitToken!.substring(0, _livekitToken!.length.clamp(0, 40))}...', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
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
}