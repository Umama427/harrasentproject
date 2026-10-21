enum UserRole {
  student,
  admin,
  committee,
}

extension UserRoleDetails on UserRole {
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.admin:
        return 'Admin';
      case UserRole.committee:
        return 'Committee';
    }
  }

  String get apiValue {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.admin:
        return 'admin';
      case UserRole.committee:
        return 'committee';
    }
  }
}