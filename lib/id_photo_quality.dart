import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Checks whether a photo of an ID is clear enough to read, so a resident
/// can retake a bad shot right away (panel revision #3) instead of being
/// rejected by MDRRMO later.
///
/// Uses only dart:ui — no extra packages. The photo is decoded small
/// (320 px wide), turned to grayscale, and three things are measured:
///
///  * sharpness  — variance of the Laplacian (how strong the edges / text
///                 are). Blur smooths edges, so a blurry photo scores low.
///  * brightness — average gray level, 0–255. Too dark scores low.
///  * glare      — share of almost-white pixels (light bouncing off the card).
///
/// When [analyze] gets a `frameAspect` (camera photos taken with the
/// on-screen ID frame), only the part of the photo that was inside that
/// frame is checked, so a blurry table or wall around the ID doesn't make
/// a sharp ID look blurry.
class IdPhotoQuality {
  final double sharpness;
  final double brightness;
  final double glare;

  /// True when only the on-screen frame area was checked (camera photo).
  final bool framed;

  const IdPhotoQuality({
    required this.sharpness,
    required this.brightness,
    required this.glare,
    this.framed = false,
  });

  // Thresholds, calibrated on simulated phone photos of an ID (1080 px wide,
  // checked at 320 px). The address line — what MDRRMO needs to read —
  // stops being readable at about 3 px of focus blur or 4 px of shake.
  //   camera frame: sharp ≈ 1300, 2 px blur ≈ 250, 3 px ≈ 73, shake ≈ 97
  //   whole photo:  sharp ≈ 500,  2 px blur ≈ 95,  3 px ≈ 28, shake ≈ 37
  // Raise these to be stricter, lower them if good photos get flagged.

  /// Below this the photo counts as blurry (camera photo, frame area).
  static const double blurThresholdFramed = 150;

  /// Below this the photo counts as blurry (gallery photo, whole image —
  /// lower because the background around the ID is included).
  static const double blurThresholdWhole = 60;

  /// Average brightness below this counts as too dark.
  static const double darkThreshold = 50;

  /// More than this share of nearly-white pixels counts as glare.
  static const double glareThresholdFramed = 0.08;
  static const double glareThresholdWhole = 0.05;

  bool get isBlurry =>
      sharpness < (framed ? blurThresholdFramed : blurThresholdWhole);
  bool get isTooDark => brightness < darkThreshold;
  bool get hasGlare =>
      glare > (framed ? glareThresholdFramed : glareThresholdWhole);
  bool get isClear => !isBlurry && !isTooDark && !hasGlare;

  /// Short headline for the warning box, or null when the photo is fine.
  String? get title {
    if (isBlurry) return 'The photo may be unclear.';
    if (isTooDark) return 'The photo is too dark.';
    if (hasGlare) return 'There is glare on the ID.';
    return null;
  }

  /// What the resident should do about it, or null when the photo is fine.
  String? get advice {
    if (isBlurry) {
      return 'Hold your phone steady, keep the ID in focus, and try better light.';
    }
    if (isTooDark) return 'Move to a brighter place and take the photo again.';
    if (hasGlare) {
      return 'Tilt the ID a little or move away from direct light, then retake.';
    }
    return null;
  }

  /// Returns null if the image can't be read — callers should then let the
  /// resident decide. The check never blocks sign-up on its own.
  static Future<IdPhotoQuality?> analyze(
    File file, {
    double? frameAspect,
  }) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 320,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final int w = image.width;
      final int h = image.height;
      image.dispose();
      codec.dispose();

      if (data == null || w < 3 || h < 3) return null;

      // Rows to check: the whole photo, or just the band that was inside
      // the on-screen frame (the frame covers the full width, centered).
      int top = 0;
      int bottom = h;
      if (frameAspect != null && frameAspect > 0) {
        int bandHeight = (w / frameAspect).round();
        if (bandHeight > h) bandHeight = h;
        if (bandHeight < 3) bandHeight = 3;
        top = (h - bandHeight) ~/ 2;
        bottom = top + bandHeight;
      }

      final Uint8List px = data.buffer.asUint8List();
      final Float64List gray = Float64List(w * h);
      for (int i = 0, p = 0; i < w * h; i++, p += 4) {
        gray[i] = 0.299 * px[p] + 0.587 * px[p + 1] + 0.114 * px[p + 2];
      }

      double brightnessSum = 0;
      int brightCount = 0;
      int pixelCount = 0;
      double lapSum = 0;
      double lapSumSq = 0;
      int lapCount = 0;

      for (int y = top; y < bottom; y++) {
        for (int x = 0; x < w; x++) {
          final int i = y * w + x;
          final double g = gray[i];
          brightnessSum += g;
          if (g >= 250) brightCount++;
          pixelCount++;

          if (y > 0 && y < h - 1 && x > 0 && x < w - 1) {
            final double lap =
                gray[i - w] + gray[i + w] + gray[i - 1] + gray[i + 1] - 4 * g;
            lapSum += lap;
            lapSumSq += lap * lap;
            lapCount++;
          }
        }
      }

      if (pixelCount == 0 || lapCount == 0) return null;

      final double mean = lapSum / lapCount;
      final double variance = (lapSumSq / lapCount) - (mean * mean);

      return IdPhotoQuality(
        sharpness: variance,
        brightness: brightnessSum / pixelCount,
        glare: brightCount / pixelCount,
        framed: frameAspect != null && frameAspect > 0,
      );
    } catch (_) {
      return null;
    }
  }
}
