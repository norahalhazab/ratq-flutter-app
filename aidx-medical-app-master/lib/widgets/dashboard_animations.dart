import 'package:flutter/material.dart';

class StaggeredAnimation extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final double verticalOffset;

  const StaggeredAnimation({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 800), // Slower, smoother
    this.verticalOffset = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(
        (index * 0.1).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutQuart, // Smoother curve
      ),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, verticalOffset * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class CountUpAnimation extends StatefulWidget {
  final double endValue;
  final Duration duration;
  final TextStyle? style;
  final String suffix;
  final int precision;

  const CountUpAnimation({
    super.key,
    required this.endValue,
    this.duration = const Duration(seconds: 2),
    this.style,
    this.suffix = '',
    this.precision = 0,
  });

  @override
  State<CountUpAnimation> createState() => _CountUpAnimationState();
}

class _CountUpAnimationState extends State<CountUpAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.endValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endValue != widget.endValue) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.endValue,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value.toStringAsFixed(widget.precision)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
