class DbConfig {
  const DbConfig({
    required this.host,
    this.port = 5432,
    this.database = 'mes_fiches',
    required this.username,
    required this.password,
    this.ssl = false,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool ssl;

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'database': database,
        'username': username,
        'password': password,
        'ssl': ssl,
      };

  factory DbConfig.fromJson(Map<String, dynamic> j) => DbConfig(
        host: j['host'] as String,
        port: j['port'] as int,
        database: j['database'] as String,
        username: j['username'] as String,
        password: j['password'] as String,
        ssl: j['ssl'] as bool? ?? false,
      );
}
