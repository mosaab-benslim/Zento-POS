class TableModel {
  final int? id;
  final String name;
  final bool isActive;

  const TableModel({
    this.id,
    required this.name,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory TableModel.fromMap(Map<String, dynamic> map) {
    return TableModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  TableModel copyWith({
    int? id,
    String? name,
    bool? isActive,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}
