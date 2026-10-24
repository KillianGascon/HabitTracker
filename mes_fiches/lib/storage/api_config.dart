/// Réglages non secrets de la connexion à l'API (le jeton d'appareil et le
/// secret Cloudflare sont dans le coffre, voir [SecretStore]).
class ApiConfig {
  const ApiConfig({required this.baseUrl, this.cfClientId = '', required this.deviceName});

  /// Ex. `https://api.mondomaine.fr` ou, en dev sur l'émulateur, `http://10.0.2.2:3000`.
  final String baseUrl;

  /// Client ID du jeton de service Cloudflare Access (vide = pas de Cloudflare Access).
  final String cfClientId;
  final String deviceName;

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'cfClientId': cfClientId,
        'deviceName': deviceName,
      };

  factory ApiConfig.fromJson(Map<String, dynamic> j) => ApiConfig(
        baseUrl: j['baseUrl'] as String,
        cfClientId: j['cfClientId'] as String? ?? '',
        deviceName: j['deviceName'] as String? ?? 'Téléphone',
      );
}
