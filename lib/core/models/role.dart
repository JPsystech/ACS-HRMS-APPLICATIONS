/// Role hierarchy with rank mapping for backend role strings.
/// Rank 1: ADMIN (highest)
/// Rank 2: MD
/// Rank 3: VP (department vice president, not HR)
/// Rank 4: MANAGER
/// Rank 5: EMPLOYEE
/// Rank 6+: future roles
enum Role {
  admin('ADMIN', 1),
  md('MD', 2),
  vp('VP', 3),
  manager('MANAGER', 4),
  employee('EMPLOYEE', 5),
  unknown('', 999); // Fallback for unknown roles

  final String backendValue;
  final int rank;

  const Role(this.backendValue, this.rank);

  /// Parse role from backend string value (case-insensitive)
  static Role fromString(String value) {
    final normalized = value.trim().toUpperCase();
    for (final role in Role.values) {
      if (role.backendValue.toUpperCase() == normalized) {
        return role;
      }
    }
    return Role.unknown;
  }

  /// Get role rank from backend string value
  static int getRankFromString(String roleName) {
    return fromString(roleName).rank;
  }

  /// Check if this role has higher or equal rank compared to another role
  bool hasHigherOrEqualRankThan(Role other) {
    return rank <= other.rank;
  }

  /// Check if this role has higher or equal rank compared to another role string
  bool hasHigherOrEqualRankThanString(String otherRole) {
    return rank <= getRankFromString(otherRole);
  }

  @override
  String toString() => backendValue;
}