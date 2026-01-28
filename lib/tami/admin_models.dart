// ==================== MODÈLES ADMIN ====================

enum AdminRole {
  superAdmin('Super Admin'),
  admin('Admin'),
  readOnly('Lecture seule');

  final String label;
  const AdminRole(this.label);
}

class AdminUser {
  final String id;
  final String email;
  final String fullName;
  final AdminRole role;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;

  AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.isActive = true,
    this.lastLogin,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'] ?? '',
      role: AdminRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => AdminRole.readOnly,
      ),
      isActive: json['is_active'] ?? true,
      lastLogin: json['last_login'] != null 
          ? DateTime.parse(json['last_login'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get canWrite => role != AdminRole.readOnly;
  bool get isSuperAdmin => role == AdminRole.superAdmin;
}

// ==================== STATISTIQUES DASHBOARD ====================

class DocumentStats {
  final int total;
  final int chifa;
  final int cni;
  final int passport;
  final int today;
  final int week;
  final int month;
  final int verified;
  final int lowConfidence;
  final Map<String, int> byType;

  DocumentStats({
    required this.total,
    required this.chifa,
    required this.cni,
    required this.passport,
    this.today = 0,
    this.week = 0,
    this.month = 0,
    this.verified = 0,
    this.lowConfidence = 0,
    Map<String, int>? byType,
  }) : byType = byType ?? {'chifa': chifa, 'cni': cni, 'passport': passport};

  factory DocumentStats.empty() {
    return DocumentStats(
      total: 0,
      chifa: 0,
      cni: 0,
      passport: 0,
    );
  }

  factory DocumentStats.fromCache(Map<String, dynamic> cache) {
    return DocumentStats(
      total: cache['total_count'] ?? 0,
      chifa: 0, // Calculé après
      cni: 0,
      passport: 0,
      today: cache['today_count'] ?? 0,
      week: cache['week_count'] ?? 0,
      month: cache['month_count'] ?? 0,
      verified: cache['verified_count'] ?? 0,
    );
  }
}
