import 'package:flutter/material.dart';

class CategoryChips extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryChips({
    Key? key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  State<CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CategoryChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      _scrollToSelectedCategory();
    }
  }

  void _scrollToSelectedCategory() {
    final index = widget.categories.indexOf(widget.selectedCategory);
    if (index != -1) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = 100.0; // Approximate width of each chip

      final offset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
      final clampedOffset =
          offset.clamp(0.0, _scrollController.position.maxScrollExtent);

      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final isSelected = category == widget.selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: isSelected ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 1.0 + (value * 0.05),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        widget.onCategorySelected(category);
                      }
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.blue.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: Color.lerp(Colors.black, Colors.blue, value),
                      fontWeight: FontWeight.lerp(
                        FontWeight.normal,
                        FontWeight.bold,
                        value,
                      ),
                    ),
                    elevation: value * 1.0,
                    pressElevation: 2.0,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
