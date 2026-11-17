/// Soru ağacında yürüme (sitedeki src/lib/dert-agaci.ts > dertAdimi ile aynı kural). Ağaç sunucudan gelir
/// (/api/m/veri/dert-agaci); burada yalnız verilen cevaplara göre hangi sorunun ya da sonucun geldiği hesaplanır.
library;

class DertAdimi {
  DertAdimi(this.gecmis, this.soruKodu, this.soru, this.sonuc);

  /// (soru, verilen cevap) çiftleri.
  final List<(String, String)> gecmis;
  final String? soruKodu;
  final Map<String, dynamic>? soru;
  final Map<String, dynamic>? sonuc;
}

/// Cevap kodlarını ağaçta yürür; geçersiz yolda null.
DertAdimi? dertAdimi(Map<String, dynamic> agac, List<String> yol) {
  var dugum = 'kok';
  final gecmis = <(String, String)>[];
  for (var i = 0; i < yol.length; i++) {
    final soru = agac[dugum] as Map<String, dynamic>?;
    if (soru == null) return null;
    final secim = (soru['secenekler'] as List).cast<Map<String, dynamic>>().where((x) => x['kod'] == yol[i]).firstOrNull;
    if (secim == null) return null;
    gecmis.add((soru['soru'] as String, secim['etiket'] as String));
    if (secim['sonuc'] != null) return i == yol.length - 1 ? DertAdimi(gecmis, null, null, Map<String, dynamic>.from(secim['sonuc'])) : null;
    dugum = secim['sonraki'] as String;
  }
  final soru = agac[dugum] as Map<String, dynamic>?;
  return soru == null ? null : DertAdimi(gecmis, dugum, soru, null);
}

/// Ustaya ve teklif talebine gidecek kısa özet: kişinin sözleri ve ağaçta verdiği cevaplar.
String dertOzeti(DertAdimi adim, String? metin) {
  final cevaplar = adim.gecmis.map((g) => g.$2.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ').trim()).join(' → ');
  return [if (metin != null && metin.trim().isNotEmpty) metin.trim(), if (cevaplar.isNotEmpty) 'Soru ağacındaki cevaplarım: $cevaplar.'].join('\n');
}
