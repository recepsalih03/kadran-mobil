import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../bilesenler.dart';
import '../katalog.dart';
import '../oturum.dart';
import '../tema.dart';
import '../zaman.dart';
import 'giris.dart' show siteyiAc;
import 'mesajlar.dart';
import 'musteri.dart' show UstaDetayEkrani;
import 'takip.dart';

/* Fotoğrafla teklif (sitedeki /tekliflerim, /teklif-iste, /usta/teklifler) ve ustanın paylaşılabilir bağlantısı.
   Araç sahibi fiyatı belirsiz iş için talep açar; bölgedeki uygun ustalar fiyat aralığı verir; araç sahibi
   karşılaştırıp beğendiğinden randevu alır. */

String fiyatAraligi(num alt, num ust) => alt == ust ? tlYaz(alt) : '${tlYaz(alt)} – ${tlYaz(ust)}';

String _talepDurumu(Map<String, dynamic> t) => t['durum'] == 'kapandi' ? 'Kapandı' : (t['bitti'] == true ? 'Süresi doldu' : 'Açık');

/// Talebin fotoğrafları (en çok 3), yan yana.
class TalepFotolari extends StatelessWidget {
  const TalepFotolari({super.key, required this.id, required this.sayi});
  final String id;
  final int sayi;
  @override
  Widget build(BuildContext context) => sayi == 0
      ? const SizedBox.shrink()
      : Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: i < sayi ? OturumFotosu('/teklif-foto/$id/$i', boy: 100, etiket: 'Fotoğraf ${i + 1}') : const SizedBox.shrink()),
          ],
        ]);
}

/* ── Araç sahibi ──────────────────────────────────────────────────────── */

class TekliflerimEkrani extends StatefulWidget {
  const TekliflerimEkrani({super.key});
  @override
  State<TekliflerimEkrani> createState() => _TekliflerimEkraniState();
}

class _TekliflerimEkraniState extends State<TekliflerimEkrani> {
  final _anahtar = GlobalKey<VeriEkraniState<(Katalog, Map<String, dynamic>)>>();

  Future<void> _yeni(BuildContext context) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const TeklifIsteEkrani()));
    _anahtar.currentState?.yenile();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          key: _anahtar,
          yenileme: const Duration(seconds: 30),
          yukle: () async => (await Katalog.al(), await Api.ben.veri('taleplerim')),
          icerik: (context, veri, yenile) {
            final (katalog, v) = veri;
            final talepler = [for (final t in v['talepler'] as List) Map<String, dynamic>.from(t)];
            return Sayfa(children: [
              const Konum(baslik: 'Tekliflerim', aciklama: 'Ustaların verdiği fiyatları karşılaştır, beğendiğinden randevu al.'),
              if (talepler.isEmpty)
                BosEkran(
                  baslik: 'Henüz teklif istemedin',
                  aciklama: 'Kaporta, boya ya da adını koyamadığın bir arıza mı var? Anlat, bölgendeki ustalar fiyat versin.',
                  eylem: 'Teklif iste',
                  onEylem: () => _yeni(context),
                )
              else ...[
                AnaDugme(etiket: 'Yeni teklif iste', simge: Icons.add, onPressed: () => _yeni(context)),
                const SizedBox(height: 16),
                Satirlar(children: [
                  for (final t in talepler)
                    Satir(
                      baslik: '${katalog.hizmetAdi(t['hizmet'])} · ${plaka(t['plaka'])}',
                      ayrinti: '${tarihKisa(t['gun'])} · ${t['ilce']} · ${_talepDurumu(t)}\n'
                          '${(t['teklifSayisi'] as num) > 0 && t['enDusuk'] != null ? '${t['teklifSayisi']} teklif · en düşük ${tlYaz(t['enDusuk'] as num)}' : 'Henüz teklif yok'}',
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => TalepEkrani(id: t['id'])));
                        yenile();
                      },
                    ),
                ]),
              ],
            ]);
          },
        ),
      );
}

class TalepEkrani extends StatelessWidget {
  const TalepEkrani({super.key, required this.id, this.yeni = false});
  final String id;
  final bool yeni;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          yenileme: const Duration(seconds: 20),
          yukle: () async => (await Katalog.al(), Map<String, dynamic>.from((await Api.ben.veri('talep', {'id': id}))['talep'])),
          icerik: (context, veri, yenile) {
            final (katalog, t) = veri;
            final teklifler = [for (final x in t['teklifler'] as List) Map<String, dynamic>.from(x)];
            final acik = t['durum'] == 'acik' && t['bitti'] != true;
            return Sayfa(children: [
              Konum(baslik: katalog.hizmetAdi(t['hizmet']), aciklama: '${plaka(t['plaka'])} · ${t['arac']} · ${t['ilce']}, ${t['il']}'),
              if (yeni) ...[
                const Uyari(tur: UyariTuru.basari, baslik: 'Talebin bölgendeki ustalara gitti.', metin: 'Teklif geldikçe sana haber veririz. Talep 7 gün açık kalır.'),
                const SizedBox(height: 16),
              ],
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${tarihKisa(t['gun'])} · ${_talepDurumu(t)}', style: Yazi.ikincil),
                  const SizedBox(height: 6),
                  Text('${t['aciklama']}', style: Yazi.govde),
                  if ((t['fotoSayisi'] as num) > 0) ...[const SizedBox(height: 12), TalepFotolari(id: t['id'], sayi: (t['fotoSayisi'] as num).toInt())],
                ]),
              ),
              Bolum(
                baslik: teklifler.isEmpty ? 'Teklifler' : '${teklifler.length} teklif',
                aciklama: teklifler.length > 1 ? 'En düşük fiyattan başlayarak.' : null,
                child: teklifler.isEmpty
                    ? Panel(child: Text(acik ? 'Henüz teklif gelmedi. Ustalar bakıp fiyat verecek; gelince haber veririz.' : 'Teklif gelmedi.', style: Yazi.govde))
                    : Column(children: [
                        for (final x in teklifler) ...[
                          Panel(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${x['ustaAdi']}', style: Yazi.govdeKalin),
                                    Text('${x['firma']} · ${x['ilce']}', style: Yazi.ikincil),
                                    if ((x['yorumSayisi'] as num) > 0) PuanSatiri(puan: x['puan'] as num, sayi: (x['yorumSayisi'] as num).toInt()),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                Flexible(child: Text(fiyatAraligi(x['altFiyat'] as num, x['ustFiyat'] as num), textAlign: TextAlign.right, style: Yazi.rakam.copyWith(fontSize: 20))),
                              ]),
                              if (x['aciklama'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('“${x['aciklama']}”', style: Yazi.govde)),
                              const SizedBox(height: 12),
                              AnaDugme(
                                etiket: 'Bu ustadan randevu al',
                                simge: Icons.arrow_forward,
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UstaDetayEkrani(slug: x['ustaSlug'], hizmet: t['hizmet']))),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SohbetEkrani(ustaSlug: x['ustaSlug'], baslik: x['ustaAdi']))),
                                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                                  label: const Text('Ustaya sor'),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ]),
              ),
              if (acik) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () async {
                    final s = await Api.ben.eylem('talep-kapat', {'id': t['id']});
                    if (!context.mounted) return;
                    bildir(context, s.hata ?? 'Talep kapatıldı. Ustalar artık teklif veremez.');
                    yenile();
                  },
                  child: const Text('Talebi kapat'),
                ),
                const SizedBox(height: 6),
                const Text('Kapatınca ustalar artık teklif veremez; gelen teklifler burada kalır.', style: Yazi.kucuk),
              ],
            ]);
          },
        ),
      );
}

class TeklifIsteEkrani extends StatefulWidget {
  const TeklifIsteEkrani({super.key});
  @override
  State<TeklifIsteEkrani> createState() => _TeklifIsteEkraniState();
}

class _TeklifIsteEkraniState extends State<TeklifIsteEkrani> {
  String? _arac, _hizmet, _il, _ilce;
  final _aciklama = TextEditingController();
  EylemSonucu? _sonuc;
  bool _bekliyor = false;

  @override
  void initState() {
    super.initState();
    _il = Oturum.ben.kullanici?.il;
    _ilce = Oturum.ben.kullanici?.ilce;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, List<Map<String, dynamic>>)>(
          yukle: () async => (await Katalog.al(), [for (final a in (await Api.ben.veri('araclarim'))['araclar'] as List) Map<String, dynamic>.from(a)]),
          icerik: (context, veri, _) {
            final (katalog, araclar) = veri;
            _arac ??= araclar.firstOrNull?['id'];
            final h = _sonuc?.alanlar ?? const {};
            return Sayfa(children: [
              const Konum(baslik: 'Teklif iste', aciklama: 'Fiyatı bilmediğin bir iş mi var? Anlat, bölgendeki ustalar fiyat versin.'),
              if (araclar.isEmpty)
                const BosEkran(baslik: 'Önce aracını ekle', aciklama: 'Ustalar hangi araç için fiyat verdiklerini bilmeli. Araçlarım sekmesinden ekleyebilirsin.')
              else ...[
                if (_sonuc?.hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 16)],
                SecimKutusu(
                  etiket: 'Hangi aracın için?',
                  simge: Icons.directions_car_outlined,
                  deger: _arac,
                  hata: h['arac'] != null,
                  gruplar: [SecenekGrubu([for (final a in araclar) Secenek(a['id'], '${a['plaka']} · ${a['markaAdi']} ${a['model']}')])],
                  onSec: (v) => setState(() => _arac = v),
                ),
                const SizedBox(height: 14),
                Alan(
                  etiket: 'Ne için teklif istiyorsun?',
                  hata: h['hizmet'],
                  child: SecimKutusu(
                    etiket: 'İş',
                    simge: Icons.build_outlined,
                    bos: 'İş seç',
                    deger: _hizmet,
                    hata: h['hizmet'] != null,
                    gruplar: [
                      for (final g in katalog.hizmetler) SecenekGrubu([Secenek(g.kod, 'Bütün ${g.ad.toLowerCase()} işleri'), for (final i in g.isler) Secenek(i.kod, i.ad)], baslik: g.ad),
                    ],
                    onSec: (v) => setState(() => _hizmet = v),
                  ),
                ),
                const SizedBox(height: 14),
                Alan(
                  etiket: 'Sorunu anlat',
                  ipucu: 'Ustalar buna bakıp fiyat verir. Örnek: Sol arka kapıda göçük var, boya da çizildi.',
                  hata: h['aciklama'],
                  child: MetinKutusu(kontrol: _aciklama, satir: 4, hata: h['aciklama'] != null),
                ),
                const SizedBox(height: 14),
                const FotoSitedeNotu(yol: '/teklif-iste', metin: 'Fotoğraflı talep için siteyi kullan. Fotoğraflı talepler daha doğru fiyat alır.'),
                const SizedBox(height: 14),
                SecimKutusu(
                  etiket: 'Aracın hangi ilde?',
                  simge: Icons.place_outlined,
                  deger: _il,
                  gruplar: [SecenekGrubu([for (final il in katalog.iller.keys) Secenek(il, il)])],
                  onSec: (v) => setState(() {
                    _il = v;
                    _ilce = null;
                  }),
                ),
                const SizedBox(height: 10),
                Alan(
                  etiket: 'İlçe',
                  ipucu: 'Bu bölgedeki ustalar teklif verir.',
                  hata: h['ilce'],
                  child: SecimKutusu(
                    etiket: 'İlçe',
                    deger: _ilce,
                    bos: 'İlçe seç',
                    hata: h['ilce'] != null,
                    gruplar: [SecenekGrubu([for (final i in katalog.iller[_il] ?? const <String>[]) Secenek(i, i)])],
                    onSec: (v) => setState(() => _ilce = v),
                  ),
                ),
                const SizedBox(height: 22),
                AnaDugme(
                  etiket: 'Teklif iste',
                  bekliyor: _bekliyor,
                  onPressed: () async {
                    setState(() => _bekliyor = true);
                    final s = await Api.ben.eylem('talep-ac', {'arac': _arac, 'hizmet': _hizmet ?? '', 'aciklama': _aciklama.text, 'il': _il ?? '', 'ilce': _ilce ?? ''});
                    if (!context.mounted) return;
                    setState(() {
                      _bekliyor = false;
                      _sonuc = s;
                    });
                    final id = RegExp(r'tekliflerim/([0-9a-f-]{36})').firstMatch(s.yonlendir ?? '')?.group(1);
                    if (id != null) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TalepEkrani(id: id, yeni: true)));
                  },
                ),
                const SizedBox(height: 10),
                const Text('Talebin 7 gün açık kalır. Teklif geldikçe haber veririz; istediğin zaman kapatabilirsin.', style: Yazi.kucuk),
              ],
            ]);
          },
        ),
      );
}

/* ── Usta ─────────────────────────────────────────────────────────────── */

class UstaTaleplerEkrani extends StatelessWidget {
  const UstaTaleplerEkrani({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          yenileme: const Duration(seconds: 30),
          yukle: () async => (await Katalog.al(), await Api.ben.veri('usta-talepleri')),
          icerik: (context, veri, yenile) {
            final (katalog, v) = veri;
            final hepsi = [for (final t in v['talepler'] as List) Map<String, dynamic>.from(t)];
            final sirali = [...hepsi.where((t) => t['benimTeklif'] == null), ...hepsi.where((t) => t['benimTeklif'] != null)];
            return Sayfa(children: [
              const Konum(baslik: 'Teklif talepleri', aciklama: 'Bölgendeki araç sahipleri sorununu anlattı. Fiyat ver, müşteri seni seçsin.'),
              if (sirali.isEmpty)
                const Panel(child: Text('Şu an açık talep yok. Bölgende senin yaptığın işe uygun yeni bir talep gelince haber veririz.', style: Yazi.govde))
              else
                Satirlar(children: [
                  for (final t in sirali)
                    Satir(
                      baslik: '${katalog.hizmetAdi(t['hizmet'])} · ${t['arac']}',
                      ayrinti: '${tarihKisa(t['gun'])} · ${t['ilce']}${(t['fotoSayisi'] as num) > 0 ? ' · ${t['fotoSayisi']} fotoğraf' : ''} · ${t['teklifSayisi']} teklif verildi\n'
                          '${t['benimTeklif'] != null ? 'Senin teklifin: ${fiyatAraligi(t['benimTeklif']['alt'] as num, t['benimTeklif']['ust'] as num)}' : '“${_kisalt(t['aciklama'] as String)}”'}',
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => UstaTalepEkrani(id: t['id'])));
                        yenile();
                      },
                    ),
                ]),
            ]);
          },
        ),
      );
}

String _kisalt(String s, [int n = 90]) => s.length > n ? '${s.substring(0, n)}…' : s;

class UstaTalepEkrani extends StatefulWidget {
  const UstaTalepEkrani({super.key, required this.id});
  final String id;
  @override
  State<UstaTalepEkrani> createState() => _UstaTalepEkraniState();
}

class _UstaTalepEkraniState extends State<UstaTalepEkrani> {
  final _anahtar = GlobalKey<VeriEkraniState<(Katalog, Map<String, dynamic>)>>();
  final _alt = TextEditingController();
  final _ust = TextEditingController();
  final _aciklama = TextEditingController();
  bool _dolduruldu = false;
  EylemSonucu? _sonuc;
  bool _bekliyor = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          key: _anahtar,
          yukle: () async => (await Katalog.al(), Map<String, dynamic>.from((await Api.ben.veri('usta-talep', {'id': widget.id}))['talep'])),
          icerik: (context, veri, _) {
            final (katalog, t) = veri;
            final benim = t['benimTeklif'] == null ? null : Map<String, dynamic>.from(t['benimTeklif']);
            if (benim != null && !_dolduruldu) {
              _dolduruldu = true;
              _alt.text = '${benim['alt']}';
              _ust.text = '${benim['ust']}';
              _aciklama.text = benim['aciklama'] ?? '';
            }
            final h = _sonuc?.alanlar ?? const {};
            return Sayfa(children: [
              Konum(baslik: katalog.hizmetAdi(t['hizmet']), aciklama: '${t['arac']} · ${t['ilce']}, ${t['il']} · ${tarihKisa(t['gun'])}'),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['aciklama']}', style: Yazi.govde),
                  if ((t['fotoSayisi'] as num) > 0) ...[const SizedBox(height: 12), TalepFotolari(id: t['id'], sayi: (t['fotoSayisi'] as num).toInt())],
                  const SizedBox(height: 8),
                  Text((t['teklifSayisi'] as num) > 0 ? '${t['teklifSayisi']} usta teklif verdi.' : 'Henüz kimse teklif vermedi.', style: Yazi.ikincil),
                ]),
              ),
              Bolum(
                baslik: benim != null ? 'Teklifin' : 'Fiyat ver',
                aciklama: 'Fotoğraftan emin olamıyorsan aralığı geniş tut; kesin fiyatı aracı görünce söylersin.',
                child: Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_sonuc?.hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 12)],
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Alan(etiket: 'En az (TL)', hata: h['alt'], child: MetinKutusu(kontrol: _alt, klavye: const TextInputType.numberWithOptions(decimal: true), hata: h['alt'] != null))),
                      const SizedBox(width: 10),
                      Expanded(child: Alan(etiket: 'En çok (TL)', hata: h['ust'], child: MetinKutusu(kontrol: _ust, klavye: const TextInputType.numberWithOptions(decimal: true), hata: h['ust'] != null))),
                    ]),
                    const SizedBox(height: 12),
                    Alan(etiket: 'Not (isteğe bağlı)', ipucu: 'Örnek: Boya dahil, parça gerekirse ayrıca söylerim. 1 günde biter.', child: MetinKutusu(kontrol: _aciklama, satir: 3)),
                    const SizedBox(height: 14),
                    AnaDugme(
                      etiket: benim != null ? 'Teklifimi güncelle' : 'Teklif ver',
                      bekliyor: _bekliyor,
                      onPressed: () async {
                        setState(() => _bekliyor = true);
                        final s = await Api.ben.eylem('teklif-ver', {'talep': t['id'], 'alt': _alt.text, 'ust': _ust.text, 'aciklama': _aciklama.text});
                        if (!context.mounted) return;
                        setState(() {
                          _bekliyor = false;
                          _sonuc = s;
                        });
                        if (s.yonlendir?.contains('verildi=1') == true) {
                          bildir(context, 'Teklifin müşteriye gitti.');
                          _anahtar.currentState?.yenile();
                        }
                      },
                    ),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
}

/// Ustanın bağlantısı: WhatsApp'tan paylaş, kopyala, sitede QR afişi yazdır.
class BaglantiKarti extends StatelessWidget {
  const BaglantiKarti({super.key, required this.baglanti, required this.firma});
  final String baglanti;
  final String firma;
  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Kose.orta), border: Border.all(color: Renk.alan, width: 1.5)),
            child: SelectableText(baglanti, style: Yazi.govdeKalin),
          ),
          const SizedBox(height: 10),
          AnaDugme(
            etiket: "WhatsApp'tan paylaş",
            simge: Icons.share_outlined,
            onPressed: () => launchUrl(
              Uri.parse('https://wa.me/?text=${Uri.encodeComponent('$firma için randevunu buradan al: $baglanti')}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: baglanti));
                  if (context.mounted) bildir(context, 'Bağlantı kopyalandı.');
                },
                icon: const Icon(Icons.copy, size: 20),
                label: const Text('Kopyala'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => siteyiAc('/usta/afis'),
                icon: const Icon(Icons.qr_code_2, size: 20),
                label: const Text('QR afiş'),
              ),
            ),
          ]),
        ]),
      );
}
