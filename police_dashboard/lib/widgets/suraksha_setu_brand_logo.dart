import 'package:flutter/material.dart';

class SurakshaSetuBrandLogo extends StatelessWidget {
  const SurakshaSetuBrandLogo({
    super.key,
    this.width = 220,
    this.compact = false,
    this.showShadow = true,
  });

  final double width;
  final bool compact;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: compact ? 0.96 : 1.18,
        child: CustomPaint(
          painter: _SurakshaSetuBrandLogoPainter(
            compact: compact,
            showShadow: showShadow,
          ),
        ),
      ),
    );
  }
}

class _SurakshaSetuBrandLogoPainter extends CustomPainter {
  const _SurakshaSetuBrandLogoPainter({
    required this.compact,
    required this.showShadow,
  });

  final bool compact;
  final bool showShadow;

  static const Color _greenDark = Color(0xFF1B5E20);
  static const Color _green = Color(0xFF43A047);
  static const Color _greenLight = Color(0xFF7BC043);
  static const Color _red = Color(0xFFC62828);
  static const Color _redDark = Color(0xFF8E1414);
  static const Color _orangeLight = Color(0xFFFFB300);
  static const Color _cream = Color(0xFFFDF8EF);
  static const Color _shadow = Color(0x1A000000);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final emblemRect = compact
        ? Rect.fromLTWH(
            width * 0.11, height * 0.05, width * 0.78, height * 0.84)
        : Rect.fromLTWH(
            width * 0.16, height * 0.03, width * 0.68, height * 0.63);

    _paintTopArc(canvas, size);
    _paintHands(canvas, size, emblemRect);
    _paintSkyline(canvas, emblemRect);
    _paintShield(canvas, size, emblemRect);

    if (!compact) {
      _paintWordmark(canvas, size);
      _paintTagline(canvas, size);
    }
  }

  void _paintTopArc(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.09)
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * -0.03,
        size.width * 0.86,
        size.height * 0.19,
      );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.032
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: <Color>[_greenLight, _green],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintHands(Canvas canvas, Size size, Rect emblemRect) {
    final leftHand = Path()
      ..moveTo(size.width * 0.14, emblemRect.bottom - size.height * 0.05)
      ..quadraticBezierTo(
        size.width * 0.03,
        emblemRect.center.dy + size.height * 0.08,
        size.width * 0.12,
        emblemRect.top + size.height * 0.2,
      )
      ..quadraticBezierTo(
        size.width * 0.2,
        emblemRect.top + size.height * 0.02,
        emblemRect.left + size.width * 0.1,
        emblemRect.top + size.height * 0.16,
      )
      ..quadraticBezierTo(
        emblemRect.left - size.width * 0.04,
        emblemRect.center.dy + size.height * 0.14,
        size.width * 0.14,
        emblemRect.bottom - size.height * 0.05,
      )
      ..close();

    final rightHand = Path()
      ..moveTo(size.width * 0.86, emblemRect.bottom - size.height * 0.05)
      ..quadraticBezierTo(
        size.width * 0.97,
        emblemRect.center.dy + size.height * 0.08,
        size.width * 0.88,
        emblemRect.top + size.height * 0.2,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        emblemRect.top + size.height * 0.02,
        emblemRect.right - size.width * 0.1,
        emblemRect.top + size.height * 0.16,
      )
      ..quadraticBezierTo(
        emblemRect.right + size.width * 0.04,
        emblemRect.center.dy + size.height * 0.14,
        size.width * 0.86,
        emblemRect.bottom - size.height * 0.05,
      )
      ..close();

    if (showShadow) {
      canvas.drawShadow(leftHand, _shadow, 8, true);
      canvas.drawShadow(rightHand, _shadow, 8, true);
    }

    canvas.drawPath(
      leftHand,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[_greenLight, _greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(leftHand.getBounds()),
    );
    canvas.drawPath(
      rightHand,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[_red, _redDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rightHand.getBounds()),
    );

    final handAccentPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.014
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.12, emblemRect.bottom - size.height * 0.08)
        ..quadraticBezierTo(
          size.width * 0.04,
          emblemRect.center.dy + size.height * 0.1,
          size.width * 0.12,
          emblemRect.top + size.height * 0.28,
        ),
      handAccentPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.88, emblemRect.bottom - size.height * 0.08)
        ..quadraticBezierTo(
          size.width * 0.96,
          emblemRect.center.dy + size.height * 0.1,
          size.width * 0.88,
          emblemRect.top + size.height * 0.28,
        ),
      handAccentPaint,
    );
  }

  void _paintSkyline(Canvas canvas, Rect emblemRect) {
    final skylineRect = Rect.fromLTWH(
      emblemRect.left + emblemRect.width * 0.08,
      emblemRect.top + emblemRect.height * 0.02,
      emblemRect.width * 0.84,
      emblemRect.height * 0.14,
    );

    final path = Path()
      ..moveTo(skylineRect.left, skylineRect.bottom)
      ..lineTo(skylineRect.left, skylineRect.top + skylineRect.height * 0.6)
      ..lineTo(skylineRect.left + skylineRect.width * 0.08,
          skylineRect.top + skylineRect.height * 0.5)
      ..lineTo(skylineRect.left + skylineRect.width * 0.08,
          skylineRect.top + skylineRect.height * 0.22)
      ..lineTo(skylineRect.left + skylineRect.width * 0.14,
          skylineRect.top + skylineRect.height * 0.22)
      ..lineTo(skylineRect.left + skylineRect.width * 0.14,
          skylineRect.top + skylineRect.height * 0.42)
      ..lineTo(skylineRect.left + skylineRect.width * 0.2,
          skylineRect.top + skylineRect.height * 0.42)
      ..lineTo(skylineRect.left + skylineRect.width * 0.2, skylineRect.top)
      ..lineTo(skylineRect.left + skylineRect.width * 0.29, skylineRect.top)
      ..lineTo(skylineRect.left + skylineRect.width * 0.29,
          skylineRect.top + skylineRect.height * 0.35)
      ..lineTo(skylineRect.left + skylineRect.width * 0.37,
          skylineRect.top + skylineRect.height * 0.35)
      ..lineTo(skylineRect.left + skylineRect.width * 0.37,
          skylineRect.top + skylineRect.height * 0.08)
      ..lineTo(skylineRect.left + skylineRect.width * 0.46,
          skylineRect.top + skylineRect.height * 0.08)
      ..lineTo(skylineRect.left + skylineRect.width * 0.46,
          skylineRect.top + skylineRect.height * 0.34)
      ..lineTo(skylineRect.left + skylineRect.width * 0.56,
          skylineRect.top + skylineRect.height * 0.34)
      ..lineTo(skylineRect.left + skylineRect.width * 0.6,
          skylineRect.top + skylineRect.height * 0.18)
      ..lineTo(skylineRect.left + skylineRect.width * 0.69,
          skylineRect.top + skylineRect.height * 0.32)
      ..lineTo(skylineRect.left + skylineRect.width * 0.78,
          skylineRect.top + skylineRect.height * 0.12)
      ..lineTo(skylineRect.left + skylineRect.width * 0.88,
          skylineRect.top + skylineRect.height * 0.22)
      ..lineTo(skylineRect.left + skylineRect.width * 0.96,
          skylineRect.top + skylineRect.height * 0.18)
      ..lineTo(skylineRect.left + skylineRect.width * 0.96, skylineRect.bottom)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[_greenDark, _green],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(path.getBounds()),
    );
  }

  void _paintShield(Canvas canvas, Size size, Rect emblemRect) {
    final outerShield = _shieldPath(emblemRect);
    final whiteBorderRect = emblemRect.deflate(emblemRect.width * 0.035);
    final whiteShield = _shieldPath(whiteBorderRect);
    final innerRect = whiteBorderRect.deflate(emblemRect.width * 0.045);
    final innerShield = _shieldPath(innerRect);

    if (showShadow) {
      canvas.drawShadow(outerShield, _shadow, 10, true);
    }

    canvas.drawPath(
      outerShield,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[_greenDark, _green],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(outerShield.getBounds()),
    );
    canvas.drawPath(whiteShield, Paint()..color = Colors.white);
    canvas.drawPath(
      innerShield,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(innerShield.getBounds()),
    );

    canvas.save();
    canvas.clipPath(innerShield);

    final centerX = innerRect.center.dx;
    final midY = innerRect.top + innerRect.height * 0.45;

    canvas.drawPath(
      Path()
        ..moveTo(innerRect.left, innerRect.top)
        ..lineTo(centerX, innerRect.top)
        ..lineTo(centerX, midY)
        ..lineTo(innerRect.left, innerRect.bottom)
        ..close(),
      Paint()..color = _orangeLight,
    );
    canvas.drawPath(
      Path()
        ..moveTo(centerX, innerRect.top)
        ..lineTo(innerRect.right, innerRect.top)
        ..lineTo(innerRect.right, innerRect.bottom)
        ..lineTo(centerX, midY)
        ..close(),
      Paint()..color = _red,
    );
    canvas.drawPath(
      Path()
        ..moveTo(innerRect.left, innerRect.bottom)
        ..lineTo(centerX, midY)
        ..lineTo(centerX, innerRect.bottom)
        ..close(),
      Paint()..color = _greenLight,
    );
    canvas.drawPath(
      Path()
        ..moveTo(centerX, midY)
        ..lineTo(innerRect.right, innerRect.bottom)
        ..lineTo(centerX, innerRect.bottom)
        ..close(),
      Paint()..color = _greenDark,
    );

    _paintSignalWaves(canvas, innerRect);
    _paintPin(canvas, size, innerRect);
    _paintCamera(canvas, innerRect);

    canvas.restore();
  }

  void _paintSignalWaves(Canvas canvas, Rect innerRect) {
    final origin = Offset(innerRect.left + innerRect.width * 0.2,
        innerRect.top + innerRect.height * 0.34);
    final wavePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerRect.height * 0.028
      ..strokeCap = StrokeCap.round;

    for (final radius in <double>[0.075, 0.13, 0.185]) {
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: innerRect.width * radius),
        2.3,
        1.35,
        false,
        wavePaint,
      );
    }

    canvas.drawCircle(
      origin.translate(innerRect.width * 0.02, innerRect.height * 0.01),
      innerRect.width * 0.028,
      Paint()..color = Colors.white,
    );
  }

  void _paintPin(Canvas canvas, Size size, Rect innerRect) {
    final pinCenter =
        Offset(innerRect.center.dx, innerRect.top + innerRect.height * 0.33);
    final pinRadius = innerRect.width * 0.16;
    final tip =
        Offset(innerRect.center.dx, innerRect.top + innerRect.height * 0.75);

    final pinPath = Path()
      ..moveTo(pinCenter.dx, pinCenter.dy - pinRadius)
      ..quadraticBezierTo(
        pinCenter.dx + pinRadius,
        pinCenter.dy - pinRadius * 0.55,
        pinCenter.dx + pinRadius * 0.8,
        pinCenter.dy + pinRadius * 0.35,
      )
      ..quadraticBezierTo(
        pinCenter.dx + pinRadius * 0.34,
        pinCenter.dy + pinRadius * 1.15,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        pinCenter.dx - pinRadius * 0.34,
        pinCenter.dy + pinRadius * 1.15,
        pinCenter.dx - pinRadius * 0.8,
        pinCenter.dy + pinRadius * 0.35,
      )
      ..quadraticBezierTo(
        pinCenter.dx - pinRadius,
        pinCenter.dy - pinRadius * 0.55,
        pinCenter.dx,
        pinCenter.dy - pinRadius,
      )
      ..close();

    if (showShadow) {
      canvas.drawShadow(pinPath, const Color(0x26000000), 8, true);
    }

    canvas.drawPath(pinPath, Paint()..color = Colors.white);
    canvas.drawCircle(
      pinCenter.translate(0, pinRadius * 0.04),
      pinRadius * 0.44,
      Paint()..color = _red,
    );
    canvas.drawCircle(
      pinCenter.translate(pinRadius * 0.22, -pinRadius * 0.18),
      pinRadius * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );

    final baseOuter = Rect.fromCenter(
      center: Offset(
          innerRect.center.dx, innerRect.bottom - innerRect.height * 0.12),
      width: innerRect.width * 0.34,
      height: innerRect.height * 0.11,
    );
    final baseInner = Rect.fromCenter(
      center: baseOuter.center,
      width: baseOuter.width * 0.55,
      height: baseOuter.height * 0.5,
    );
    canvas.drawOval(baseOuter, Paint()..color = _cream);
    canvas.drawOval(baseInner, Paint()..color = _orangeLight);
  }

  void _paintCamera(Canvas canvas, Rect innerRect) {
    final cameraRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        innerRect.right - innerRect.width * 0.28,
        innerRect.top + innerRect.height * 0.56,
        innerRect.width * 0.2,
        innerRect.height * 0.12,
      ),
      Radius.circular(innerRect.width * 0.03),
    );

    canvas.drawRRect(cameraRect, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(cameraRect.left + cameraRect.width * 0.45, cameraRect.center.dy),
      cameraRect.height * 0.24,
      Paint()..color = _red,
    );
    canvas.drawPath(
      Path()
        ..moveTo(
            cameraRect.right - cameraRect.width * 0.08, cameraRect.center.dy)
        ..lineTo(cameraRect.right + cameraRect.width * 0.12,
            cameraRect.center.dy - cameraRect.height * 0.18)
        ..lineTo(cameraRect.right + cameraRect.width * 0.12,
            cameraRect.center.dy + cameraRect.height * 0.18)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  void _paintWordmark(Canvas canvas, Size size) {
    final ribbonRect = Rect.fromLTWH(
      size.width * 0.11,
      size.height * 0.68,
      size.width * 0.78,
      size.height * 0.16,
    );
    final ribbon = RRect.fromRectAndRadius(
      ribbonRect,
      Radius.circular(size.height * 0.038),
    );

    if (showShadow) {
      canvas.drawShadow(
        Path()..addRRect(ribbon),
        _shadow,
        8,
        true,
      );
    }

    canvas.save();
    canvas.clipRRect(ribbon);
    canvas.drawRect(
      Rect.fromLTWH(ribbonRect.left, ribbonRect.top, ribbonRect.width * 0.56,
          ribbonRect.height),
      Paint()..color = _red,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        ribbonRect.left + ribbonRect.width * 0.56,
        ribbonRect.top,
        ribbonRect.width * 0.44,
        ribbonRect.height,
      ),
      Paint()..color = _green,
    );
    canvas.restore();

    _paintCenteredText(
      canvas,
      text: 'SURAKSHA SETU',
      rect: ribbonRect,
      fontSize: size.height * 0.086,
      weight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: size.width * 0.0025,
    );
  }

  void _paintTagline(Canvas canvas, Size size) {
    final taglineRect = Rect.fromLTWH(
      size.width * 0.24,
      size.height * 0.86,
      size.width * 0.52,
      size.height * 0.085,
    );
    final badge = RRect.fromRectAndRadius(
      taglineRect,
      Radius.circular(size.height * 0.03),
    );

    canvas.drawRRect(
      badge,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[_red, _redDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(taglineRect),
    );

    _paintCenteredText(
      canvas,
      text: 'RAPID RESPONSE & SAFETY ALERTS',
      rect: taglineRect,
      fontSize: size.height * 0.035,
      weight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: size.width * 0.002,
    );
  }

  void _paintCenteredText(
    Canvas canvas, {
    required String text,
    required Rect rect,
    required double fontSize,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width);

    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  Path _shieldPath(Rect rect) {
    return Path()
      ..moveTo(rect.center.dx, rect.top)
      ..quadraticBezierTo(
        rect.right - rect.width * 0.06,
        rect.top + rect.height * 0.06,
        rect.right,
        rect.top + rect.height * 0.18,
      )
      ..lineTo(rect.right, rect.bottom - rect.height * 0.2)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom - rect.height * 0.08,
        rect.center.dx,
        rect.bottom,
      )
      ..quadraticBezierTo(
        rect.left,
        rect.bottom - rect.height * 0.08,
        rect.left,
        rect.bottom - rect.height * 0.2,
      )
      ..lineTo(rect.left, rect.top + rect.height * 0.18)
      ..quadraticBezierTo(
        rect.left + rect.width * 0.06,
        rect.top + rect.height * 0.06,
        rect.center.dx,
        rect.top,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _SurakshaSetuBrandLogoPainter oldDelegate) {
    return oldDelegate.compact != compact ||
        oldDelegate.showShadow != showShadow;
  }
}
