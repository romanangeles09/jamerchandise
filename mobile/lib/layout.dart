import 'package:flutter/material.dart';

/// Phones and short/narrow windows (including phone landscape).
/// Height is checked first so landscape phones never get desktop tables/headers.
bool isCompact(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.height < 640 || size.width < 960 || size.shortestSide < 600;
}

double dialogWidth(BuildContext context, [double desktop = 520]) {
  final width = MediaQuery.sizeOf(context).width;
  if (isCompact(context)) return width - 24;
  return desktop;
}
