import 'api.dart';

/// Katalog (markalar, hizmetler) ve il/ilçe listesi: siteden bir kez alınıp uygulama açık kaldıkça saklanır.
class Marka {
  Marka(this.kod, this.ad, this.koken, this.modeller);
  final String kod, ad, koken;
  final List<String> modeller;
}

class Is {
  Is(this.kod, this.ad);
  final String kod, ad;
}

class HizmetGrubu {
  HizmetGrubu(this.kod, this.ad, this.ornek, this.isler);
  final String kod, ad, ornek;
  final List<Is> isler;
}

/// Ustanın girdiği araç durumu (iş takibi): teslim alındı → … → teslim edildi.
class IsDurumu {
  IsDurumu(this.kod, this.ad, this.kisa, this.aciklama);
  final String kod, ad, kisa, aciklama;
}

/// Araç hatırlatıcısı türü (muayene, sigorta, kasko, bakım, lastik).
class HatirlaticiTuru {
  HatirlaticiTuru(this.tur, this.ad, this.ipucu, this.hizmet, this.oneri);
  final String tur, ad, ipucu, oneri;
  final String? hizmet;
}

class Katalog {
  Katalog._(this.markalar, this.hizmetler, this.yakitlar, this.iller, this.isDurumlari, this.hatirlaticiTurleri);
  final List<Marka> markalar;
  final List<HizmetGrubu> hizmetler;
  final List<String> yakitlar;
  /// İl → ilçeler (alfabetik).
  final Map<String, List<String>> iller;
  final List<IsDurumu> isDurumlari;
  final List<HatirlaticiTuru> hatirlaticiTurleri;

  static Katalog? _onbellek;

  static Future<Katalog> al() async {
    if (_onbellek != null) return _onbellek!;
    final sonuc = await Future.wait([Api.ben.veri('katalog'), Api.ben.veri('iller')]);
    final k = sonuc[0], i = sonuc[1];
    final markalar = [
      for (final m in k['markalar'] as List) Marka(m['kod'], m['ad'], m['koken'], [for (final x in m['modeller'] as List) '$x']),
    ]..sort((a, b) => a.ad.toLowerCase().compareTo(b.ad.toLowerCase()));
    final hizmetler = [
      for (final g in k['hizmetler'] as List)
        HizmetGrubu(g['kod'], g['ad'], g['ornek'] ?? '', [for (final x in g['isler'] as List) Is(x['kod'], x['ad'])]),
    ];
    final iller = {for (final x in i['iller'] as List) x['il'] as String: [for (final y in x['ilceler'] as List) '$y']};
    final durumlar = [for (final d in (k['isDurumlari'] as List? ?? const [])) IsDurumu(d['kod'], d['ad'], d['kisa'], d['aciklama'])];
    final turler = [
      for (final h in (k['hatirlaticiTurleri'] as List? ?? const [])) HatirlaticiTuru(h['tur'], h['ad'], h['ipucu'], h['hizmet'] as String?, h['oneri']),
    ];
    return _onbellek = Katalog._(markalar, hizmetler, [for (final y in k['yakitlar'] as List) '$y'], iller, durumlar, turler);
  }

  String markaAdi(String kod) => markalar.where((m) => m.kod == kod).firstOrNull?.ad ?? kod;

  /// İş ya da grup kodundan okunur ad.
  String hizmetAdi(String kod) {
    for (final g in hizmetler) {
      if (g.kod == kod) return g.ad;
      for (final i in g.isler) {
        if (i.kod == kod) return i.ad;
      }
    }
    return kod;
  }

  IsDurumu? isDurumu(String? kod) => isDurumlari.where((d) => d.kod == kod).firstOrNull;
  HatirlaticiTuru? hatirlatici(String tur) => hatirlaticiTurleri.where((h) => h.tur == tur).firstOrNull;

  HizmetGrubu? grubuBul(String kod) =>
      hizmetler.where((g) => g.kod == kod || g.isler.any((i) => i.kod == kod)).firstOrNull;
}
