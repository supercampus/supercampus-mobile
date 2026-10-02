import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The SuperCampus signature on the sign-in page, handwritten in Brittany.
///
/// It writes "SuperCampus", holds, un-writes at twice the speed, then writes
/// the next word — campus verbs, in the spirit of a spinner — and loops.
///
/// The writing is a reveal behind a slanted, soft-edged pen front that leans
/// with the script. The front is paced per letter (narrow, curly letters take
/// a touch longer per pixel than wide strokes), so it reads as a hand rather
/// than a wipe. With reduced motion on, the signature is simply shown.
class LoginSignature extends StatefulWidget {
  const LoginSignature({
    super.key,
    this.width = 280,
    this.height = 90,
    this.fontSize = 40,
    this.words = defaultWords,
    this.animate,
  });

  final double width;
  final double height;
  final double fontSize;
  final List<String> words;

  /// Null animates everywhere except under `flutter test`, where an endless
  /// animation would keep `pumpAndSettle` from settling.
  final bool? animate;

  static const defaultWords = <String>[
    'SuperCampus',
    'Learning',
    'Exploring',
    'Connecting',
    'Creating',
    'Discovering',
    'Brainstorming',
    'Daydreaming',
    'Achieving',
    'Belonging',
    'Thriving',
  ];

  /// How long a word takes to write; un-writing takes half of it.
  static Duration writeDuration(String word) =>
      Duration(milliseconds: 520 + 105 * word.length);

  static const hold = Duration(milliseconds: 1500);
  static const gap = Duration(milliseconds: 320);

  @override
  State<LoginSignature> createState() => _LoginSignatureState();
}

bool get _underFlutterTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

class _LoginSignatureState extends State<LoginSignature>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pen = AnimationController(vsync: this);
  int _index = 0;
  bool _running = false;

  bool get _animates => widget.animate ?? !_underFlutterTest;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context) || !_animates;
    if (still) {
      _pen.value = 1;
    } else if (!_running) {
      _running = true;
      _loop();
    }
  }

  Future<void> _loop() async {
    try {
      while (mounted) {
        final word = widget.words[_index % widget.words.length];
        final write = LoginSignature.writeDuration(word);
        _pen
          ..duration = write
          ..reverseDuration = write ~/ 2;
        await _pen.forward(from: 0).orCancel;
        await Future<void>.delayed(LoginSignature.hold);
        if (!mounted || !_stillAnimating) break;
        await _pen.reverse().orCancel;
        await Future<void>.delayed(LoginSignature.gap);
        if (!mounted || !_stillAnimating) break;
        setState(() => _index++);
      }
    } on TickerCanceled {
      // Disposed mid-stroke.
    }
    _running = false;
  }

  bool get _stillAnimating => !MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _pen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final word = widget.words[_index % widget.words.length];
    return Semantics(
      label: 'SuperCampus',
      image: true,
      child: Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _InkPainter(
                word: word,
                fontSize: widget.fontSize,
                ink: dark
                    ? const [Color(0xFFB9A3FF), Color(0xFFE4D9FF)]
                    : const [Color(0xFF2B1572), Color(0xFF6236D0)],
                progress: CurvedAnimation(
                  parent: _pen,
                  // A steady hand: eases in and out without rushing the middle.
                  curve: Curves.easeInOutSine,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter({
    required this.word,
    required this.fontSize,
    required this.ink,
    required this.progress,
  }) : super(repaint: progress);

  final String word;
  final double fontSize;
  final List<Color> ink;
  final Animation<double> progress;

  /// The pen front's lean, matching the script's slant (about 16°).
  static const _slant = 0.28;

  /// How soft the pen front is, in logical pixels.
  static const _feather = 22.0;

  TextPainter? _text;
  List<double>? _stops;

  TextPainter _layout() {
    final cached = _text;
    if (cached != null) return cached;
    final text = TextPainter(
      text: TextSpan(
        text: word,
        style: TextStyle(
          fontFamily: 'Brittany',
          fontSize: fontSize,
          height: 1.1,
          color: ink.first,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Each letter's left edge, then the end of the word.
    final edges = <double>[];
    for (var i = 0; i < word.length; i++) {
      final boxes = text.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      edges.add(boxes.isEmpty ? (edges.isEmpty ? 0 : edges.last) : boxes.first.left);
    }
    edges.add(text.width);
    _stops = edges;
    return _text = text;
  }

  /// Where the pen front is, in text x, for time [t] in 0..1.
  ///
  /// Every letter gets time for its width plus a constant, so narrow, curly
  /// letters are written a little slower than long strokes.
  double _penX(double t, double lead, double tail) {
    final edges = _stops!;
    final xs = <double>[edges.first - lead, ...edges, edges.last + tail];
    const perLetter = 9.0;
    final weights = <double>[
      for (var i = 0; i < xs.length - 1; i++)
        (xs[i + 1] - xs[i]).abs() +
            (i == 0 || i == xs.length - 2 ? 0 : perLetter),
    ];
    final total = weights.fold<double>(0, (a, b) => a + b);
    var at = t.clamp(0.0, 1.0) * total;
    for (var i = 0; i < weights.length; i++) {
      if (at <= weights[i] || i == weights.length - 1) {
        final f = weights[i] == 0 ? 1.0 : (at / weights[i]).clamp(0.0, 1.0);
        return xs[i] + (xs[i + 1] - xs[i]) * f;
      }
      at -= weights[i];
    }
    return xs.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final text = _layout();
    final t = progress.value;
    if (t <= 0) return;

    final scale = math.min(1.0, (size.width - 8) / text.width);
    final w = text.width * scale;
    final h = text.height * scale;
    canvas
      ..save()
      ..translate((size.width - w) / 2, (size.height - h) / 2)
      ..scale(scale);

    // Generous bounds: Brittany's flourishes reach past the line box.
    final bounds = Rect.fromLTWH(
      -fontSize,
      -fontSize * 0.6,
      text.width + fontSize * 2,
      text.height + fontSize * 1.2,
    );
    final cy = text.height / 2;
    // How far the slanted front reaches past the letters at their top and
    // bottom, so a word starts and ends cleanly without dead time.
    final lean = text.height * 0.55 * math.tan(_slant);

    canvas.saveLayer(bounds, Paint());
    final inkPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(text.width, text.height),
        ink,
      );
    canvas.saveLayer(bounds, Paint());
    text.paint(canvas, Offset.zero);
    canvas
      ..drawRect(bounds, inkPaint..blendMode = BlendMode.srcIn)
      ..restore();

    if (t < 1) {
      // Everything behind the pen front is ink; ahead of it, paper.
      final x = _penX(t, lean + _feather, lean + _feather);
      final d = Offset(math.cos(_slant), math.sin(_slant));
      final front = Offset(x, cy);
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            front - d * (_feather / 2),
            front + d * (_feather / 2),
            const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          ),
      );
    }
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_InkPainter old) =>
      old.word != word ||
      old.fontSize != fontSize ||
      old.ink != ink ||
      old.progress != progress;
}
