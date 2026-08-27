import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The scan screen.
///
/// The camera lives inside one rounded card in the lower part of the screen and
/// nowhere else. That is the whole point of the layout: the preview is clipped
/// to the card, so a feed of any aspect fills it without ever bleeding over the
/// title or the edges of the screen.
///
/// Pops with the code that was read, or null if the screen was dismissed.
///
/// Measurements are fractions of the screen, taken off the design board, which
/// draws the phone at 428 x 787.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key, this.title = 'Scan QR'});

  final String title;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

const _purple = Color(0xFF6C00FF);

// Off the board: the card, and the title above it.
const _cardLeft = 14 / 428;
const _cardWidth = 402 / 428;
const _cardTop = 430 / 787;
const _cardHeight = 295 / 787;
const _cardRadius = 30 / 428;

const _scriptCentreY = 171.5 / 787;
const _scriptSize = 26 / 428;
// The board stacks the two lines tight — the mark's box ends where the title's
// begins — so the title needs no offset of its own.
const _titleSize = 48 / 428;

// Controls inside the card.
const _controlCentreY = 48 / 295;
const _galleryCentreX = 44.5 / 402;
const _closeCentreX = 361 / 402;
const _controlSize = 29 / 402;

class _ScanQrScreenState extends State<ScanQrScreen>
    with TickerProviderStateMixin {
  /// The card arrives from the bottom of the screen and leaves the same way.
  /// Something that disappears one way is expected to come back from there.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 320),
  );

  /// The line that travels down the preview. It is the only thing on the screen
  /// that says the camera is live rather than frozen.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  /// QR only, and one result at a time. `noDuplicates` stops the same code
  /// firing on every frame while it is still in shot.
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _quiet = false;
  bool _leaving = false;

  /// The first code wins. Reading is stopped before the screen animates out, so
  /// a code drifting through the frame on the way cannot arrive second.
  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _finish(value);
        return;
      }
    }
  }

  /// Reads a code out of a photo instead of the camera — the same result by a
  /// different route, so it leaves the screen the same way.
  Future<void> _fromGallery() async {
    if (_leaving) return;
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(type: FileType.image);
    } on Exception {
      if (mounted) _say('The photo library is not available on this device.');
      return;
    }
    final path = file?.path;
    if (path == null || path.isEmpty) {
      if (mounted && file != null) _say('That photo could not be opened.');
      return;
    }
    try {
      final capture = await _camera.analyzeImage(path);
      final value = capture?.barcodes
          .map((barcode) => barcode.rawValue)
          .firstWhere(
            (raw) => raw != null && raw.isNotEmpty,
            orElse: () => null,
          );
      if (value == null) {
        if (mounted) _say('No QR code found in that photo.');
        return;
      }
      _finish(value);
    } on UnsupportedError {
      if (mounted) _say('Reading a code from a photo is not supported here.');
    } on Exception {
      if (mounted) _say('That photo could not be read.');
    }
  }

  void _say(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quiet = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (quiet == _quiet && _enter.isAnimating) return;
    _quiet = quiet;
    if (quiet) {
      // Reduced motion still gets the screen, just not the travel: the card is
      // simply there, and the sweep — a loop with no informational content —
      // does not run at all.
      _enter.value = 1;
      _sweep.stop();
      _sweep.value = 0;
    } else {
      if (_enter.status == AnimationStatus.dismissed) _enter.forward();
      if (!_sweep.isAnimating) _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _sweep.dispose();
    // Releasing the camera is not optional: a controller left running holds the
    // device open and the next screen to want it gets nothing.
    _camera.dispose();
    super.dispose();
  }

  /// Leaves along the path it arrived on, then pops. Guarded so a double tap on
  /// the close button cannot pop twice.
  Future<void> _close() => _finish(null);

  Future<void> _finish(String? code) async {
    if (_leaving) return;
    _leaving = true;
    // Stop reading first — the camera has no reason to keep working through the
    // exit, and a second code arriving mid-animation would be discarded anyway.
    unawaited(_camera.stop());
    if (!_quiet) await _enter.reverse();
    if (!mounted) return;
    // `pop`, never `maybePop`. The [PopScope] below declares `canPop: false` so
    // that a system back runs this exit first, and `maybePop` consults that very
    // guard — it would decline, hand back to `onPopInvokedWithResult`, hit the
    // `_leaving` return above, and leave the route on the stack with its card
    // already gone: a black screen with no way out of it.
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final cardWidth = _cardWidth * w;
            final cardHeight = _cardHeight * h;

            return Stack(
              children: [
                _title(w, h),
                AnimatedBuilder(
                  animation: _enter,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_enter.value);
                    return Positioned(
                      left: _cardLeft * w,
                      // It rises the last of its own height into place, so the
                      // move reads as the card coming from off the bottom of
                      // the screen rather than fading in where it lands.
                      top: _cardTop * h + (1 - t) * cardHeight * 0.55,
                      width: cardWidth,
                      height: cardHeight,
                      child: Opacity(opacity: t, child: child),
                    );
                  },
                  child: _card(cardWidth, cardHeight),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _title(double w, double h) {
    return Positioned(
      left: 0,
      right: 0,
      // The board centres the wordmark on this line; the block is laid out from
      // its top, so back off by half the mark's own height.
      top: _scriptCentreY * h - _scriptSize * w / 2,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
        child: Column(
          children: [
            // The board sets the wordmark in a signature script. Poppins is
            // what ships with the app, so it is italicised and spaced to read
            // as a mark rather than as a second heading.
            Text(
              'SuperCampus',
              style: TextStyle(
                color: _purple,
                fontSize: _scriptSize * w,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
            Text(
              widget.title,
              style: TextStyle(
                color: _purple,
                fontSize: _titleSize * w,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(double cardWidth, double cardHeight) {
    final radius = BorderRadius.circular(_cardRadius * cardWidth / _cardWidth);
    final control = _controlSize * cardWidth;

    // No glow around it: the board gives the card a clean edge against the
    // black, and a halo on a dark ground only smears it.
    return ClipRRect(
      // Everything the camera draws is confined here. A preview of any aspect
      // is cropped to the card instead of covering the screen.
      borderRadius: radius,
      child: ColoredBox(
        color: const Color(0xFF0B0B10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The preview fills the card and is cropped by the clip above it,
            // so a sensor of any shape stays inside the frame.
            MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              fit: BoxFit.cover,
              placeholderBuilder: (context) =>
                  const _CardMessage(message: 'Starting the camera…'),
              errorBuilder: (context, error) => _CardMessage(
                message: switch (error.errorCode) {
                  MobileScannerErrorCode.permissionDenied =>
                    'Camera access is off. Turn it on in Settings to scan.',
                  MobileScannerErrorCode.unsupported =>
                    'This device cannot scan a code.',
                  _ => 'The camera could not be started.',
                },
              ),
            ),
            _Sweep(progress: _sweep, quiet: _quiet),
            _control(
              centreX: _galleryCentreX,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              size: control,
              icon: Icons.image_rounded,
              tooltip: 'Scan a photo',
              keyValue: 'scan-gallery',
              onTap: _fromGallery,
            ),
            _control(
              centreX: _closeCentreX,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              size: control,
              icon: Icons.close_rounded,
              tooltip: 'Close',
              keyValue: 'scan-close',
              onTap: _close,
            ),
          ],
        ),
      ),
    );
  }

  Widget _control({
    required double centreX,
    required double cardWidth,
    required double cardHeight,
    required double size,
    required IconData icon,
    required String tooltip,
    required String keyValue,
    required Future<void> Function() onTap,
  }) {
    // The glyph is the board's size; the tap target around it is not, so it
    // still clears a fingertip on a small phone.
    final target = size * 1.8;

    return Positioned(
      left: centreX * cardWidth - target / 2,
      top: _controlCentreY * cardHeight - target / 2,
      width: target,
      height: target,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: InkResponse(
            key: ValueKey(keyValue),
            onTap: () => onTap(),
            radius: target / 2,
            child: Center(
              child: Icon(icon, size: size, color: const Color(0xFF1B1B1F)),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the card shows when there is no picture in it: the frame a code would
/// be read in, and one line saying why nothing is moving.
class _CardMessage extends StatelessWidget {
  const _CardMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B0B10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide * 0.44;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: side,
                  child: CustomPaint(painter: _FramePainter()),
                ),
                SizedBox(height: side * 0.16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: side * 0.2),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: side * 0.09,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = size.width * 0.03
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arm = size.width * 0.26;
    canvas.drawPath(
      Path()
        ..moveTo(0, arm)
        ..lineTo(0, 0)
        ..lineTo(arm, 0)
        ..moveTo(size.width - arm, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, arm)
        ..moveTo(size.width, size.height - arm)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - arm, size.height)
        ..moveTo(arm, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, size.height - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => false;
}

/// A band of light that travels down the card and back.
///
/// It is a gradient rather than a hairline so it reads as light falling across
/// the frame, and it eases at each end instead of snapping back to the top —
/// a hard reset is what makes a scan line look like a loading bar.
class _Sweep extends StatelessWidget {
  const _Sweep({required this.progress, required this.quiet});

  final Animation<double> progress;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    if (quiet) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          // One controller cycle is a round trip, so the band never jumps.
          final t = Curves.easeInOut.transform(
            progress.value <= 0.5
                ? progress.value * 2
                : (1 - progress.value) * 2,
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final band = h * 0.18;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: t * (h - band),
                    height: band,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _purple.withValues(alpha: 0),
                            _purple.withValues(alpha: 0.22),
                            _purple.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Opens the scan screen. The black ground fades up while the card rides in, so
/// the screen arrives as one movement rather than as a page swap.
/// Resolves with the code that was read, or null if the screen was dismissed.
Future<String?> openScanQr(BuildContext context, {String title = 'Scan QR'}) {
  return Navigator.of(context).push<String>(
    PageRouteBuilder<String>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => ScanQrScreen(title: title),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}
