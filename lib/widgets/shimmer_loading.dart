import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  final bool isDark;

  const ShimmerLoading({
    Key? key,
    this.isDark = false,
  }) : super(key: key);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ShimmerItem(
            controller: _shimmerController,
            isDark: widget.isDark,
          ),
        );
      },
    );
  }
}

class _ShimmerItem extends StatelessWidget {
  final AnimationController controller;
  final bool isDark;

  const _ShimmerItem({
    Key? key,
    required this.controller,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Colors for light and dark mode
    final baseColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]!;
    final highlightColor = isDark ? const Color(0xFF3D3D3D) : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    colors: [
                      baseColor,
                      highlightColor,
                      baseColor,
                    ],
                    stops: const [0.1, 0.3, 0.4],
                    begin: const Alignment(-1.0, -0.3),
                    end: const Alignment(1.0, 0.3),
                    transform: _SlidingGradientTransform(controller.value),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category placeholder
                    Container(
                      width: 80,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            baseColor,
                            highlightColor,
                            baseColor,
                          ],
                          stops: const [0.1, 0.3, 0.4],
                          begin: const Alignment(-1.0, -0.3),
                          end: const Alignment(1.0, 0.3),
                          transform:
                              _SlidingGradientTransform(controller.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title placeholder
                    Container(
                      width: double.infinity,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            baseColor,
                            highlightColor,
                            baseColor,
                          ],
                          stops: const [0.1, 0.3, 0.4],
                          begin: const Alignment(-1.0, -0.3),
                          end: const Alignment(1.0, 0.3),
                          transform:
                              _SlidingGradientTransform(controller.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description placeholder
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            baseColor,
                            highlightColor,
                            baseColor,
                          ],
                          stops: const [0.1, 0.3, 0.4],
                          begin: const Alignment(-1.0, -0.3),
                          end: const Alignment(1.0, 0.3),
                          transform:
                              _SlidingGradientTransform(controller.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity * 0.7,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            baseColor,
                            highlightColor,
                            baseColor,
                          ],
                          stops: const [0.1, 0.3, 0.4],
                          begin: const Alignment(-1.0, -0.3),
                          end: const Alignment(1.0, 0.3),
                          transform:
                              _SlidingGradientTransform(controller.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
