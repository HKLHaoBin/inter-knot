import 'dart:io';

void main() {
  final pem = Platform.environment['PEM'];
  final clientId = Platform.environment['CLIENT_ID'];
  File('lib/secret.dart').writeAsString(
    "import 'dart:convert';\nfinal pem = String.fromCharCodes(base64Decode('$pem'));\nfinal clientId = String.fromCharCodes(base64Decode('$clientId'));",
  );
}
