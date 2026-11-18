import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../bilesenler.dart';
import '../katalog.dart';
import '../tema.dart';
import '../zaman.dart';
import 'giris.dart' show siteyiAc;
import 'musteri.dart' show onaySor;
import 'takip.dart' show TarihSecici, tlYaz;

/* Ustanın kayıtları (sitedeki /usta/kayitlar): servis defteri, dönem özeti, arama, elle kayıt, servis fişi.
   Kayıt tutmak isteğe bağlı; hatırlatmalar kapatılabilir. Servis fişi araç sahibi ve usta tarafından açılır. */

String _binlik(num n) => n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

class UstaKayitlarEkrani extends StatefulWidget {
  const UstaKayitlarEkrani({super.key});
  @override
  State<UstaKayitlarEkrani> createState() => _UstaKayitlarEkraniState();
}

class _UstaKayitlarEkraniState extends State<UstaKayitlarEkrani> {
  String _donem = 'bu-ay';
  String _q = '';
  final _ara = TextEditingController();
  int _surum = 0;

  Future<(Katalog, Map<String, dynamic>)> _yukle() async => (await Katalog.al(), await Api.ben.veri('usta-kayitlar', {'donem': _donem, if (_q.isNotEmpty) 'q': _q}));

  void _yenidenYukle() => setState(() => _surum++);

  @override
  Widget build(BuildContext context) => VeriEkrani<(Katalog, Map<String, dynamic>)>(
        key: ValueKey('$_donem|$_q|$_surum'),
        yukle: _yukle,
        icerik: (context, veri, yenile) {
          final (katalog, v) = veri;
          final o = Map<String, dynamic>.from(v['ozet']);
          final liste = [for (final x in v['liste'] as List) Map<String, dynamic>.from(x)];
          final eksik = [for (final x in (v['eksik'] as List? ?? const [])) Map<String, dynamic>.from(x)];
          final hatirlat = v['hatirlat'] == true;
          final donemler = [for (final d in v['donemler'] as List) (d['kod'] as String, d['ad'] as String)];
          final kartlar = <(String, String)>[
            ('Tamamlanan iş', _binlik(o['isSayisi'] as num)),
            ('Servis kaydı', _binlik(o['kayitSayisi'] as num)),
            ('Toplam tutar', (o['toplamTutar'] as num) > 0 ? tlYaz(o['toplamTutar'] as num) : '0 TL'),
            ('Ortalama iş', o['ortalamaTutar'] == null ? '–' : tlYaz((o['ortalamaTutar'] as num).round())),
            ('Tekrar gelen araç', _binlik(o['tekrarGelen'] as num)),
            ('Puan', (o['puanSayisi'] as num) > 0 ? '${o['puan'].toString().replaceAll('.', ',')} (${o['puanSayisi']})' : '–'),
          ];

          Future<void> yeniKayit({Map<String, dynamic>? elden}) async {
            final eklendi = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => KayitFormEkrani(elden: elden)));
            if (eklendi == true) _yenidenYukle();
          }

          return Sayfa(children: [
            const Konum(baslik: 'Kayıtlar', aciklama: 'Servis defterin: yaptığın işler, tutarlar, fişler. Kullanmak isteğe bağlı.'),
            AnaDugme(etiket: 'Kayıt ekle', simge: Icons.add, onPressed: () => yeniKayit()),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final (kod, ad) in donemler) ...[
                  SecimDugmesi(
                    secili: _donem == kod,
                    yukseklik: 46,
                    onTap: () => setState(() => _donem = kod),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(ad, style: Yazi.govdeKalin.copyWith(fontSize: 15))),
                  ),
                  const SizedBox(width: 6),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: [
                for (final (ad, deger) in kartlar)
                  Panel(
                    dolgu: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      FittedBox(fit: BoxFit.scaleDown, child: Text(deger, style: Yazi.rakam.copyWith(fontSize: 22))),
                      Text(ad, style: Yazi.kucuk),
                    ]),
                  ),
              ],
            ),
            if (eksik.isNotEmpty) ...[
              const SizedBox(height: 12),
              Panel(
                renk: Renk.bekleZemin,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kaydı yazılmamış ${o['eksikKayit']} iş var (isteğe bağlı)', style: Yazi.govdeKalin.copyWith(color: Renk.bekle)),
                  for (final r in eksik)
                    TextButton(
                      style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
                      onPressed: r['tur'] == 'elden' ? () => yeniKayit(elden: {'randevu': r['id'], 'musteri': r['musteri'], 'hizmet': r['hizmet']}) : null,
                      child: Text('${tarihKisa(r['gun'])} · ${r['musteri']}${r['plaka'] != null ? ' · ${r['plaka']}' : ''} · ${katalog.hizmetAdi(r['hizmet'])}',
                          style: Yazi.govde.copyWith(decoration: r['tur'] == 'elden' ? TextDecoration.underline : null)),
                    ),
                  if (eksik.any((r) => r['tur'] != 'elden')) const Text('Kadran randevularının kaydını Randevular > İş takibi ekranından yazarsın.', style: Yazi.kucuk),
                ]),
              ),
            ],
            if ((o['enCok'] as List).isNotEmpty)
              Bolum(
                baslik: 'En çok yaptığın işler',
                child: Satirlar(children: [
                  for (final x in o['enCok'] as List)
                    Satir(ok: false, baslik: katalog.hizmetAdi(x['hizmet']), ayrinti: '${x['sayi']} iş${(x['tutar'] as num) > 0 ? ' · ${tlYaz(x['tutar'] as num)}' : ''}'),
                ]),
              ),
            Bolum(
              baslik: _q.isEmpty ? '${liste.length} kayıt' : '“$_q” için ${liste.length} kayıt',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: MetinKutusu(kontrol: _ara, ipucu: 'Plaka, müşteri ya da yapılan iş')),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(onPressed: () => setState(() => _q = _ara.text.trim()), child: const Text('Ara')),
                  ),
                ]),
                const SizedBox(height: 10),
                if (liste.isEmpty)
                  Panel(child: Text(_q.isEmpty ? 'Bu dönemde kayıt yok. Yazmak zorunda değilsin.' : 'Bu aramaya uyan kayıt yok.', style: Yazi.govde))
                else
                  Satirlar(children: [
                    for (final x in liste)
                      Satir(
                        baslik: '${x['musteri']}${x['plaka'] != null ? ' · ${x['plaka']}' : ''}',
                        ayrinti: [
                          tarihKisa(x['tarih']),
                          if (x['fisNo'] != null) 'Fiş ${x['fisNo']}',
                          if (x['hizmet'] != null) katalog.hizmetAdi(x['hizmet']),
                          if (x['tutar'] != null) tlYaz(x['tutar'] as num),
                          if (x['kaynak'] == 'elle') 'Elle yazıldı',
                        ].join(' · '),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => KayitDetayEkrani(id: x['id'])));
                          _yenidenYukle();
                        },
                      ),
                  ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => siteyiAc('/usta/kayitlar/indir?donem=$_donem'),
                  icon: const Icon(Icons.download),
                  label: const Text('Muhasebe için indir (sitede)'),
                ),
              ]),
            ),
            Bolum(
              baslik: 'Hatırlatmalar',
              aciklama: 'Kayıt yazmak isteğe bağlı. Kapatırsan iş bitince servis kaydı formu kapalı gelir, eksik kayıt uyarısı çıkmaz.',
              child: Panel(
                child: Row(children: [
                  Expanded(child: Text('Servis kaydı hatırlatmaları: ${hatirlat ? 'Açık' : 'Kapalı'}', style: Yazi.govdeKalin)),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: () async {
                      await Api.ben.eylem('kayit-tercihi', {'hatirlat': hatirlat ? 'kapali' : 'acik'});
                      _yenidenYukle();
                    },
                    child: Text(hatirlat ? 'Kapat' : 'Aç'),
                  ),
                ]),
              ),
            ),
          ]);
        },
      );
}

/// Tek kayıt: ayrıntı, servis fişi, aynı aracın öteki işleri, düzeltme, (elle yazılmışsa) silme.
class KayitDetayEkrani extends StatefulWidget {
  const KayitDetayEkrani({super.key, required this.id});
  final String id;
  @override
  State<KayitDetayEkrani> createState() => _KayitDetayEkraniState();
}

class _KayitDetayEkraniState extends State<KayitDetayEkrani> {
  int _surum = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          key: ValueKey(_surum),
          yukle: () async => (await Katalog.al(), await Api.ben.veri('usta-kayit', {'id': widget.id})),
          icerik: (context, veri, _) {
            final (katalog, v) = veri;
            final k = Map<String, dynamic>.from(v['kayit']);
            final onceki = [for (final x in v['onceki'] as List) Map<String, dynamic>.from(x)];
            final elle = k['kaynak'] == 'elle';
            return Sayfa(children: [
              Konum(
                baslik: '${k['musteri']}${k['plaka'] != null ? ' · ${k['plaka']}' : ''}',
                aciklama: '${gunVeTarih(k['tarih'])}${k['fisNo'] != null ? ' · Fiş ${k['fisNo']}' : ''} · ${elle ? 'Elle yazıldı' : 'Kadran randevusu'}',
              ),
              AnaDugme(
                etiket: 'Servis fişi',
                simge: Icons.receipt_long_outlined,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FisEkrani(id: k['id']))),
              ),
              const SizedBox(height: 12),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (k['arac'] != null || k['hizmet'] != null || k['km'] != null)
                    Text([k['arac'], if (k['hizmet'] != null) katalog.hizmetAdi(k['hizmet']), if (k['km'] != null) '${_binlik(k['km'] as num)} km'].whereType<String>().join(' · '), style: Yazi.ikincil),
                  const SizedBox(height: 4),
                  Text('${k['yapilanlar']}', style: Yazi.govdeKalin),
                  if (k['parcalar'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Parçalar: ${k['parcalar']}', style: Yazi.govde)),
                  if (k['tutar'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tlYaz(k['tutar'] as num), style: Yazi.rakam.copyWith(fontSize: 22))),
                  if (k['telefon'] != null)
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:0${k['telefon']}')),
                      icon: const Icon(Icons.phone_outlined),
                      label: Text(telefonYaz(k['telefon'])),
                    ),
                ]),
              ),
              if (onceki.isNotEmpty)
                Bolum(
                  baslik: 'Bu araca daha önce yaptıkların',
                  child: Satirlar(children: [
                    for (final x in onceki)
                      Satir(
                        baslik: '${tarihKisa(x['tarih'])}${x['tutar'] != null ? ' · ${tlYaz(x['tutar'] as num)}' : ''}',
                        ayrinti: x['yapilanlar'],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KayitDetayEkrani(id: x['id']))),
                      ),
                  ]),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final tamam = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => KayitFormEkrani(kayit: k)));
                  if (tamam == true) setState(() => _surum++);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Kaydı düzelt'),
              ),
              if (elle) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Renk.hayir, side: const BorderSide(color: Renk.hayir, width: 1.5)),
                  onPressed: () async {
                    final evet = await onaySor(context, 'Kaydı sil', 'Bu kayıt defterinden silinecek. Geri alınamaz.', 'Evet, sil');
                    if (!evet || !context.mounted) return;
                    await Api.ben.eylem('kayit-sil', {'id': k['id']});
                    if (!context.mounted) return;
                    bildir(context, 'Kayıt silindi.');
                    Navigator.pop(context);
                  },
                  child: const Text('Kaydı sil'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Kadran randevusundan yazılan kayıt araç sahibinin servis geçmişinde de durur; silinemez, düzeltilebilir.', style: Yazi.kucuk),
                ),
            ]);
          },
        ),
      );
}

/// Kayıt formu: yeni elle kayıt, elden randevudan kayıt ya da düzeltme. Kadran kaydında kişi ve araç alanı yok.
class KayitFormEkrani extends StatefulWidget {
  const KayitFormEkrani({super.key, this.kayit, this.elden});
  final Map<String, dynamic>? kayit;
  /// Elden randevudan: {randevu, musteri, telefon, arac, hizmet}
  final Map<String, dynamic>? elden;
  @override
  State<KayitFormEkrani> createState() => _KayitFormEkraniState();
}

class _KayitFormEkraniState extends State<KayitFormEkrani> {
  late final _musteri = TextEditingController(text: widget.kayit?['musteri'] ?? widget.elden?['musteri'] ?? '');
  late final _telefon = TextEditingController(text: widget.kayit?['telefon'] ?? widget.elden?['telefon'] ?? '');
  late final _plaka = TextEditingController(text: widget.kayit?['plaka'] ?? '');
  late final _arac = TextEditingController(text: widget.kayit?['arac'] ?? widget.elden?['arac'] ?? '');
  late final _yapilanlar = TextEditingController(text: widget.kayit?['yapilanlar'] ?? '');
  late final _parcalar = TextEditingController(text: widget.kayit?['parcalar'] ?? '');
  late final _tutar = TextEditingController(text: widget.kayit?['tutar'] == null ? '' : '${widget.kayit!['tutar']}');
  late final _km = TextEditingController(text: widget.kayit?['km'] == null ? '' : '${widget.kayit!['km']}');
  late String? _hizmet = widget.kayit?['hizmet'] ?? widget.elden?['hizmet'];
  late String? _tarih = widget.kayit?['tarih'] ?? bugunIso();
  EylemSonucu? _sonuc;
  bool _bekliyor = false;

  bool get _kadranKaydi => widget.kayit != null && widget.kayit!['kaynak'] != 'elle';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<Katalog>(
          yukle: Katalog.al,
          icerik: (context, katalog, _) {
            final h = _sonuc?.alanlar ?? const {};
            return Sayfa(children: [
              Konum(
                baslik: widget.kayit != null ? 'Kaydı düzelt' : 'Kayıt ekle',
                aciklama: widget.elden != null ? 'Elden randevu' : (widget.kayit == null ? 'Elden gelen ya da Kadran dışında yaptığın bir iş. Yalnız senin defterinde durur.' : null),
              ),
              if (_sonuc?.hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 12)],
              if (!_kadranKaydi) ...[
                Alan(etiket: 'Müşteri', hata: h['musteri'], child: MetinKutusu(kontrol: _musteri, hata: h['musteri'] != null)),
                const SizedBox(height: 12),
                Alan(etiket: 'Telefon (isteğe bağlı)', hata: h['telefon'], child: MetinKutusu(kontrol: _telefon, klavye: TextInputType.phone, hata: h['telefon'] != null)),
                const SizedBox(height: 12),
                Alan(etiket: 'Plaka (isteğe bağlı)', ipucu: 'Aynı araç yeniden gelince önceki işleri gösteririz.', hata: h['plaka'], child: MetinKutusu(kontrol: _plaka, hata: h['plaka'] != null)),
                const SizedBox(height: 12),
                Alan(etiket: 'Araç (isteğe bağlı)', ipucu: 'Örnek: Fiat Egea 2019', child: MetinKutusu(kontrol: _arac)),
                const SizedBox(height: 12),
                SecimKutusu(
                  etiket: 'İş (isteğe bağlı)',
                  bos: 'Seçmedim',
                  deger: _hizmet,
                  gruplar: [for (final g in katalog.hizmetler) SecenekGrubu([Secenek(g.kod, '${g.ad} (genel)'), for (final i in g.isler) Secenek(i.kod, i.ad)], baslik: g.ad)],
                  onSec: (v) => setState(() => _hizmet = v),
                ),
                if (widget.elden == null) ...[
                  const SizedBox(height: 12),
                  Alan(etiket: 'Tarih', hata: h['tarih'], child: TarihSecici(etiket: 'Tarih', deger: _tarih, onSec: (t) => setState(() => _tarih = t))),
                ],
                const SizedBox(height: 12),
              ],
              Alan(etiket: 'Yapılanlar', ipucu: 'Örnek: Yağ ve yağ filtresi değişti.', hata: h['yapilanlar'], child: MetinKutusu(kontrol: _yapilanlar, satir: 3, hata: h['yapilanlar'] != null)),
              const SizedBox(height: 12),
              Alan(etiket: 'Değişen parçalar (isteğe bağlı)', child: MetinKutusu(kontrol: _parcalar, satir: 2)),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Alan(etiket: 'Tutar, TL', hata: h['tutar'], child: MetinKutusu(kontrol: _tutar, klavye: const TextInputType.numberWithOptions(decimal: true), hata: h['tutar'] != null))),
                const SizedBox(width: 10),
                Expanded(child: Alan(etiket: 'Kilometre', hata: h['km'], child: MetinKutusu(kontrol: _km, klavye: TextInputType.number, hata: h['km'] != null))),
              ]),
              const SizedBox(height: 20),
              AnaDugme(
                etiket: widget.kayit != null ? 'Kaydı güncelle' : 'Kaydı yaz',
                bekliyor: _bekliyor,
                onPressed: () async {
                  setState(() => _bekliyor = true);
                  final s = await Api.ben.eylem('kayit-kaydet', {
                    'id': ?widget.kayit?['id'],
                    'randevu': ?widget.elden?['randevu'],
                    'musteri': _musteri.text,
                    'telefon': _telefon.text,
                    'plaka': _plaka.text,
                    'arac': _arac.text,
                    'hizmet': _hizmet ?? '',
                    'tarih': _tarih ?? '',
                    'yapilanlar': _yapilanlar.text,
                    'parcalar': _parcalar.text,
                    'tutar': _tutar.text,
                    'km': _km.text,
                  });
                  if (!context.mounted) return;
                  setState(() {
                    _bekliyor = false;
                    _sonuc = s;
                  });
                  if (s.yonlendir != null && s.hata == null) {
                    bildir(context, widget.kayit != null ? 'Kayıt güncellendi.' : 'Kayıt yazıldı.');
                    Navigator.pop(context, true);
                  }
                },
              ),
            ]);
          },
        ),
      );
}

/// Servis fişi (araç sahibi ve usta): ekranda gösterilir; yazdırmak ya da PDF için sitede açılır.
class FisEkrani extends StatelessWidget {
  const FisEkrani({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          yukle: () async => (await Katalog.al(), Map<String, dynamic>.from((await Api.ben.veri('fis', {'id': id}))['fis'])),
          icerik: (context, veri, _) {
            final (katalog, f) = veri;
            Widget satir(String ad, Object? deger) => deger == null || '$deger'.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 110, child: Text(ad, style: Yazi.ikincil)),
                      Expanded(child: Text('$deger', style: Yazi.govdeKalin)),
                    ]),
                  );
            return Sayfa(children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Kose.panel), border: Border.all(color: Renk.cizgi)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${f['firma']}', style: Yazi.bolum),
                        Text('${f['ustaAdi']}', style: Yazi.govde),
                        if (f['adres'] != null) Text([f['adres'], if (f['ilce'] != null) '${f['ilce']}/${f['il']}'].join(' · '), style: Yazi.kucuk),
                        if (f['ustaTelefon'] != null) Text('Tel: ${telefonYaz(f['ustaTelefon'])}', style: Yazi.kucuk),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('SERVİS FİŞİ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
                      if (f['fisNo'] != null) Text('No: ${'${f['fisNo']}'.padLeft(5, '0')}', style: Yazi.rakam),
                      Text(tarihKisa(f['tarih']), style: Yazi.govde),
                    ]),
                  ]),
                  const Divider(height: 24, thickness: 2, color: Renk.lacivert),
                  satir('Müşteri', f['musteri']),
                  satir('Telefon', f['telefon'] == null ? null : telefonYaz(f['telefon'])),
                  satir('Plaka', f['plaka']),
                  satir('Araç', f['arac']),
                  satir('Kilometre', f['km'] == null ? null : '${_binlik(f['km'] as num)} km'),
                  satir('İş', f['hizmet'] == null ? null : katalog.hizmetAdi(f['hizmet'])),
                  const SizedBox(height: 10),
                  const Text('Yapılanlar', style: Yazi.govdeKalin),
                  Text('${f['yapilanlar']}', style: Yazi.govde),
                  if (f['parcalar'] != null) ...[
                    const SizedBox(height: 8),
                    const Text('Değişen parçalar', style: Yazi.govdeKalin),
                    Text('${f['parcalar']}', style: Yazi.govde),
                  ],
                  if (f['tutar'] != null) ...[
                    const Divider(height: 24, thickness: 2, color: Renk.lacivert),
                    Row(children: [
                      const Expanded(child: Text('Toplam', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                      Text(tlYaz(f['tutar'] as num), style: Yazi.rakam.copyWith(fontSize: 20)),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  const Text('Bu fiş fatura yerine geçmez.', style: Yazi.kucuk),
                ]),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => siteyiAc('/fis/$id'),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Yazdır ya da PDF (sitede)'),
              ),
            ]);
          },
        ),
      );
}
