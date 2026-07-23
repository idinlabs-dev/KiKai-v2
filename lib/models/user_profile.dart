class UserProfile {
  final String name;
  final String email;
  final String? avatarPath;

  const UserProfile({
    this.name = 'You',
    this.email = '',
    this.avatarPath,
  });
}
