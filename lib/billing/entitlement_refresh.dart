import 'package:flutter/material.dart';

class EntitlementRefresh extends InheritedWidget {
  const EntitlementRefresh({
    super.key,
    required this.refresh,
    required super.child,
  });

  final Future<void> Function() refresh;

  static EntitlementRefresh? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<EntitlementRefresh>();
  }

  @override
  bool updateShouldNotify(EntitlementRefresh oldWidget) => false;
}
