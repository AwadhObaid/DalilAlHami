import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x16003D43),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x29003D43),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x10003D43),
      blurRadius: 13,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> navigation = [
    BoxShadow(
      color: Color(0x1A003D43),
      blurRadius: 24,
      offset: Offset(0, -4),
    ),
  ];
}
