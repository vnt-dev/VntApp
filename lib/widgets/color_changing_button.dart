import 'package:flutter/material.dart';
import 'dart:async';

class ColorChangingButton extends StatefulWidget {
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onPressed;

  const ColorChangingButton({super.key, 
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  @override
  _ColorChangingButtonState createState() => _ColorChangingButtonState();
}

class _ColorChangingButtonState extends State<ColorChangingButton> {
  late Timer _timer;
  late Color _currentColor;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.colors[_currentIndex];
    _startColorChange();
  }

  void _startColorChange() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.colors.length;
        _currentColor = widget.colors[_currentIndex];
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(widget.icon, color: _currentColor),
      onPressed: widget.onPressed,
    );
  }
}
