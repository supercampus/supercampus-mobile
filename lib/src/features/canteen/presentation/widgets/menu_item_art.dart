import 'package:flutter/material.dart';

import '../../data/canteen_models.dart';

/// The square thumbnail on a menu row.
///
/// Items normally carry a photograph. Where one is missing — or fails to load
/// on a flaky campus connection — the row falls back to a tinted tile carrying
/// the storefront's icon, so the list keeps its rhythm instead of collapsing.
class MenuItemArt extends StatelessWidget {
  const MenuItemArt({super.key, required this.item, this.size = 72});

  final CanteenMenuItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final image = item.imageUrl;
    final devicePixels = (size * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(64, 512);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: image == null || image.isEmpty
            ? _Fallback(store: item.store, size: size)
            : Image.network(
                menuItemThumbnailUrl(image, pixels: devicePixels),
                fit: BoxFit.cover,
                cacheWidth: devicePixels,
                cacheHeight: devicePixels,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _Fallback(store: item.store, size: size),
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : _Fallback(store: item.store, size: size),
              ),
      ),
    );
  }
}

/// Cloudinary originals can be multi-megapixel phone photographs. Asking the
/// image service and Flutter decoder for only the pixels used by the card
/// avoids memory-related decode failures on lower-end phones.
String menuItemThumbnailUrl(String raw, {int pixels = 256}) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.host.toLowerCase() != 'res.cloudinary.com' ||
      !uri.path.contains('/image/upload/')) {
    return raw;
  }
  final bounded = pixels.clamp(64, 512);
  return uri
      .replace(
        path: uri.path.replaceFirst(
          '/image/upload/',
          '/image/upload/c_fill,w_$bounded,h_$bounded,q_auto/',
        ),
      )
      .toString();
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.store, required this.size});

  final MenuStore store;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (store) {
      MenuStore.classic => Icons.restaurant,
      MenuStore.bites => Icons.local_pizza_outlined,
      MenuStore.stationery => Icons.storefront_outlined,
    };
    return Container(
      color: const Color(0xFFDDE7FB),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.42, color: const Color(0xFF2563EB)),
    );
  }
}
