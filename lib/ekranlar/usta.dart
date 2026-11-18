import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../bilesenler.dart';
import '../katalog.dart';
import '../oturum.dart';
import '../tema.dart';
import '../zaman.dart';
import 'giris.dart';
import 'mesajlar.dart';
import 'musteri.dart' show onaySor;
import 'takip.dart';
import 'teklif.dart';
import 'kayitlar.dart';

/* Usta yüzü: Özet · Randevular · Mesajlar · Takvim. Ustanın günlük işleri burada:
   talebi onayla ya da reddet, randevuyu sonuçlandır, elden randevu ekle, saat kapat, müşteriye yaz.
   Başvuru, belgeler ve çalışma saatlerinin düzenlenmesi sitede kalır (bağlantıyla açılır). */

final ustaSekmesi = ValueNotifier<int>(0);

class UstaKabuk extends StatefulWidget {
  const UstaKabuk({super.key});
  @override
  State<UstaKabuk> createState() => _UstaKabukState();
}

class _UstaKabukState extends State<UstaKabuk> {
  @override
  void initState() {
    super.initState();
    ustaSekmesi.addListener(_degisti);
    Oturum.ben.addListener(_degisti);
  }

  @override
  void dispose() {
    ustaSekmesi.removeListener(_degisti);
    Oturum.ben.removeListener(_degisti);
    super.dispose();
  }

  void _degisti() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final i = ustaSekmesi.value;
    return Scaffold(
      appBar: ustSerit(context),
      body: IndexedStack(index: i, children: [
        UstaOzetEkrani(key: ValueKey('o$i')),
        UstaRandevularEkrani(key: ValueKey('r$i')),
        MesajlarEkrani(key: ValueKey('m$i')),
        UstaTakvimEkrani(key: ValueKey('t$i')),
        UstaKayitlarEkrani(key: ValueKey('k$i')),
      ]),
      bottomNavigationBar: AltCubuk(
        secili: i,
        onSec: (s) => ustaSekmesi.value = s,
        sekmeler: [
          const AltSekme('Özet', Icons.view_list_outlined),
          const AltSekme('Randevular', Icons.event_available_outlined),
          AltSekme('Mesajlar', Icons.chat_bubble_outline, rozet: Oturum.ben.okunmamis),
          const AltSekme('Takvim', Icons.calendar_month_outlined),
          const AltSekme('Kayıtlar', Icons.receipt_long_outlined),
        ],
      ),
    );
  }
}

/// Randevu satırı için ortak liste verisi (talepler, onaylılar, geçmiş).
class _Randevular {
  _Randevular(this.bugun, this.hepsi);
  final String bugun;
  final List<Map<String, dynamic>> hepsi;
  List<Map<String, dynamic>> get bekleyen => hepsi.where((r) => r['durum'] == 'bekliyor' && (r['tarih'] as String).compareTo(bugun) >= 0).toList();
  List<Map<String, dynamic>> get onayli =>
      hepsi.where((r) => r['durum'] == 'onaylandi' && !(r['tur'] == 'kapali' && (r['tarih'] as String).compareTo(bugun) < 0)).toList();
  List<Map<String, dynamic>> get gecmis => hepsi.where((r) => r['tur'] != 'kapali' && !bekleyen.contains(r) && !onayli.contains(r)).toList().reversed.toList();
}

Future<_Randevular> _randevulariYukle() async {
  final v = await Api.ben.veri('usta-randevular');
  return _Randevular(v['bugun'], [for (final r in v['randevular'] as List) Map<String, dynamic>.from(r)]);
}

/* ── Özet ─────────────────────────────────────────────────────────────── */

class UstaOzetEkrani extends StatelessWidget {
  const UstaOzetEkrani({super.key});
  @override
  Widget build(BuildContext context) => VeriEkrani<(Map<String, dynamic>, _Randevular, Katalog, List<dynamic>)>(
        yenileme: const Duration(seconds: 15),
        yukle: () async => (
          await Api.ben.veri('usta-ben'),
          await _randevulariYukle(),
          await Katalog.al(),
          (await Api.ben.veri('usta-talepleri'))['talepler'] as List,
        ),
        icerik: (context, veri, yenile) {
          final (ben, r, katalog, talepler) = veri;
          final yeniTalep = talepler.where((t) => t['benimTeklif'] == null).length;
          final k = Oturum.ben.kullanici!;
          final bekleyen = r.bekleyen;
          final bugunku = r.onayli.where((x) => x['tarih'] == r.bugun && x['tur'] != 'kapali').toList();
          final saatYok = (ben['program'] as List).every((g) => g['acik'] != true);
          return Sayfa(children: [
            Konum(baslik: 'Merhaba, ${k.ilkAd} Usta', aciklama: '${gunVeTarih(r.bugun)} · ${ben['firma']}'),
            if (saatYok) ...[
              const Uyari(tur: UyariTuru.bilgi, baslik: 'Çalışma saatlerini henüz girmedin.', metin: 'Saatlerini girene kadar müşteriler seni listede göremez.'),
              const SizedBox(height: 12),
              AnaDugme(etiket: 'Çalışma saatlerini sitede gir', onPressed: () => siteyiAc('/usta/takvim')),
              const SizedBox(height: 16),
            ],
            Panel(
              dolgu: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${bekleyen.length}', style: Yazi.rakam.copyWith(fontSize: 56, height: 1)),
                  const SizedBox(width: 10),
                  const Expanded(child: Padding(padding: EdgeInsets.only(bottom: 6), child: Text('talep onayını bekliyor', style: Yazi.govdeKalin))),
                ]),
                const SizedBox(height: 8),
                Text(
                  bekleyen.isEmpty ? 'Yeni talep gelince burada görürsün.' : 'Müşteri, sen onaylayana kadar randevusunu kesin bilmiyor. Erken bakman iyi olur.',
                  style: Yazi.ikincil,
                ),
                const SizedBox(height: 14),
                bekleyen.isEmpty
                    ? SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => ustaSekmesi.value = 1, child: const Text('Randevulara git')))
                    : AnaDugme(etiket: 'Talepleri gör', simge: Icons.arrow_forward, onPressed: () => ustaSekmesi.value = 1),
              ]),
            ),
            Bolum(
              baslik: 'Bugünkü randevular',
              aciklama: '${bugunku.length} onaylı randevu',
              child: bugunku.isEmpty
                  ? const Panel(child: Text('Bugün onaylı randevun yok.', style: Yazi.govde))
                  : Satirlar(children: [
                      for (final x in bugunku)
                        Satir(
                          sol: BuyukSaat(x['saat']),
                          baslik: x['musteri'],
                          ayrinti: [x['arac'], x['plaka'], if ((x['hizmet'] as String).isNotEmpty) katalog.hizmetAdi(x['hizmet'])].where((e) => '$e'.isNotEmpty).join(' · '),
                        ),
                    ]),
            ),
            Bolum(
              baslik: 'Teklif talepleri',
              aciklama: 'Bölgendeki araç sahipleri fiyat soruyor.',
              child: Satirlar(children: [
                Satir(
                  baslik: yeniTalep > 0 ? '$yeniTalep talep fiyatını bekliyor' : 'Yeni talep yok',
                  ayrinti: talepler.isEmpty ? 'Yeni talep gelince haber veririz.' : '${talepler.length} açık talep',
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const UstaTaleplerEkrani()));
                    yenile();
                  },
                ),
              ]),
            ),
            if (ben['baglanti'] != null)
              Bolum(
                baslik: 'Müşterilerine bağlantını ver',
                aciklama: "WhatsApp'tan yolla ya da QR afişi dükkâna as. Müşteri doğrudan senin boş saatlerini görür.",
                child: BaglantiKarti(baglanti: ben['baglanti'], firma: ben['firma']),
              ),
            Bolum(
              baslik: 'İşyerim',
              child: Satirlar(children: [
                Satir(baslik: '${ben['firma']}', ayrinti: '${ben['adres']} · ${ben['ilce']}, ${ben['il']}'),
                Satir(baslik: 'Puanın', alt: PuanSatiri(puan: ben['puan'] as num, sayi: (ben['yorumSayisi'] as num).toInt())),
                Satir(baslik: 'İşyeri bilgilerini, belgelerini düzenle', ayrinti: 'Sitede açılır', onTap: () => siteyiAc('/usta/isyerim')),
                Satir(baslik: 'Usta sayfamı gör', ayrinti: 'Müşterilerin gördüğü sayfa', onTap: () => siteyiAc('/ustalar/${ben['slug']}')),
              ]),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Renk.hayir), onPressed: Oturum.ben.cikis, icon: const Icon(Icons.logout), label: const Text('Çıkış yap')),
          ]);
        },
      );
}

/* ── Randevular ───────────────────────────────────────────────────────── */

class UstaRandevularEkrani extends StatefulWidget {
  const UstaRandevularEkrani({super.key});
  @override
  State<UstaRandevularEkrani> createState() => _UstaRandevularEkraniState();
}

class _UstaRandevularEkraniState extends State<UstaRandevularEkrani> {
  String _sekme = 'bekleyen';

  static const _sonuclar = {
    'onaylandi': 'Randevu onaylandı. Müşteriye haber veriyoruz.',
    'reddedildi': 'Talep reddedildi. Müşteriye nedenini bildiriyoruz.',
    'tamamlandi': 'İş tamamlandı olarak kaydedildi. Müşteri artık seni puanlayabilir.',
    'gelmedi': 'Müşteri gelmedi olarak kaydedildi.',
    'iptal': 'Randevu iptal edildi. Müşteriye nedenini bildiriyoruz.',
    'eklendi': 'Randevu takvime eklendi. O saat sitede dolu görünüyor.',
    'kapatildi': 'Saatler kapatıldı. Bu aralıkta müşteriler randevu alamaz.',
    'kaldirildi': 'Kayıt kaldırıldı. O saat yeniden boş.',
    'yapilamadi': 'İşlem yapılamadı. Randevunun durumu değişmiş olabilir; listeyi kontrol et.',
  };

  Future<void> _karar(Future<void> Function() yenile, Map<String, Object?> alanlar, {String eylem = 'usta-karar'}) async {
    final s = await Api.ben.eylem(eylem, alanlar);
    if (!mounted) return;
    final islem = s.parametre('islem');
    bildir(context, s.hata ?? _sonuclar[islem] ?? 'Kaydedildi.');
    await yenile();
  }

  /// Elden randevunun servis kaydı: varsa açar, yoksa randevunun bilgileriyle form açar.
  Future<void> _kayitAc(Map<String, dynamic> x, Future<void> Function() yenile) async {
    if (x['kayitId'] != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => KayitDetayEkrani(id: x['kayitId'])));
    } else {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => KayitFormEkrani(elden: {'randevu': x['id'], 'musteri': x['musteri'], 'telefon': x['telefon'], 'arac': x['arac'], 'hizmet': x['hizmet']})),
      );
    }
    await yenile();
  }

  Future<String?> _nedenSor(String baslik, List<String> nedenler) => secimSayfasi(
        context,
        baslik: baslik,
        arama: false,
        gruplar: [SecenekGrubu([for (final n in nedenler) Secenek(n, n)])],
      );

  @override
  Widget build(BuildContext context) => VeriEkrani<(_Randevular, Katalog)>(
        yenileme: const Duration(seconds: 10),
        yukle: () async => (await _randevulariYukle(), await Katalog.al()),
        icerik: (context, veri, yenile) {
          final (r, katalog) = veri;
          final liste = switch (_sekme) { 'onayli' => r.onayli, 'gecmis' => r.gecmis, _ => r.bekleyen };
          String isAdi(Map<String, dynamic> x) => (x['hizmet'] as String).isEmpty || x['hizmet'] == 'kapali' ? '' : katalog.hizmetAdi(x['hizmet']);

          return Sayfa(children: [
            const Konum(baslik: 'Randevular'),
            Row(children: [
              for (final (kod, ad, sayi) in [('bekleyen', 'Onay bekleyen', r.bekleyen.length), ('onayli', 'Onaylanan', r.onayli.length), ('gecmis', 'Geçmiş', r.gecmis.length)]) ...[
                if (kod != 'bekleyen') const SizedBox(width: 8),
                Expanded(
                  child: SecimDugmesi(
                    secili: _sekme == kod,
                    yukseklik: 60,
                    onTap: () => setState(() => _sekme = kod),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(ad, textAlign: TextAlign.center, style: Yazi.govdeKalin.copyWith(fontSize: 15)),
                      Text('$sayi', style: Yazi.kucuk),
                    ]),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final eklendi = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const EldenEkleEkrani()));
                if (eklendi != null && context.mounted) {
                  bildir(context, _sonuclar[eklendi] ?? 'Kaydedildi.');
                  setState(() => _sekme = 'onayli');
                  yenile();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Elden randevu ekle ya da saat kapat'),
            ),
            const SizedBox(height: 16),
            if (liste.isEmpty)
              BosEkran(
                baslik: switch (_sekme) { 'onayli' => 'Onaylanmış randevun yok', 'gecmis' => 'Geçmiş randevun yok', _ => 'Onay bekleyen talep yok' },
                aciklama: _sekme == 'bekleyen' ? 'Takvimin açık olduğu sürece yeni talepler buraya düşer.' : 'Onayladığın talepler ve elden eklediğin randevular burada görünür.',
              )
            else
              for (final x in liste) ...[_kart(x, r.bugun, isAdi(x), yenile), const SizedBox(height: 10)],
          ]);
        },
      );

  Widget _kart(Map<String, dynamic> x, String bugun, String isAdi, Future<void> Function() yenile) {
    final tur = x['tur'] as String;
    final kapali = tur == 'kapali';
    final elden = tur == 'elden';
    final gunuGeldi = (x['tarih'] as String).compareTo(bugun) <= 0;
    final telefon = x['telefon'] as String?;

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BuyukSaat(x['saat'], boy: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(kapali ? 'Kapalı saat · ${x['saat']}–${x['bitis']}' : x['musteri'], style: Yazi.govdeKalin)),
                if (elden) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)), child: const Text('Elden', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              ]),
              Text([gunVeTarih(x['tarih']), if (!kapali) '${x['saat']}–${x['bitis']}', if (isAdi.isNotEmpty) isAdi].join(' · '), style: Yazi.ikincil),
              if (!kapali && ('${x['arac']}${x['plaka']}').isNotEmpty) Text([x['arac'], x['plaka']].where((e) => '$e'.isNotEmpty).join(' · '), style: Yazi.ikincil),
              if (x['not'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${x['not']}”', style: Yazi.govde)),
              if ((x['onceki'] as num? ?? 0) > 0)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('Bu araç sana daha önce ${x['onceki']} kez geldi', style: Yazi.govdeKalin.copyWith(color: Renk.bekle))),
              if (kapali && x['aciklama'] != null) Text('${x['aciklama']}', style: Yazi.ikincil),
              if (x['durum'] != 'bekliyor' && x['durum'] != 'onaylandi') Padding(padding: const EdgeInsets.only(top: 6), child: DurumRozeti(x['durum'])),
              if (x['durum'] == 'bekliyor') Padding(padding: const EdgeInsets.only(top: 4), child: Text('Talep geldi: ${x['geldi']}', style: Yazi.kucuk)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        if (x['durum'] == 'bekliyor') ...[
          AnaDugme(etiket: 'Onayla', simge: Icons.check, onPressed: () => _karar(yenile, {'id': x['id'], 'karar': 'onayla'})),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final neden = await _nedenSor('Neden reddediyorsun?', const ['Bu saatte doluyum', 'Bu iş için uygun değilim', 'Parça yok, getirtmem lazım', 'Başka bir neden']);
                if (neden != null) _karar(yenile, {'id': x['id'], 'karar': 'reddet', 'neden': neden});
              },
              child: const Text('Reddet'),
            ),
          ),
        ] else if (x['durum'] == 'onaylandi') ...[
          if (!kapali && !elden) ...[
            AnaDugme(
              etiket: 'İş takibi: durum, ek iş, servis',
              simge: Icons.arrow_forward,
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => RandevuTakipEkrani(id: x['id'], usta: true)));
                yenile();
              },
            ),
            const SizedBox(height: 8),
          ],
          if (elden && gunuGeldi) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _kayitAc(x, yenile),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(x['kayitId'] != null ? 'Servis kaydı' : 'Servis kaydı yaz (isteğe bağlı)'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (!kapali && gunuGeldi) ...[
            // Elden randevuda ana düğme; site randevusunda iş takibi ana düğmedir, bu ikincil kalır.
            if (elden)
              AnaDugme(etiket: 'İş tamamlandı', simge: Icons.check, onPressed: () => _karar(yenile, {'id': x['id'], 'karar': 'tamamla'}))
            else
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _karar(yenile, {'id': x['id'], 'karar': 'tamamla'}), child: const Text('İş tamamlandı'))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _karar(yenile, {'id': x['id'], 'karar': 'gelmedi'}), child: const Text('Müşteri gelmedi'))),
            const SizedBox(height: 8),
          ],
          if (kapali || elden)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final evet = await onaySor(context, kapali ? 'Kapalı saati kaldır' : 'Randevuyu kaldır', 'Bu kayıt takvimden kalkacak; saat yeniden boş görünecek.', 'Evet, kaldır');
                  if (evet) _karar(yenile, {'id': x['id']}, eylem: 'elden-sil');
                },
                child: Text(kapali ? 'Kapalı saati kaldır' : 'Randevuyu takvimden kaldır'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Renk.hayir),
                onPressed: () async {
                  final neden = await _nedenSor('Neden iptal ediyorsun?', const ['Dükkân o gün kapalı', 'Parça gelmedi', 'Sağlık sorunu', 'Başka bir neden']);
                  if (neden != null) _karar(yenile, {'id': x['id'], 'karar': 'iptal', 'neden': neden});
                },
                child: const Text('Randevuyu iptal et'),
              ),
            ),
        ],
        if (x['durum'] == 'tamamlandi' && elden)
          TextButton.icon(
            onPressed: () => _kayitAc(x, yenile),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(x['kayitId'] != null ? 'Servis kaydı' : 'Servis kaydı yaz'),
          ),
        if (x['durum'] == 'tamamlandi' && !elden && x['silinmis'] != true)
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RandevuTakipEkrani(id: x['id'], usta: true))),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Servis kaydı'),
          ),
        if (!kapali) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 4, children: [
            if (telefon != null)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:${telefon.replaceAll(' ', '')}')),
                icon: const Icon(Icons.phone_outlined),
                label: Text('Ara · $telefon'),
              ),
            if (!elden && x['silinmis'] != true)
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SohbetEkrani(randevuId: x['id'], baslik: x['musteri']))),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Müşteriye yaz'),
              ),
          ]),
        ],
      ]),
    );
  }
}

/* ── Elden randevu ve saat kapatma ────────────────────────────────────── */

/// Başarılı olunca sonucu ("eklendi" ya da "kapatildi") döndürür.
class EldenEkleEkrani extends StatefulWidget {
  const EldenEkleEkrani({super.key});
  @override
  State<EldenEkleEkrani> createState() => _EldenEkleEkraniState();
}

class _EldenEkleEkraniState extends State<EldenEkleEkrani> {
  String _tur = 'elden';
  String _gun = bugunIso();
  String _bas = '09:00';
  String? _bit;
  String _hizmet = '';
  final _ad = TextEditingController();
  final _telefon = TextEditingController();
  final _arac = TextEditingController();
  final _not = TextEditingController();
  EylemSonucu? _sonuc;
  bool _bekliyor = false;

  static final _saatler = [
    for (var d = 6 * 60; d < 24 * 60; d += 15) '${(d ~/ 60).toString().padLeft(2, '0')}:${(d % 60).toString().padLeft(2, '0')}',
  ];
  int _dk(String s) => int.parse(s.substring(0, 2)) * 60 + int.parse(s.substring(3, 5));

  Future<void> _kaydet() async {
    setState(() => _bekliyor = true);
    final s = await Api.ben.eylem('elden-ekle', {
      'tur': _tur,
      'gun': _gun,
      'bas': _bas,
      'bit': _bit ?? '',
      'ad': _ad.text,
      'telefon': _telefon.text,
      'arac': _arac.text,
      'hizmet': _hizmet,
      'not': _not.text,
    });
    if (!mounted) return;
    setState(() {
      _sonuc = s;
      _bekliyor = false;
    });
    if (s.tamam) Navigator.pop(context, s.parametre('islem'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Map<String, dynamic>, Katalog)>(
          yukle: () async => (await Api.ben.veri('usta-ben'), await Katalog.al()),
          icerik: (context, veri, _) {
            final (ben, katalog) = veri;
            final h = _sonuc?.alanlar ?? {};
            final sure = (ben['randevuSuresi'] as num).toInt();
            final bit = _bit ?? _saatler.firstWhere((s) => _dk(s) >= _dk(_bas) + sure, orElse: () => _saatler.last);
            final elden = _tur == 'elden';
            final uzm = [for (final x in ben['uzmanliklar'] as List) '$x'];
            return Sayfa(children: [
              const Konum(baslik: 'Takvime ekle', aciklama: 'Eklediğin saatler sitede dolu görünür; müşteriler o saate randevu alamaz.'),
              Row(children: [
                Expanded(child: SecimDugmesi(secili: elden, yukseklik: 64, onTap: () => setState(() => _tur = 'elden'), child: const Column(mainAxisSize: MainAxisSize.min, children: [Text('Elden randevu', style: Yazi.govdeKalin), Text('Telefonla, kapıdan', style: Yazi.kucuk)]))),
                const SizedBox(width: 8),
                Expanded(child: SecimDugmesi(secili: !elden, yukseklik: 64, onTap: () => setState(() => _tur = 'kapali'), child: const Column(mainAxisSize: MainAxisSize.min, children: [Text('Saati kapat', style: Yazi.govdeKalin), Text('Öğle, dışarıda, özel iş', style: Yazi.kucuk)]))),
              ]),
              const SizedBox(height: 18),
              if (_sonuc?.hata != null && !_sonuc!.tamam) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 16)],
              Alan(
                etiket: 'Gün',
                hata: h['gun'],
                child: SecimKutusu(
                  etiket: 'Gün',
                  deger: _gun,
                  gruplar: [SecenekGrubu([for (var i = 0; i <= 30; i++) Secenek(gunEkle(bugunIso(), i), gunVeTarih(gunEkle(bugunIso(), i)))])],
                  onSec: (g) => setState(() => _gun = g),
                ),
              ),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Alan(
                    etiket: 'Başlangıç',
                    hata: h['bas'],
                    child: SecimKutusu(
                      etiket: 'Saat',
                      deger: _bas,
                      hata: h['bas'] != null,
                      gruplar: [SecenekGrubu([for (final s in _saatler) Secenek(s, s)])],
                      onSec: (s) => setState(() {
                        _bas = s;
                        if (_bit != null && _dk(_bit!) <= _dk(s)) _bit = null;
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Alan(
                    etiket: 'Bitiş',
                    hata: h['bit'],
                    child: SecimKutusu(
                      etiket: 'Saat',
                      deger: bit,
                      hata: h['bit'] != null,
                      gruplar: [SecenekGrubu([for (final s in _saatler.where((s) => _dk(s) > _dk(_bas))) Secenek(s, s)])],
                      onSec: (s) => setState(() => _bit = s),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (elden) ...[
                Alan(etiket: 'Müşterinin adı', hata: h['ad'], child: MetinKutusu(kontrol: _ad, hata: h['ad'] != null)),
                const SizedBox(height: 16),
                Alan(etiket: 'Telefonu (isteğe bağlı)', hata: h['telefon'], child: MetinKutusu(kontrol: _telefon, klavye: TextInputType.phone, hata: h['telefon'] != null)),
                const SizedBox(height: 16),
                Alan(etiket: 'Araç ve plaka (isteğe bağlı)', ipucu: 'Örnek: Renault Clio · 34 ABC 123', hata: h['arac'], child: MetinKutusu(kontrol: _arac)),
                const SizedBox(height: 16),
                Alan(
                  etiket: 'Yapılacak iş (isteğe bağlı)',
                  child: SecimKutusu(
                    etiket: 'İş',
                    deger: _hizmet,
                    gruplar: [
                      const SecenekGrubu([Secenek('', 'Belirtilmedi')]),
                      for (final g in katalog.hizmetler.where((g) => uzm.contains(g.kod))) SecenekGrubu([for (final i in g.isler) Secenek(i.kod, i.ad)], baslik: g.ad),
                    ],
                    onSec: (x) => setState(() => _hizmet = x),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Alan(etiket: elden ? 'Not (isteğe bağlı)' : 'Neden (isteğe bağlı, yalnız sen görürsün)', hata: h['not'], child: MetinKutusu(kontrol: _not, satir: 2)),
              const SizedBox(height: 24),
              AnaDugme(
                etiket: elden ? 'Randevuyu takvime ekle' : 'Bu saatleri kapat',
                bekliyor: _bekliyor,
                onPressed: () {
                  _bit = bit;
                  _kaydet();
                },
              ),
            ]);
          },
        ),
      );
}

/* ── Takvim ───────────────────────────────────────────────────────────── */

class UstaTakvimEkrani extends StatelessWidget {
  const UstaTakvimEkrani({super.key});
  static const _gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

  @override
  Widget build(BuildContext context) => VeriEkrani<(Map<String, dynamic>, Katalog)>(
        yukle: () async => (await Api.ben.veri('usta-ben'), await Katalog.al()),
        icerik: (context, veri, _) {
          final (ben, katalog) = veri;
          final program = [for (final p in ben['program'] as List) Map<String, dynamic>.from(p)];
          final izinler = [for (final i in ben['izinler'] as List) Map<String, dynamic>.from(i)];
          final sureler = Map<String, dynamic>.from(ben['sureler'] as Map);
          final bugunNo = DateTime.now().toUtc().add(const Duration(hours: 3)).weekday - 1;
          return Sayfa(children: [
            Konum(baslik: 'Çalışma takvimi', aciklama: '${program.where((g) => g['acik'] == true).length} gün açık'),
            Satirlar(children: [
              for (var i = 0; i < program.length; i++)
                Container(
                  color: i == bugunNo ? Renk.bant2 : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    SizedBox(width: 112, child: Text(_gunler[i], style: Yazi.govdeKalin)),
                    Expanded(
                      child: Text(
                        program[i]['acik'] == true ? [for (final a in program[i]['araliklar'] as List) '${a['bas']}–${a['bit']}'].join(', ') : 'Kapalı',
                        style: program[i]['acik'] == true ? Yazi.rakam.copyWith(fontSize: 17, fontWeight: FontWeight.w500) : Yazi.ikincil,
                      ),
                    ),
                    if (i == bugunNo) const Text('Bugün', style: Yazi.kucuk),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final sonuc = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const EldenEkleEkrani()));
                if (sonuc != null && context.mounted) bildir(context, sonuc == 'kapatildi' ? 'Saatler kapatıldı.' : 'Randevu takvime eklendi.');
              },
              icon: const Icon(Icons.block),
              label: const Text('Bir saati kapat ya da elden randevu ekle'),
            ),
            Bolum(
              baslik: 'Randevu süresi',
              child: Satirlar(children: [
                Satir(baslik: 'Genel', ayrinti: sureYaz((ben['randevuSuresi'] as num).toInt())),
                for (final e in sureler.entries) Satir(baslik: katalog.hizmetAdi(e.key), ayrinti: sureYaz((e.value as num).toInt())),
              ]),
            ),
            Bolum(
              baslik: 'İzin günleri',
              child: izinler.isEmpty
                  ? const Panel(child: Text('Planlanmış izin yok.', style: Yazi.govde))
                  : Satirlar(children: [
                      for (final z in izinler)
                        Satir(baslik: z['bas'] == z['bit'] ? '${tarihKisa(z['bas'])} ${gunAdi(z['bas'])}' : '${tarihKisa(z['bas'])} – ${tarihKisa(z['bit'])}', ayrinti: (z['neden'] as String?)?.isNotEmpty == true ? z['neden'] : 'Tüm gün'),
                    ]),
            ),
            const SizedBox(height: 16),
            const Panel(child: Text('Çalışma saatlerini, randevu sürelerini ve izin günlerini sitede değiştirirsin; değişiklik burada da görünür.', style: Yazi.ikincil)),
            const SizedBox(height: 12),
            AnaDugme(etiket: 'Takvimi sitede düzenle', simge: Icons.open_in_new, onPressed: () => siteyiAc('/usta/takvim')),
          ]);
        },
      );
}

/* ── Başvurusu onaylanmamış usta ──────────────────────────────────────── */

class UstaBasvuruDurumu extends StatelessWidget {
  const UstaBasvuruDurumu({super.key, required this.kullanici});
  final Kullanici kullanici;
  @override
  Widget build(BuildContext context) {
    final (baslik, metin) = switch (kullanici.ustaDurumu) {
      'bekliyor' => ('Başvurun inceleniyor', 'Belgelerini inceliyoruz. Onaylanınca e-postayla haber veririz; panelin burada açılır.'),
      'eksik' => ('Bir belge eksik', 'Başvurunda yeniden yüklenmesi gereken bir belge var. Sitede başvuru sayfasından yükle.'),
      'reddedildi' => ('Başvurun onaylanmadı', 'Nedenini sitedeki başvuru sayfasında görebilirsin.'),
      'askida' => ('Hesabın askıda', 'Ayrıntı için destek adresine yaz.'),
      _ => ('Başvurunu tamamla', 'Usta başvurusu belge yüklemeyle birlikte sitede yapılır. Kaldığın adımdan devam edebilirsin.'),
    };
    return Scaffold(
      appBar: ustSerit(context),
      body: Sayfa(children: [
        Konum(baslik: baslik, aciklama: 'Merhaba, ${kullanici.ilkAd} Usta'),
        Uyari(tur: kullanici.ustaDurumu == 'eksik' || kullanici.ustaDurumu == 'reddedildi' ? UyariTuru.hata : UyariTuru.bilgi, baslik: metin),
        const SizedBox(height: 16),
        AnaDugme(etiket: 'Başvuru sayfasını aç', simge: Icons.open_in_new, onPressed: () => siteyiAc(kullanici.ustaDurumu == null || kullanici.ustaDurumu == 'taslak' ? '/usta-kayit' : '/usta/basvurum')),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: Oturum.ben.yukle, child: const Text('Durumu yenile')),
        const SizedBox(height: 10),
        OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Renk.hayir), onPressed: Oturum.ben.cikis, child: const Text('Çıkış yap')),
      ]),
    );
  }
}
