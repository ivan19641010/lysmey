import 'dart:typed_data';

class DecoderService {
  static const int cdLen8 = 8;
  static const int cdLen6 = 6;
  static const int cdShift = 13;
  static const int shifts = 5;

  static const List<int> _passW = [129, 96, 113, 171, 215, 23];
  static const String _chars =
      '3srXzDbFBdg^&5apJ1YvEWSyU@Cho4Qw9Z!7TA6Ktgf8j0Vx2uL#RPMq%mkHNiNc';

  /// Декодирует имя устройства (8 символов) в число.
  /// Возвращает 0, если декодирование не удалось или контрольная сумма не совпала.
  static int decodeInt(String str) {
    if (str.length != cdLen8) return 0;

    Uint8List arr = Uint8List(cdLen6);

    // 1. Начальное заполнение массива на основе символов
    for (int i = 0; i < cdLen8; i++) {
      int fou = _chars.indexOf(str[i]);
      if (fou == -1) return 0;

      arr[0] = (arr[0] + fou) & 0xFF;
      _cdRight(arr, 6);
    }

    // 2. Цикл перемешивания и XOR
    for (int i = 0; i < cdShift; i++) {
      _cdRight(arr, shifts);
      _cdXor(arr);
    }

    // 3. Извлечение цифр и проверка контрольной суммы
    int result = 0;
    int sum = 0;

    // Проходим по первым 5 байтам (индексы 0-4)
    for (int i = cdLen6 - 2; i >= 0; i--) {
      int highNibble = arr[i] >> 4;
      sum += highNibble;
      result = result * 10 + highNibble;

      int lowNibble = arr[i] & 0x0F;
      sum += lowNibble;
      result = result * 10 + lowNibble;
    }

    // Последний байт (индекс 5) — контрольная сумма
    int checksumByte = ((arr[5] >> 4) * 10) + (arr[5] & 0x0F);
    
    if (checksumByte != sum) {
      return 0;
    }

    return result;
  }

  static void _cdXor(Uint8List res) {
    for (int i = 0; i < cdLen6; i++) {
      res[i] = res[i] ^ _passW[i];
    }
  }

  static void _cdRight(Uint8List res, int num) {
    for (int r = 0; r < num; r++) {
      int old = 0;
      // В Pascal цикл шел от 6 до 1 (downto)
      // В Dart это от 5 до 0
      for (int i = 5; i >= 0; i--) {
        int carry = res[i] & 1;
        res[i] = (res[i] >> 1) | (old << 7);
        old = carry;
      }
      // После цикла в Pascal: res[6] := res[6] + old * 128
      // В Dart это значит, что самый первый бит, который выпал из res[0], 
      // заходит в старший бит res[5]
      res[5] = res[5] | (old << 7);
    }
  }
}
