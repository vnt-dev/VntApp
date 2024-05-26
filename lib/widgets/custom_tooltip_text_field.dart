import 'package:flutter/material.dart';

class CustomTooltipTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String tooltipMessage;
  final int maxLength;
  final String? Function(String?)? validator;

  const CustomTooltipTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.tooltipMessage,
    this.maxLength = 32,
    this.validator,
  });

  @override
  _CustomTooltipTextFieldState createState() => _CustomTooltipTextFieldState();
}

class _CustomTooltipTextFieldState extends State<CustomTooltipTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _showTooltip = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _showTooltip = _focusNode.hasFocus;
        if (!_focusNode.hasFocus && widget.validator != null) {
          setState(() {
            _errorText = widget.validator!(widget.controller.text);
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showTooltip)
          Text(
            '${widget.labelText} ${widget.tooltipMessage}',
            style: const TextStyle(color: Colors.black, fontSize: 13),
          ),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: !_showTooltip ? widget.labelText : null,
            errorText: _errorText,
          ),
          maxLength: widget.maxLength,
        ),
      ],
    );
  }
}
