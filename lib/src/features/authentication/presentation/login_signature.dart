import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The SuperCampus signature on the sign-in page, written out by the brand
/// animation and replayed in a loop.
///
/// The video is the signature on a pure white ground, so it sits on the light
/// sign-in page with no visible edge. Until the first frame is ready — or
/// where video cannot play (some browsers, tests) — the finished signature is
/// shown as a still, so the page never jumps. On the dark theme the white
/// ground would show as a box, so the Brittany wordmark is used instead.
class LoginSignature extends StatefulWidget {
  const LoginSignature({
    super.key,
    required this.darkFallback,
    this.width = 240,
    this.playVideo = true,
  });

  /// What the dark theme shows instead of the white-ground animation.
  final Widget darkFallback;

  /// Rendered width; the height follows the artwork's 720 x 272 ratio.
  final double width;

  /// Off in tests and wherever only the still should show.
  final bool playVideo;

  static const videoAsset = 'assets/branding/supercampus_signature.mp4';
  static const posterAsset = 'assets/branding/supercampus_signature_poster.png';
  static const aspectRatio = 720 / 272;

  @override
  State<LoginSignature> createState() => _LoginSignatureState();
}

class _LoginSignatureState extends State<LoginSignature> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.playVideo) _start();
  }

  Future<void> _start() async {
    final controller = VideoPlayerController.asset(
      LoginSignature.videoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      // Muted, which browsers require before they will autoplay a video.
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      // No video here; the still stays.
      debugPrint('LoginSignature: video unavailable ($error)');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return widget.darkFallback;
    }
    final controller = _controller;
    return Semantics(
      label: 'SuperCampus',
      image: true,
      child: Center(
        child: SizedBox(
          width: widget.width,
          child: AspectRatio(
            aspectRatio: LoginSignature.aspectRatio,
            // The video is on the page from the start (browsers may not load
            // a video that isn't), under the still, which steps aside once
            // the video is playing.
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (controller != null) VideoPlayer(controller),
                if (!_ready)
                  ColoredBox(
                    color: Colors.white,
                    child: Image.asset(
                      LoginSignature.posterAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => widget.darkFallback,
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
