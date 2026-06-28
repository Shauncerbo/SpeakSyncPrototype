class AuthService {
  static final Map<String, String> _users = {
    'student@speaksync.com': 'capstone123',
  };

  static bool authenticate(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();
    final storedPassword = _users[normalizedEmail];
    return storedPassword != null && storedPassword == password;
  }

  static String? registerUser(String fullName, String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();

    if (fullName.trim().isEmpty) {
      return 'Please enter your full name.';
    }
    if (normalizedEmail.isEmpty) {
      return 'Please enter your email address.';
    }
    if (!normalizedEmail.contains('@') || !normalizedEmail.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (_users.containsKey(normalizedEmail)) {
      return 'An account already exists for that email.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters long.';
    }

    _users[normalizedEmail] = password;
    return null;
  }
}
