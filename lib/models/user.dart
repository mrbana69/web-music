class GoogleUser {
  final String name;
  final String email;
  final String avatarUrl;
  final String? token;
  final String? cookie;

  const GoogleUser({
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.token,
    this.cookie,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'token': token,
    'cookie': cookie,
  };

  factory GoogleUser.fromJson(Map<String, dynamic> json) => GoogleUser(
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString() ?? '',
    token: json['token']?.toString(),
    cookie: json['cookie']?.toString(),
  );

  GoogleUser copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? token,
    String? cookie,
  }) {
    return GoogleUser(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      token: token ?? this.token,
      cookie: cookie ?? this.cookie,
    );
  }
}
