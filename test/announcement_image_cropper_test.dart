import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/announcement_image_cropper.dart';

void main() {
  test('wide images are cropped to the 16:7 cover area', () {
    final rect = announcementCoverSourceRect(
      sourceSize: const Size(2000, 1000),
      settings: const AnnouncementCropSettings(),
    );

    expect(rect.width / rect.height, closeTo(16 / 7, 0.0001));
    expect(rect.center, const Offset(1000, 500));
  });

  test('focus and zoom select a smaller exact area', () {
    final rect = announcementCoverSourceRect(
      sourceSize: const Size(1600, 1200),
      settings: const AnnouncementCropSettings(
        focusX: 1,
        focusY: -1,
        zoom: 2,
      ),
    );

    expect(rect.width / rect.height, closeTo(16 / 7, 0.0001));
    expect(rect.right, 1600);
    expect(rect.top, 0);
  });

  test('hosted image URLs work even without a file extension', () {
    expect(
      isAnnouncementImageAttachment(
        null,
        'https://res.cloudinary.com/campus/image/upload/v1/announcement',
      ),
      isTrue,
    );
    expect(
      isAnnouncementImageAttachment(
        'notice.pdf',
        'https://res.cloudinary.com/campus/raw/upload/v1/notice',
      ),
      isFalse,
    );
  });
}
