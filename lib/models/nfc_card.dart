class NFCCard {
  final int? id;
  final String name;
  final String uid;
  final String technology;
  final String? data;
  final DateTime createdAt;
  final DateTime? lastUsed;

  NFCCard({
    this.id,
    required this.name,
    required this.uid,
    required this.technology,
    this.data,
    required this.createdAt,
    this.lastUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'uid': uid,
      'technology': technology,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed?.toIso8601String(),
    };
  }

  static NFCCard fromMap(Map<String, dynamic> map) {
    return NFCCard(
      id: map['id'],
      name: map['name'],
      uid: map['uid'],
      technology: map['technology'],
      data: map['data'],
      createdAt: DateTime.parse(map['createdAt']),
      lastUsed: map['lastUsed'] != null
          ? DateTime.parse(map['lastUsed'])
          : null,
    );
  }

  NFCCard copyWith({
    int? id,
    String? name,
    String? uid,
    String? technology,
    String? data,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return NFCCard(
      id: id ?? this.id,
      name: name ?? this.name,
      uid: uid ?? this.uid,
      technology: technology ?? this.technology,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  String toString() {
    return 'NFCCard{id: $id, name: $name, uid: $uid, technology: $technology, createdAt: $createdAt}';
  }
}
