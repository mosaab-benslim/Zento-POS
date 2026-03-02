import 'package:flutter/material.dart';

class Category {
  final int? id;
  final String name;
  final int orderIndex; // To sort buttons on the screen
  final int colorValue; // Hex color value
  final bool isEnabled;
  final String? imagePath; // Path to category image

  Category({
    this.id,
    required this.name,
    required this.orderIndex,
    this.colorValue = 0xFF3498DB, // Default blue
    this.isEnabled = true,
    this.imagePath,
  });

  // Helper to get Color object
  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'orderIndex': orderIndex,
      'colorValue': colorValue,
      'isEnabled': isEnabled ? 1 : 0,
      'imagePath': imagePath,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      orderIndex: map['orderIndex'] as int? ?? 0,
      colorValue: map['colorValue'] as int? ?? 0xFF3498DB,
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
      imagePath: map['imagePath'] as String?,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    int? orderIndex,
    int? colorValue,
    bool? isEnabled,
    String? imagePath,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      colorValue: colorValue ?? this.colorValue,
      isEnabled: isEnabled ?? this.isEnabled,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
