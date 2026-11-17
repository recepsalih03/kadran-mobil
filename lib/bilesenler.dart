import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'tema.dart';

/* Ortak parçalar: sitedeki bileşenlerin (yapi.tsx, parcalar.tsx, form.tsx, secim-kutusu.tsx) uygulamadaki karşılıkları.
   Dokunma alanları en az 48 px, gövde yazısı 17 px, seçili durum turuncu kenar + onay işareti. */

/// Üst şerit: lacivert, solda KADRAN logosu. İç sayfada geri oku da çıkar.
PreferredSizeWidget ustSerit(BuildContext context, {List<Widget>? eylemler}) => AppBar(
      toolbarHeight: 60,
      title: Image.asset('assets/resim/logo-beyaz.png', height: 22, semanticLabel: 'Kadran'),
      actions: eylemler,
    );

/// Sayfa başlığı: büyük başlık ve altında kısa açıklama (sitedeki Konum).
class Konum extends StatelessWidget {
  const Konum({super.key, required this.baslik, this.aciklama, this.sag});
  final String baslik;
  final String? aciklama;
  final Widget? sag;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(baslik, style: Yazi.baslik),
              if (aciklama != null) ...[const SizedBox(height: 4), Text(aciklama!, style: Yazi.ikincil.copyWith(fontSize: 17))],
            ]),
          ),
          ?sag,
        ]),
      );
}

/// Bölüm başlığı.
class Bolum extends StatelessWidget {
  const Bolum({super.key, required this.baslik, this.aciklama, required this.child});
  final String baslik;
  final String? aciklama;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: Yazi.bolum),
          if (aciklama != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(aciklama!, style: Yazi.ikincil)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

/// Açık gri kutu (grup kutusu, panel).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.dolgu = const EdgeInsets.all(16), this.renk = Renk.bant});
  final Widget child;
  final EdgeInsets dolgu;
  final Color renk;
  @override
  Widget build(BuildContext context) =>
      Container(width: double.infinity, padding: dolgu, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(Kose.panel)), child: child);
}

/// Satırlar: gri kutu içinde ince çizgiyle ayrılmış liste.
class Satirlar extends StatelessWidget {
  const Satirlar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(Kose.panel),
        child: Material(
          color: Renk.bant,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(), children[i]],
          ]),
        ),
      );
}

/// Liste satırı: solda isteğe bağlı büyük değer (saat), ortada başlık ve ayrıntı, sağda ok.
class Satir extends StatelessWidget {
  const Satir({super.key, this.sol, required this.baslik, this.ayrinti, this.alt, this.onTap, this.ok = true});
  final Widget? sol;
  final String baslik;
  final String? ayrinti;
  final Widget? alt;
  final VoidCallback? onTap;
  final bool ok;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (sol != null) ...[sol!, const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(baslik, style: Yazi.govdeKalin),
                  if (ayrinti != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(ayrinti!, style: Yazi.ikincil)),
                  if (alt != null) Padding(padding: const EdgeInsets.only(top: 6), child: alt!),
                ]),
              ),
              if (onTap != null && ok) const Padding(padding: EdgeInsets.only(top: 2, left: 8), child: Icon(Icons.chevron_right, color: Renk.murekkep2)),
            ]),
          ),
        ),
      );
}

/// Büyük saat yazısı (liste satırının solu).
class BuyukSaat extends StatelessWidget {
  const BuyukSaat(this.saat, {super.key, this.boy = 26});
  final String saat;
  final double boy;
  @override
  Widget build(BuildContext context) => SizedBox(width: boy * 3.2, child: Text(saat, style: Yazi.rakam.copyWith(fontSize: boy, height: 1)));
}

enum UyariTuru { basari, bilgi, hata }

/// Uyarı kutusu: başarı (yeşil), bilgi (gri), hata (kırmızı); simge + başlık + açıklama.
class Uyari extends StatelessWidget {
  const Uyari({super.key, required this.tur, required this.baslik, this.metin});
  final UyariTuru tur;
  final String baslik;
  final String? metin;
  @override
  Widget build(BuildContext context) {
    final (zemin, yazi, simge) = switch (tur) {
      UyariTuru.basari => (Renk.okZemin, Renk.ok, Icons.check_circle_outline),
      UyariTuru.bilgi => (Renk.bant, Renk.lacivert, Icons.info_outline),
      UyariTuru.hata => (Renk.hayirZemin, Renk.hayir, Icons.error_outline),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(Kose.orta)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(simge, color: yazi, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(baslik, style: Yazi.govdeKalin.copyWith(color: yazi)),
              if (metin != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(metin!, style: Yazi.govde.copyWith(color: yazi, fontSize: 16))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Form alanı: etiket + kutu + ipucu ya da hata ("ne oldu + ne yapmalı").
class Alan extends StatelessWidget {
  const Alan({super.key, required this.etiket, this.ipucu, this.hata, required this.child});
  final String etiket;
  final String? ipucu;
  final String? hata;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: Yazi.govde.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
        if (hata != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, size: 20, color: Renk.hayir),
              const SizedBox(width: 6),
              Expanded(child: Text(hata!, style: Yazi.govde.copyWith(color: Renk.hayir, fontWeight: FontWeight.w500))),
            ]),
          )
        else if (ipucu != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(ipucu!, style: Yazi.ikincil)),
      ]);
}

/// Metin kutusu (17 px, 1,5 px gri kenar). Hata varsa kenar kırmızı.
class MetinKutusu extends StatelessWidget {
  const MetinKutusu({super.key, required this.kontrol, this.hata = false, this.klavye, this.gizli = false, this.satir = 1, this.ipucu, this.otomatik});
  final TextEditingController kontrol;
  final bool hata;
  final TextInputType? klavye;
  final bool gizli;
  final int satir;
  final String? ipucu;
  final Iterable<String>? otomatik;
  @override
  Widget build(BuildContext context) => TextField(
        controller: kontrol,
        keyboardType: klavye,
        obscureText: gizli,
        minLines: satir,
        maxLines: gizli ? 1 : satir,
        autofillHints: otomatik,
        style: Yazi.govde,
        decoration: InputDecoration(
          hintText: ipucu,
          enabledBorder: hata
              ? OutlineInputBorder(borderRadius: BorderRadius.circular(Kose.orta), borderSide: const BorderSide(color: Renk.hayir, width: 2))
              : null,
        ),
      );
}

/// Seçim seçeneği ve grubu.
class Secenek {
  const Secenek(this.deger, this.etiket, {this.alt});
  final String deger, etiket;
  final String? alt;
}

class SecenekGrubu {
  const SecenekGrubu(this.secenekler, {this.baslik});
  final String? baslik;
  final List<Secenek> secenekler;
}

/// Seçim kutusu: dokununca tam ekran seçim sayfası açılır (12'den uzun listede arama kutusu).
/// Sitedeki "fis" görünümü: solda simge, üstte küçük etiket, ortada seçili değer, sağda "Değiştir".
class SecimKutusu extends StatelessWidget {
  const SecimKutusu({super.key, required this.etiket, required this.gruplar, this.deger, required this.onSec, this.simge, this.bos = 'Seç', this.hata = false, this.baslik});
  final String etiket;
  final String? baslik;
  final List<SecenekGrubu> gruplar;
  final String? deger;
  final ValueChanged<String> onSec;
  final IconData? simge;
  final String bos;
  final bool hata;

  @override
  Widget build(BuildContext context) {
    final secili = gruplar.expand((g) => g.secenekler).where((s) => s.deger == deger).firstOrNull;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Kose.orta),
        side: BorderSide(color: hata ? Renk.hayir : Renk.alan, width: hata ? 2 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Kose.orta),
        onTap: () async {
          final s = await secimSayfasi(context, baslik: baslik ?? etiket, gruplar: gruplar, deger: deger);
          if (s != null) onSec(s);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(children: [
              if (simge != null) ...[Icon(simge, color: Renk.murekkep2, size: 24), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(etiket, style: Yazi.ikincil.copyWith(height: 1.2)),
                  const SizedBox(height: 2),
                  Text(secili?.etiket ?? bos,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Yazi.govdeKalin.copyWith(color: secili == null ? Renk.murekkep2 : Renk.lacivert)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                decoration: BoxDecoration(color: Renk.bant, borderRadius: BorderRadius.circular(99)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Değiştir', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  Icon(Icons.expand_more, size: 20),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Aramada Türkçe harf farkını yok say: "sanziman" "Şanzıman"ı bulur.
String _sade(String s) => s
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('İ', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll('Ş', 's')
    .replaceAll('Ğ', 'g')
    .replaceAll('Ü', 'u')
    .replaceAll('Ö', 'o')
    .replaceAll('Ç', 'c');

/// Tam ekran seçim sayfası. Seçilen değeri döndürür (kapatılırsa null).
Future<String?> secimSayfasi(BuildContext context, {required String baslik, required List<SecenekGrubu> gruplar, String? deger, bool? arama}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Kose.pano))),
    builder: (_) => _SecimSayfasi(baslik: baslik, gruplar: gruplar, deger: deger, arama: arama ?? gruplar.expand((g) => g.secenekler).length > 12),
  );
}

class _SecimSayfasi extends StatefulWidget {
  const _SecimSayfasi({required this.baslik, required this.gruplar, required this.deger, required this.arama});
  final String baslik;
  final List<SecenekGrubu> gruplar;
  final String? deger;
  final bool arama;
  @override
  State<_SecimSayfasi> createState() => _SecimSayfasiState();
}

class _SecimSayfasiState extends State<_SecimSayfasi> {
  String _ara = '';
  @override
  Widget build(BuildContext context) {
    final aranan = _sade(_ara.trim());
    final gorunen = [
      for (final g in widget.gruplar)
        SecenekGrubu([for (final s in g.secenekler) if (aranan.isEmpty || _sade('${s.etiket} ${s.alt ?? ''}').contains(aranan)) s], baslik: g.baslik),
    ].where((g) => g.secenekler.isNotEmpty).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            Expanded(child: Text(widget.baslik, style: Yazi.bolum)),
            OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20), label: const Text('Kapat')),
          ]),
        ),
        if (widget.arama)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _ara = v),
              style: Yazi.govde,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Yazarak ara'),
            ),
          ),
        const Divider(),
        Expanded(
          child: gorunen.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('“${_ara.trim()}” bulunamadı. Yazdığını kontrol et ya da listeden seç.', style: Yazi.govde),
                )
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  for (final g in gorunen) ...[
                    if (g.baslik != null) Padding(padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4), child: Text(g.baslik!, style: Yazi.ikincil.copyWith(fontWeight: FontWeight.w600))),
                    Satirlar(children: [
                      for (final s in g.secenekler)
                        _SecimSatiri(secenek: s, secili: s.deger == widget.deger, onTap: () => Navigator.pop(context, s.deger)),
                    ]),
                    const SizedBox(height: 8),
                  ],
                ]),
        ),
      ]),
    );
  }
}

class _SecimSatiri extends StatelessWidget {
  const _SecimSatiri({required this.secenek, required this.secili, required this.onTap});
  final Secenek secenek;
  final bool secili;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: secili ? Renk.seciliZemin : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(secenek.etiket, style: Yazi.govde.copyWith(fontWeight: secili ? FontWeight.w600 : FontWeight.w500)),
                    if (secenek.alt != null) Text(secenek.alt!, style: Yazi.ikincil),
                  ]),
                ),
                if (secili) const Icon(Icons.check_circle, color: Renk.secili),
              ]),
            ),
          ),
        ),
      );
}

/// Seçim düğmesi (saat, gün, yıldız gibi kısa değerler): seçiliyken turuncu kenar ve açık turuncu zemin.
class SecimDugmesi extends StatelessWidget {
  const SecimDugmesi({super.key, required this.secili, required this.onTap, required this.child, this.yukseklik = 54});
  final bool secili;
  final VoidCallback? onTap;
  final Widget child;
  final double yukseklik;
  @override
  Widget build(BuildContext context) => Semantics(
        selected: secili,
        button: true,
        child: Material(
          color: secili ? Renk.seciliZemin : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Kose.orta),
            side: BorderSide(color: secili ? Renk.secili : Renk.alan, width: secili ? 2.5 : 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Kose.orta),
            onTap: onTap,
            child: SizedBox(height: yukseklik, child: Center(child: child)),
          ),
        ),
      );
}

/// Saat ızgarası: üç sütun, büyük rakam.
class SaatIzgarasi extends StatelessWidget {
  const SaatIzgarasi({super.key, required this.saatler, required this.secili, required this.onSec});
  final List<String> saatler;
  final String? secili;
  final ValueChanged<String> onSec;
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.1,
        children: [
          for (final s in saatler)
            SecimDugmesi(secili: s == secili, onTap: () => onSec(s), child: Text(s, style: Yazi.rakam.copyWith(fontSize: 21))),
        ],
      );
}

/// Gün sekmeleri: "Bugün · 18 Kas · 6 boş".
class GunSekmeleri extends StatelessWidget {
  const GunSekmeleri({super.key, required this.gunler, required this.secili, required this.onSec, this.alt});
  final List<String> gunler;
  final String secili;
  final ValueChanged<String> onSec;
  final String Function(String gun)? alt;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < gunler.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: SecimDugmesi(
              secili: gunler[i] == secili,
              yukseklik: 64,
              onTap: () => onSec(gunler[i]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_gunKisa(gunler[i]), style: Yazi.govdeKalin.copyWith(fontSize: 16)),
                if (alt != null) Text(alt!(gunler[i]), style: Yazi.kucuk.copyWith(fontSize: 13), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ],
      ]);
}

String _gunKisa(String iso) {
  // Sekmede kısa ad: Bugün, Yarın, Cuma.
  final t = DateTime.utc(int.parse(iso.substring(0, 4)), int.parse(iso.substring(5, 7)), int.parse(iso.substring(8, 10)));
  final simdi = DateTime.now().toUtc().add(const Duration(hours: 3));
  final bugun = DateTime.utc(simdi.year, simdi.month, simdi.day);
  final fark = t.difference(bugun).inDays;
  if (fark == 0) return 'Bugün';
  if (fark == 1) return 'Yarın';
  return const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][t.weekday - 1];
}

/// Randevu durum rozeti: renk + simge + yazı (turuncu hiçbir durumda kullanılmaz).
class DurumRozeti extends StatelessWidget {
  const DurumRozeti(this.durum, {super.key});
  final String durum;
  @override
  Widget build(BuildContext context) {
    final (zemin, yazi, simge, etiket) = switch (durum) {
      'bekliyor' => (Renk.bekleZemin, Renk.bekle, Icons.schedule, 'Onay bekliyor'),
      'onaylandi' => (Renk.okZemin, Renk.ok, Icons.check, 'Onaylandı'),
      'reddedildi' => (Renk.hayirZemin, Renk.hayir, Icons.close, 'Reddedildi'),
      'iptal' => (Renk.gectiZemin, Renk.gecti, Icons.remove, 'İptal edildi'),
      'tamamlandi' => (Renk.gectiZemin, Renk.gecti, Icons.done_all, 'Tamamlandı'),
      'gelmedi' => (Renk.gectiZemin, Renk.gecti, Icons.remove, 'Gelmedi'),
      _ => (Renk.bant, Renk.lacivert, Icons.info_outline, durum),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(simge, size: 16, color: yazi),
        const SizedBox(width: 4),
        Text(etiket, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: yazi)),
      ]),
    );
  }
}

/// Yıldızlar (lacivert) ve puan satırı: "★★★★★ 4,9 (212 değerlendirme)".
class PuanSatiri extends StatelessWidget {
  const PuanSatiri({super.key, required this.puan, required this.sayi});
  final num puan;
  final int sayi;
  @override
  Widget build(BuildContext context) {
    if (sayi == 0) return Text('Henüz değerlendirme yok', style: Yazi.ikincil);
    // Dar ekranda "(212 değerlendirme)" alt satıra kayar, taşmaz.
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (var i = 1; i <= 5; i++)
        Icon(puan >= i - 0.25 ? Icons.star : (puan >= i - 0.75 ? Icons.star_half : Icons.star_border), size: 18, color: Renk.lacivert),
      const SizedBox(width: 6),
      Text(puan.toStringAsFixed(1).replaceAll('.', ','), style: Yazi.rakam.copyWith(fontSize: 16)),
      Text(' ($sayi değerlendirme)', style: Yazi.ikincil),
    ]);
  }
}

/// Boş ekran: başlık, açıklama, isteğe bağlı tek düğme.
class BosEkran extends StatelessWidget {
  const BosEkran({super.key, required this.baslik, required this.aciklama, this.eylem, this.onEylem});
  final String baslik, aciklama;
  final String? eylem;
  final VoidCallback? onEylem;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Panel(
          dolgu: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(baslik, style: Yazi.bolum.copyWith(fontSize: 21)),
            const SizedBox(height: 6),
            Text(aciklama, style: Yazi.govde),
            if (eylem != null) ...[
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onEylem, child: Text(eylem!))),
            ],
          ]),
        ),
      );
}

/// Yükleme iskeleti: gri bloklar yavaşça soluklaşıp koyulaşır (sitedeki iskeletin aynısı; dönen halka yok).
class Iskelet extends StatefulWidget {
  const Iskelet({super.key, this.satir = 5, this.baslik = true});
  final int satir;
  final bool baslik;
  @override
  State<Iskelet> createState() => _IskeletState();
}

class _IskeletState extends State<Iskelet> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _blok(double w, double h, {Color renk = Renk.bant2, double r = Kose.kucuk}) =>
      Container(width: w, height: h, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(r)));

  @override
  Widget build(BuildContext context) {
    final azalt = MediaQuery.of(context).disableAnimations;
    final icerik = Semantics(
      label: 'Sayfa yükleniyor',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.baslik) ...[const SizedBox(height: 18), _blok(220, 34), const SizedBox(height: 10), _blok(280, 18), const SizedBox(height: 20)],
          ClipRRect(
            borderRadius: BorderRadius.circular(Kose.panel),
            child: Container(
              color: Renk.bant,
              child: Column(children: [
                for (var i = 0; i < widget.satir; i++)
                  Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: Renk.cizgi))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _blok(70, 26, renk: Renk.cizgi.withValues(alpha: 0.7)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          FractionallySizedBox(widthFactor: i.isEven ? 0.5 : 0.4, child: _blok(double.infinity, 18, renk: Renk.cizgi.withValues(alpha: 0.7))),
                          const SizedBox(height: 8),
                          FractionallySizedBox(widthFactor: 0.7, child: _blok(double.infinity, 14, renk: Renk.cizgi.withValues(alpha: 0.7))),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
    if (azalt) return icerik;
    return FadeTransition(opacity: Tween(begin: 1.0, end: 0.5).animate(_a), child: icerik);
  }
}

/// Bir ekranın verisini yükler: yüklenirken iskelet, hata olursa "Yeniden dene", aşağı çekince yenileme.
/// [yenileme] verilirse açıkken o aralıkta sessizce yenilenir (yeni mesaj, yeni talep).
class VeriEkrani<T> extends StatefulWidget {
  const VeriEkrani({super.key, required this.yukle, required this.icerik, this.yenileme, this.iskelet = const Iskelet()});
  final Future<T> Function() yukle;
  final Widget Function(BuildContext context, T veri, Future<void> Function() yenile) icerik;
  final Duration? yenileme;
  final Widget iskelet;
  @override
  State<VeriEkrani<T>> createState() => VeriEkraniState<T>();
}

class VeriEkraniState<T> extends State<VeriEkrani<T>> {
  T? _veri;
  String? _hata;
  bool _yukleniyor = true;
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    yenile();
    if (widget.yenileme != null) _zamanlayici = Timer.periodic(widget.yenileme!, (_) => yenile(sessiz: true));
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  Future<void> yenile({bool sessiz = false}) async {
    if (!sessiz && _veri == null) setState(() => _yukleniyor = true);
    try {
      final v = await widget.yukle();
      if (!mounted) return;
      setState(() {
        _veri = v;
        _hata = null;
        _yukleniyor = false;
      });
    } on ApiHatasi catch (e) {
      if (!mounted || sessiz) return;
      setState(() {
        _hata = e.mesaj;
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor && _veri == null) return widget.iskelet;
    if (_hata != null && _veri == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 16),
        Uyari(tur: UyariTuru.hata, baslik: 'Sayfa açılamadı.', metin: _hata),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () => yenile(), child: const Text('Yeniden dene')),
      ]);
    }
    return RefreshIndicator(onRefresh: yenile, color: Renk.lacivert, child: widget.icerik(context, _veri as T, yenile));
  }
}

/// Kaydırılabilir sayfa gövdesi (16 px yan boşluk, altta gezinme çubuğuna yer).
class Sayfa extends StatelessWidget {
  const Sayfa({super.key, required this.children, this.alt = 32});
  final List<Widget> children;
  final double alt;
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 0, 16, alt),
        children: children,
      );
}

/// Ana düğme: gönderilirken "Bekle…" yazar ve kapanır.
class AnaDugme extends StatelessWidget {
  const AnaDugme({super.key, required this.etiket, required this.onPressed, this.bekliyor = false, this.simge});
  final String etiket;
  final VoidCallback? onPressed;
  final bool bekliyor;
  final IconData? simge;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: bekliyor ? null : onPressed,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(bekliyor ? 'Bekle…' : etiket),
            if (!bekliyor && simge != null) ...[const SizedBox(width: 8), Icon(simge, size: 20)],
          ]),
        ),
      );
}

/// Kısa bilgi iletisi (alt kısımda).
void bildir(BuildContext context, String metin) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(metin)));

/// Alt gezinme sekmesi.
class AltSekme {
  const AltSekme(this.etiket, this.simge, {this.rozet = 0});
  final String etiket;
  final IconData simge;
  final int rozet;
}

/// Alt gezinme çubuğu (sitedeki AltGezinme): beyaz zemin, üstte ince çizgi; seçili sekmede üstte turuncu çubuk
/// ve turuncu simge; okunmamış sayısı lacivert rozetle.
class AltCubuk extends StatelessWidget {
  const AltCubuk({super.key, required this.sekmeler, required this.secili, required this.onSec});
  final List<AltSekme> sekmeler;
  final int secili;
  final ValueChanged<int> onSec;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Renk.cizgi))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(children: [
              for (var i = 0; i < sekmeler.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == secili,
                    button: true,
                    label: sekmeler[i].rozet > 0 ? '${sekmeler[i].etiket}, ${sekmeler[i].rozet} yeni' : sekmeler[i].etiket,
                    // Ekran okuyucuyla da sekme değişsin (içteki dokunma alanı gizlendiği için eylem burada).
                    onTap: () => onSec(i),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onSec(i),
                      child: Stack(children: [
                        if (i == secili)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: FractionallySizedBox(
                              widthFactor: 0.52,
                              child: Container(height: 3, decoration: BoxDecoration(color: Renk.secili, borderRadius: BorderRadius.circular(99))),
                            ),
                          ),
                        Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Stack(clipBehavior: Clip.none, children: [
                              Icon(sekmeler[i].simge, size: 25, color: i == secili ? Renk.secili : Renk.lacivert),
                              if (sekmeler[i].rozet > 0)
                                Positioned(
                                  top: -7,
                                  left: 15,
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 22),
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: Renk.lacivert, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white, width: 2)),
                                    child: Text('${sekmeler[i].rozet}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 3),
                            Text(sekmeler[i].etiket,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: i == secili ? FontWeight.w700 : FontWeight.w500, color: Renk.lacivert)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
