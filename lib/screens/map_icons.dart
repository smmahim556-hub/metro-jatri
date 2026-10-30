import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Draws marker bitmaps on a canvas, since Google Maps markers take images
/// rather than widgets.
class MapIcons {
  static Future<BitmapDescriptor> train(Color color,
      {double size = 46, double pixelRatio = 3}) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(pixelRatio);
    final r = size / 2;
    c.drawCircle(Offset(r, r + 1), r - 2,
        Paint()
          ..color = Colors.black38
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(Offset(r, r), r - 3, Paint()..color = Colors.white);
    c.drawCircle(Offset(r, r), r - 6, Paint()..color = color);
    _icon(c, Icons.directions_subway_filled, Offset(r, r), size * 0.5);
    return _toBitmap(rec, size, size, pixelRatio);
  }

  /// A station dot with its name in a white pill to the right.
  static Future<BitmapDescriptor> station(String name, Color lineColor,
      {double pixelRatio = 3}) async {
    const dot = 16.0, gap = 4.0, fontSize = 12.0;
    final tp = TextPainter(
      text: TextSpan(
          text: name,
          style: const TextStyle(
              fontSize: fontSize,
              color: Colors.black87,
              fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    final pillW = tp.width + 12, pillH = tp.height + 4;
    // The dot sits at the centre of the bitmap so the anchor stays simple:
    // mirror the label's width on the left as empty space.
    final w = (dot / 2 + gap + pillW) * 2, h = pillH > dot ? pillH : dot;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(pixelRatio);
    final cx = w / 2, cy = h / 2;
    c.drawCircle(Offset(cx, cy), dot / 2 - 1, Paint()..color = Colors.white);
    c.drawCircle(
        Offset(cx, cy),
        dot / 2 - 2.5,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final left = cx + dot / 2 + gap;
    c.drawRRect(
        RRect.fromLTRBR(left, cy - pillH / 2, left + pillW, cy + pillH / 2,
            const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.92));
    tp.paint(c, Offset(left + 6, cy - tp.height / 2));
    return _toBitmap(rec, w, h, pixelRatio);
  }

  static void _icon(Canvas c, IconData icon, Offset center, double size) {
    final tp = TextPainter(
      text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
              fontSize: size,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  static Future<BitmapDescriptor> _toBitmap(
      ui.PictureRecorder rec, double w, double h, double pixelRatio) async {
    final img = await rec
        .endRecording()
        .toImage((w * pixelRatio).ceil(), (h * pixelRatio).ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BytesMapBitmap(data!.buffer.asUint8List(),
        imagePixelRatio: pixelRatio, width: w, height: h);
  }
}
