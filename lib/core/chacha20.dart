import 'dart:typed_data';

/// chacha20.dart — port Dart puro de chacha20-stream.worker.js (StreamVault v9.1)
///
/// Mantém EXATAMENTE o mesmo algoritmo e ordem de operações do worker JS
/// original (incluindo a correção da ronda diagonal), para garantir que os
/// segmentos encriptados pelo pipeline GitHub Actions/ChaCha20 continuam a
/// decriptar correctamente em Dart.
///
/// Protocolo binário por segmento (chunk-v2), igual ao worker JS:
///   [4 bytes LE: nChunks]
///   repete nChunks vezes:
///     [12 bytes: nonce]
///     [4 bytes LE: chunkLen]
///     [chunkLen bytes: ciphertext]
class ChaCha20 {
  ChaCha20._();

  static const int _c0 = 0x61707865;
  static const int _c1 = 0x3320646e;
  static const int _c2 = 0x79622d32;
  static const int _c3 = 0x6b206574;

  static int _rotl(int v, int n) {
    v &= 0xFFFFFFFF;
    return ((v << n) | (v >>> (32 - n))) & 0xFFFFFFFF;
  }

  /// Converte uma string hex (chave de 32 bytes = 64 hex chars) para bytes.
  static Uint8List hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      out[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return out;
  }

  /// Gera um bloco de 64 bytes de keystream para o contador/nonce dados.
  static Uint8List _block(Uint8List key, int ctr, Uint8List nonce) {
    final kw = Uint32List(8);
    final kbd = ByteData.sublistView(key);
    for (int i = 0; i < 8; i++) {
      kw[i] = kbd.getUint32(i * 4, Endian.little);
    }
    final nw = Uint32List(3);
    final nbd = ByteData.sublistView(nonce);
    for (int i = 0; i < 3; i++) {
      nw[i] = nbd.getUint32(i * 4, Endian.little);
    }

    final w = Uint32List(16);
    w[0] = _c0;  w[1] = _c1;  w[2] = _c2;  w[3] = _c3;
    w[4] = kw[0]; w[5] = kw[1]; w[6] = kw[2]; w[7] = kw[3];
    w[8] = kw[4]; w[9] = kw[5]; w[10] = kw[6]; w[11] = kw[7];
    w[12] = ctr & 0xFFFFFFFF; w[13] = nw[0]; w[14] = nw[1]; w[15] = nw[2];

    final s0=w[0],s1=w[1],s2=w[2],s3=w[3],
          s4=w[4],s5=w[5],s6=w[6],s7=w[7],
          s8=w[8],s9=w[9],s10=w[10],s11=w[11],
          s12=w[12],s13=w[13],s14=w[14],s15=w[15];

    for (int i = 0; i < 10; i++) {
      // Rondas de coluna
      w[0]=(w[0]+w[4])&0xFFFFFFFF; w[12]^=w[0]; w[12]=_rotl(w[12],16); w[8]=(w[8]+w[12])&0xFFFFFFFF; w[4]^=w[8]; w[4]=_rotl(w[4],12);
      w[0]=(w[0]+w[4])&0xFFFFFFFF; w[12]^=w[0]; w[12]=_rotl(w[12],8);  w[8]=(w[8]+w[12])&0xFFFFFFFF; w[4]^=w[8]; w[4]=_rotl(w[4],7);

      w[1]=(w[1]+w[5])&0xFFFFFFFF; w[13]^=w[1]; w[13]=_rotl(w[13],16); w[9]=(w[9]+w[13])&0xFFFFFFFF; w[5]^=w[9]; w[5]=_rotl(w[5],12);
      w[1]=(w[1]+w[5])&0xFFFFFFFF; w[13]^=w[1]; w[13]=_rotl(w[13],8);  w[9]=(w[9]+w[13])&0xFFFFFFFF; w[5]^=w[9]; w[5]=_rotl(w[5],7);

      w[2]=(w[2]+w[6])&0xFFFFFFFF; w[14]^=w[2]; w[14]=_rotl(w[14],16); w[10]=(w[10]+w[14])&0xFFFFFFFF; w[6]^=w[10]; w[6]=_rotl(w[6],12);
      w[2]=(w[2]+w[6])&0xFFFFFFFF; w[14]^=w[2]; w[14]=_rotl(w[14],8);  w[10]=(w[10]+w[14])&0xFFFFFFFF; w[6]^=w[10]; w[6]=_rotl(w[6],7);

      w[3]=(w[3]+w[7])&0xFFFFFFFF; w[15]^=w[3]; w[15]=_rotl(w[15],16); w[11]=(w[11]+w[15])&0xFFFFFFFF; w[7]^=w[11]; w[7]=_rotl(w[7],12);
      w[3]=(w[3]+w[7])&0xFFFFFFFF; w[15]^=w[3]; w[15]=_rotl(w[15],8);  w[11]=(w[11]+w[15])&0xFFFFFFFF; w[7]^=w[11]; w[7]=_rotl(w[7],7);

      // Rondas diagonais — ORDEM CORRIGIDA (v9.1): w[0]+w[5], w[1]+w[6], w[2]+w[7], w[3]+w[4]
      w[0]=(w[0]+w[5])&0xFFFFFFFF; w[15]^=w[0]; w[15]=_rotl(w[15],16); w[10]=(w[10]+w[15])&0xFFFFFFFF; w[5]^=w[10]; w[5]=_rotl(w[5],12);
      w[0]=(w[0]+w[5])&0xFFFFFFFF; w[15]^=w[0]; w[15]=_rotl(w[15],8);  w[10]=(w[10]+w[15])&0xFFFFFFFF; w[5]^=w[10]; w[5]=_rotl(w[5],7);

      w[1]=(w[1]+w[6])&0xFFFFFFFF; w[12]^=w[1]; w[12]=_rotl(w[12],16); w[11]=(w[11]+w[12])&0xFFFFFFFF; w[6]^=w[11]; w[6]=_rotl(w[6],12);
      w[1]=(w[1]+w[6])&0xFFFFFFFF; w[12]^=w[1]; w[12]=_rotl(w[12],8);  w[11]=(w[11]+w[12])&0xFFFFFFFF; w[6]^=w[11]; w[6]=_rotl(w[6],7);

      w[2]=(w[2]+w[7])&0xFFFFFFFF; w[13]^=w[2]; w[13]=_rotl(w[13],16); w[8]=(w[8]+w[13])&0xFFFFFFFF; w[7]^=w[8]; w[7]=_rotl(w[7],12);
      w[2]=(w[2]+w[7])&0xFFFFFFFF; w[13]^=w[2]; w[13]=_rotl(w[13],8);  w[8]=(w[8]+w[13])&0xFFFFFFFF; w[7]^=w[8]; w[7]=_rotl(w[7],7);

      w[3]=(w[3]+w[4])&0xFFFFFFFF; w[14]^=w[3]; w[14]=_rotl(w[14],16); w[9]=(w[9]+w[14])&0xFFFFFFFF; w[4]^=w[9]; w[4]=_rotl(w[4],12);
      w[3]=(w[3]+w[4])&0xFFFFFFFF; w[14]^=w[3]; w[14]=_rotl(w[14],8);  w[9]=(w[9]+w[14])&0xFFFFFFFF; w[4]^=w[9]; w[4]=_rotl(w[4],7);
    }

    w[0]=(w[0]+s0)&0xFFFFFFFF;  w[1]=(w[1]+s1)&0xFFFFFFFF;  w[2]=(w[2]+s2)&0xFFFFFFFF;  w[3]=(w[3]+s3)&0xFFFFFFFF;
    w[4]=(w[4]+s4)&0xFFFFFFFF;  w[5]=(w[5]+s5)&0xFFFFFFFF;  w[6]=(w[6]+s6)&0xFFFFFFFF;  w[7]=(w[7]+s7)&0xFFFFFFFF;
    w[8]=(w[8]+s8)&0xFFFFFFFF;  w[9]=(w[9]+s9)&0xFFFFFFFF;  w[10]=(w[10]+s10)&0xFFFFFFFF;w[11]=(w[11]+s11)&0xFFFFFFFF;
    w[12]=(w[12]+s12)&0xFFFFFFFF;w[13]=(w[13]+s13)&0xFFFFFFFF;w[14]=(w[14]+s14)&0xFFFFFFFF;w[15]=(w[15]+s15)&0xFFFFFFFF;

    final ks = Uint8List(64);
    final dv = ByteData.sublistView(ks);
    for (int i = 0; i < 16; i++) {
      dv.setUint32(i * 4, w[i], Endian.little);
    }
    return ks;
  }

  /// Decripta um único chunk de ciphertext com a chave e nonce dados.
  /// Contador começa em 1 (igual ao worker JS: `let ctr = 1`).
  static Uint8List decryptChunk(Uint8List cipher, Uint8List key, Uint8List nonce) {
    final out = Uint8List(cipher.length);
    int off = 0;
    int ctr = 1;
    while (off < cipher.length) {
      final ks = _block(key, ctr++, nonce);
      final n = (cipher.length - off) < 64 ? (cipher.length - off) : 64;
      for (int i = 0; i < n; i++) {
        out[off + i] = cipher[off + i] ^ ks[i];
      }
      off += n;
    }
    return out;
  }

  /// Faz o parsing e decriptação de um segmento .bin completo (protocolo
  /// chunk-v2), devolvendo o fMP4 plaintext concatenado — pronto para
  /// escrever em disco ou servir via proxy HTTP local.
  static Uint8List decryptSegment(Uint8List raw, String keyHex) {
    final key = hexToBytes(keyHex);
    if (raw.length < 4) return Uint8List(0);

    final bd = ByteData.sublistView(raw);
    final nChunks = bd.getUint32(0, Endian.little);
    if (nChunks == 0 || nChunks >= 100000) return Uint8List(0);

    final chunks = <Uint8List>[];
    int pos = 4;
    for (int c = 0; c < nChunks; c++) {
      if (pos + 16 > raw.length) break;
      final nonce = raw.sublist(pos, pos + 12);
      final chunkLen = ByteData.sublistView(raw, pos + 12, pos + 16).getUint32(0, Endian.little);
      pos += 16;
      if (pos + chunkLen > raw.length) break;
      final cipher = raw.sublist(pos, pos + chunkLen);
      pos += chunkLen;
      chunks.add(decryptChunk(cipher, key, nonce));
    }

    final total = chunks.fold<int>(0, (a, b) => a + b.length);
    final out = Uint8List(total);
    int o = 0;
    for (final c in chunks) {
      out.setRange(o, o + c.length, c);
      o += c.length;
    }
    return out;
  }
}
