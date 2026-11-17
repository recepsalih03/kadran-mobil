/// Türkçe tarih ve saat yazımı (sitedeki zaman.ts ile aynı dil). Tarihler "2026-11-18" biçiminde gelir.
library;

const _gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const _gunlerKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

DateTime _tarih(String iso) => DateTime.utc(int.parse(iso.substring(0, 4)), int.parse(iso.substring(5, 7)), int.parse(iso.substring(8, 10)));

/// Türkiye saatiyle bugün (UTC+3, yaz saati yok).
String bugunIso() {
  final t = DateTime.now().toUtc().add(const Duration(hours: 3));
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

String gunEkle(String iso, int n) {
  final t = _tarih(iso).add(Duration(days: n));
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

String gunAdi(String iso) => _gunler[_tarih(iso).weekday - 1];
String gunAdiKisa(String iso) => _gunlerKisa[_tarih(iso).weekday - 1];

/// "Bugün", "Yarın" ya da gün adı.
String gunEtiketi(String iso) {
  final b = bugunIso();
  if (iso == b) return 'Bugün';
  if (iso == gunEkle(b, 1)) return 'Yarın';
  return gunAdi(iso);
}

/// "18 Kasım"
String tarihKisa(String iso) {
  final t = _tarih(iso);
  return '${t.day} ${_aylar[t.month - 1]}';
}

/// "Yarın, 18 Kasım" / "Cuma, 21 Kasım"
String gunVeTarih(String iso) => '${gunEtiketi(iso)}, ${tarihKisa(iso)}';

/// "4,9"
String ondalik(num s, [int basamak = 1]) => s.toStringAsFixed(basamak).replaceAll('.', ',');

/// "90" → "1,5 saat", "45" → "45 dakika"
String sureYaz(int dk) => dk < 60 ? '$dk dakika' : '${ondalik(dk / 60, dk % 60 == 0 ? 0 : 1)} saat';

/// "0555 123 45 67" (10 haneli numaradan)
String telefonYaz(String t) {
  final d = t.replaceAll(RegExp(r'\D'), '');
  if (d.length != 10) return t;
  return '0${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6, 8)} ${d.substring(8)}';
}

/// Plaka satır sonunda bölünmesin ("34 ABC 123" tek parça kalır).
String plaka(String p) => p.replaceAll(' ', ' ');
