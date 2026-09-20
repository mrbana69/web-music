class WebviewCookie {
  final String name;
  final String value;
  final String domain;
  final String path;
  final DateTime? expires;
  final bool secure;
  final bool httpOnly;
  final bool sessionOnly;

  WebviewCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.expires,
    required this.secure,
    required this.httpOnly,
    required this.sessionOnly,
  });

  factory WebviewCookie.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] as String?)?.replaceAll('\u0000', '').trim() ?? '';
    final rawValue = (json['value'] as String?)?.replaceAll('\u0000', '').trim() ?? '';
    final rawDomain = (json['domain'] as String?)?.replaceAll('\u0000', '').trim() ?? '';
    final rawPath = (json['path'] as String?)?.replaceAll('\u0000', '').trim() ?? '';

    return WebviewCookie(
      name: rawName,
      value: rawValue,
      domain: rawDomain,
      expires: json['expires'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              ((json['expires'] as num) * 1000).toInt(),
            ),
      httpOnly: json['httpOnly'] ?? false,
      path: rawPath,
      secure: json['secure'] ?? false,
      sessionOnly: json['sessionOnly'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'expires':
          expires == null ? null : expires!.millisecondsSinceEpoch ~/ 1000,
      'secure': secure,
      'httpOnly': httpOnly,
      'sessionOnly': sessionOnly,
    };
  }
}
