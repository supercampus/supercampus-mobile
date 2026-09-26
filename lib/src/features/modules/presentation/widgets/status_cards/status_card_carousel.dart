import 'package:flutter/material.dart';

import 'status_card_models.dart';

/// A sleek horizontal status card carousel designed for the student dashboard.
///
/// Features:
/// - Smooth horizontal swiping with page snapping
/// - Maintains exact 128px status card height
/// - Animated pagination pill indicators beneath the cards
/// - Dispatches typed [StatusCardData] on user tap for deep-linking
class StatusCardCarousel extends StatefulWidget {
  const StatusCardCarousel({
    super.key,
    required this.cards,
    required this.onCardTap,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  final List<StatusCardData> cards;
  final ValueChanged<StatusCardData> onCardTap;
  final EdgeInsetsGeometry padding;

  @override
  State<StatusCardCarousel> createState() => _StatusCardCarouselState();
}

class _StatusCardCarouselState extends State<StatusCardCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 128px fixed height status card carousel
          SizedBox(
            height: 128,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.cards.length,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              itemBuilder: (context, index) {
                final card = widget.cards[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: card.buildCard(
                    context,
                    onTap: () => widget.onCardTap(card),
                  ),
                );
              },
            ),
          ),

          // Pagination dots (only if more than 1 card)
          if (widget.cards.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.cards.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  height: 4.5,
                  width: isActive ? 18.0 : 5.0,
                  decoration: BoxDecoration(
                    color: isActive
                        ? primaryColor
                        : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
