import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// ecdh.dart — replica o handshake do site (performECDH em ShakaPlayer.tsx).
///
/// O site gera um par de chaves ECDH efémero (curva P-256), exporta a chave
/// pública em formato "raw" (não comprimido: 0x04 || X || Y, 65 bytes) e
/// envia-a em base64 como query param `clientPubKey`. O JS original nunca
/// chega a usar `deriveBits` com a chave privada depois — o payload de
/// resposta (drm_key_hex) já vem pronto a usar. Por isso só precisamos de
/// gerar uma chave pública P-256 válida — sem isto o backend rejeita/não
/// responde corretamente ao pedido de stream (causa do player não arrancar).
class Ecdh {
  Ecdh._();

  static String generateClientPubKeyBase64() {
    final domainParams = ECDomainParameters('prime256v1'); // P-256 / secp256r1
    final keyGen = ECKeyGenerator();
    final secureRandom = _secureRandom();

    keyGen.init(ParametersWithRandom(
      ECKeyGeneratorParameters(domainParams),
      secureRandom,
    ));

    final pair = keyGen.generateKeyPair();
    final pub = pair.publicKey as ECPublicKey;

    final rawPoint = pub.Q!.getEncoded(false);
    return base64.encode(rawPoint);
  }

  static SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}
