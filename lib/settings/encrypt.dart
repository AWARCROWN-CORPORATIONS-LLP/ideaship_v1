import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoHelper {
  static final _key = encrypt.Key.fromUtf8('1234567890123456');
  static final _iv  = encrypt.IV.fromUtf8('6543210987654321');  

  static String encryptText(String plainText) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        _key,
        mode: encrypt.AESMode.cbc,   
        padding: 'PKCS7',            
      ),
    );

    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64; 
  }
}
