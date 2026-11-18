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
import 'takip.dart';
import 'teklif.dart';
import 'dert_ekrani.dart';

/* Araç sahibi yüzü: Usta bul · Randevular · Mesajlar · Araçlarım · Hesabım.
   Girişsiz kişi yalnız usta bulma ekranını görür; randevu ya da mesaj için giriş istenir. */

/// Sekmeler arası geçiş (ör. randevu alındıktan sonra "Randevularım"a gitmek için).
final musteriSekmesi = ValueNotifier<int>(0);

class MusteriKabuk extends StatefulWidget {
  const MusteriKabuk({super.key, this.misafir = false});
  final bool misafir;
  @override
  State<MusteriKabuk> createState() => _MusteriKabukState();
}

class _MusteriKabukState extends State<MusteriKabuk> {
  @override
  void initState() {
    super.initState();
    musteriSekmesi.addListener(_degisti);
    Oturum.ben.addListener(_degisti);
  }

  @override
  void dispose() {
    musteriSekmesi.removeListener(_degisti);
    Oturum.ben.removeListener(_degisti);
    super.dispose();
  }

  void _degisti() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (widget.misafir) {
      return Scaffold(
        appBar: ustSerit(context, eylemler: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Renk.lacivert, minimumSize: const Size(0, 44)),
              onPressed: () => girisIste(context),
              child: const Text('Giriş yap'),
            ),
          ),
        ]),
        body: const UstaBulEkrani(),
      );
    }
    final i = musteriSekmesi.value;
    return Scaffold(
      appBar: ustSerit(context),
      body: IndexedStack(index: i, children: [
        const UstaBulEkrani(),
        RandevularimEkrani(key: ValueKey('r$i')),
        MesajlarEkrani(key: ValueKey('m$i')),
        AraclarimEkrani(key: ValueKey('a$i')),
        const HesabimEkrani(),
      ]),
      bottomNavigationBar: AltCubuk(
        secili: i,
        onSec: (s) => musteriSekmesi.value = s,
        sekmeler: [
          const AltSekme('Usta bul', Icons.search),
          const AltSekme('Randevular', Icons.event_available_outlined),
          AltSekme('Mesajlar', Icons.chat_bubble_outline, rozet: Oturum.ben.okunmamis),
          const AltSekme('Araçlarım', Icons.directions_car_outlined),
          const AltSekme('Hesabım', Icons.person_outline),
        ],
      ),
    );
  }
}

/* ── Usta bul ─────────────────────────────────────────────────────────── */

class UstaBulEkrani extends StatefulWidget {
  const UstaBulEkrani({super.key, this.hizmet});
  /// Başka ekrandan (soru ağacı) bir işle açılınca süzgeç o işle başlar.
  final String? hizmet;
  @override
  State<UstaBulEkrani> createState() => _UstaBulEkraniState();
}

class _UstaBulEkraniState extends State<UstaBulEkrani> {
  String? _il, _ilce; // boşsa kişinin kendi yeri (sunucu belirler)
  String _hizmet = '', _marka = '';
  String? _gun;
  int _surum = 0; // süzgeç değişince yeniden yükle

  @override
  void initState() {
    super.initState();
    _hizmet = widget.hizmet ?? '';
  }

  String? get _yer => _il == null ? null : (_ilce == null || _ilce!.isEmpty ? _il : '$_il/$_ilce');

  Future<(Katalog, Map<String, dynamic>)> _yukle() async {
    final katalog = await Katalog.al();
    final v = await Api.ben.veri('ustalar', {'yer': ?_yer, if (_hizmet.isNotEmpty) 'hizmet': _hizmet, if (_marka.isNotEmpty) 'marka': _marka});
    return (katalog, v);
  }

  @override
  Widget build(BuildContext context) => VeriEkrani<(Katalog, Map<String, dynamic>)>(
        key: ValueKey(_surum),
        yukle: _yukle,
        icerik: (context, veri, _) {
          final (katalog, v) = veri;
          final yer = (v['yer'] as String?) ?? '';
          final parcalar = yer.split('/');
          final il = _il ?? (parcalar.isNotEmpty && parcalar.first.isNotEmpty ? parcalar.first : null);
          final ilce = _il == null ? (parcalar.length > 1 ? parcalar[1] : '') : (_ilce ?? '');
          final gunler = [for (final g in v['gunler'] as List) '$g'];
          final ustalar = [for (final u in v['ustalar'] as List) Map<String, dynamic>.from(u)];
          List<String> bos(Map<String, dynamic> u, String g) => [for (final s in (u['bosSaatler'][g] as List? ?? const [])) '$s'];
          // Gün seçilmediyse boş saati olan ilk gün.
          final gun = _gun ?? gunler.firstWhere((g) => ustalar.any((u) => bos(u, g).isNotEmpty), orElse: () => gunler.first);
          final liste = ustalar.where((u) => bos(u, gun).isNotEmpty).toList()..sort((a, b) => bos(a, gun).first.compareTo(bos(b, gun).first));
          final toplam = liste.fold<int>(0, (t, u) => t + bos(u, gun).length);
          final yerMetni = il == null ? 'Yakınındaki ustalar' : (ilce.isEmpty ? '$il, bütün ilçeler' : '$ilce, $il ve çevresi');

          return Sayfa(children: [
            Konum(baslik: 'Boş saatler', aciklama: yerMetni),
            SecimKutusu(
              etiket: 'Nerede?',
              baslik: 'Hangi ilde arayalım?',
              simge: Icons.place_outlined,
              deger: il,
              gruplar: [SecenekGrubu([for (final x in katalog.iller.keys) Secenek(x, x)])],
              onSec: (x) => setState(() {
                _il = x;
                _ilce = '';
                _gun = null;
                _surum++;
              }),
            ),
            if (il != null) ...[
              const SizedBox(height: 10),
              SecimKutusu(
                etiket: 'İlçe',
                baslik: '$il ilçeleri',
                simge: Icons.map_outlined,
                deger: ilce,
                gruplar: [SecenekGrubu([Secenek('', '$il, bütün ilçeler'), for (final x in katalog.iller[il] ?? const <String>[]) Secenek(x, x)])],
                onSec: (x) => setState(() {
                  _il = il;
                  _ilce = x;
                  _gun = null;
                  _surum++;
                }),
              ),
            ],
            const SizedBox(height: 10),
            SecimKutusu(
              etiket: 'Ne için?',
              baslik: 'Ne için gideceksin?',
              simge: Icons.build_outlined,
              deger: _hizmet,
              gruplar: [
                const SecenekGrubu([Secenek('', 'Bütün hizmetler')]),
                for (final g in katalog.hizmetler) SecenekGrubu([Secenek(g.kod, '${g.ad} (hepsi)'), for (final i in g.isler) Secenek(i.kod, i.ad)], baslik: g.ad),
              ],
              onSec: (x) => setState(() {
                _hizmet = x;
                _surum++;
              }),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DertEkrani())),
                icon: const Icon(Icons.help_outline),
                label: const Text('Ne olduğunu bilmiyor musun? Birkaç soruyla bulalım'),
              ),
            ),
            const SizedBox(height: 4),
            SecimKutusu(
              etiket: 'Araç markası',
              baslik: 'Aracının markası',
              simge: Icons.directions_car_outlined,
              deger: _marka,
              gruplar: [
                const SecenekGrubu([Secenek('', 'Bütün markalar')]),
                SecenekGrubu([for (final m in katalog.markalar) Secenek(m.kod, m.ad)]),
              ],
              onSec: (x) => setState(() {
                _marka = x;
                _surum++;
              }),
            ),
            const SizedBox(height: 16),
            GunSekmeleri(
              gunler: gunler,
              secili: gun,
              alt: (g) => '${ustalar.where((u) => bos(u, g).isNotEmpty).length} usta',
              onSec: (g) => setState(() => _gun = g),
            ),
            const SizedBox(height: 20),
            if (liste.isEmpty)
              BosEkran(
                baslik: '${gunEtiketi(gun)} boş saat bulunamadı',
                aciklama: ustalar.isEmpty
                    ? (_hizmet.isNotEmpty || _marka.isNotEmpty
                        ? 'Bu süzgece uyan usta yok. Hizmeti ve markayı “Bütün” yaparsan daha çok usta görürsün.'
                        : 'Bu bölgede henüz usta yok. İlçe kutusundan ilin bütün ilçelerine bakabilirsin.')
                    : 'Başka bir güne bak ya da süzgeci değiştir.',
              )
            else ...[
              Text('${gunVeTarih(gun)} · ${liste.length} usta, $toplam boş saat', style: Yazi.ikincil.copyWith(fontSize: 17, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Satirlar(children: [
                for (final u in liste)
                  Satir(
                    sol: BuyukSaat(bos(u, gun).first),
                    baslik: u['ad'],
                    ayrinti: [u['firma'], u['ilce'], if (u['uzaklikKm'] != null && ilce.isNotEmpty) '${ondalik(u['uzaklikKm'])} km'].join(' · '),
                    alt: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      PuanSatiri(puan: u['puan'] as num, sayi: (u['yorumSayisi'] as num).toInt()),
                      const SizedBox(height: 6),
                      _SaatSeridi(saatler: bos(u, gun)),
                    ]),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UstaDetayEkrani(slug: u['slug'], gun: gun, hizmet: _hizmet))),
                  ),
              ]),
            ],
          ]);
        },
      );
}

/// Bir ustanın o günkü ilk birkaç boş saati (küçük kapsüller).
class _SaatSeridi extends StatelessWidget {
  const _SaatSeridi({required this.saatler});
  final List<String> saatler;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in saatler.take(4))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Kose.kucuk), border: Border.all(color: Renk.cizgi)),
            child: Text(s, style: Yazi.rakam.copyWith(fontSize: 15)),
          ),
        if (saatler.length > 4) Padding(padding: const EdgeInsets.only(top: 3), child: Text('+${saatler.length - 4}', style: Yazi.kucuk)),
      ]);
}

/* ── Usta sayfası ─────────────────────────────────────────────────────── */

class UstaDetayEkrani extends StatefulWidget {
  const UstaDetayEkrani({super.key, required this.slug, this.gun, this.hizmet = ''});
  final String slug;
  final String? gun;
  final String hizmet;
  @override
  State<UstaDetayEkrani> createState() => _UstaDetayEkraniState();
}

class _UstaDetayEkraniState extends State<UstaDetayEkrani> {
  String? _gun, _saat;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          yukle: () async => (await Katalog.al(), await Api.ben.veri('usta', {'slug': widget.slug})),
          icerik: (context, veri, _) {
            final (katalog, u) = veri;
            final gunler = [for (final g in u['gunler'] as List) '$g'];
            List<String> bos(String g) => [for (final s in (u['bosSaatler'][g] as List? ?? const [])) '$s'];
            final gun = _gun ?? (gunler.contains(widget.gun) ? widget.gun! : gunler.firstWhere((g) => bos(g).isNotEmpty, orElse: () => gunler.first));
            final saatler = bos(gun);
            final saat = saatler.contains(_saat) ? _saat : (saatler.isEmpty ? null : saatler.first);
            final markalar = u['markalar'];
            final yorumlar = [for (final y in u['yorumlar'] as List) Map<String, dynamic>.from(y)];
            final program = [for (final p in u['program'] as List) Map<String, dynamic>.from(p)];

            return Sayfa(children: [
              Konum(baslik: u['ad'], aciklama: '${u['firma']} · ${u['ilce']}, ${u['il']}'),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PuanSatiri(puan: u['puan'] as num, sayi: (u['yorumSayisi'] as num).toInt()),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.place_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${u['adres']}${u['uzaklikKm'] != null ? ' · ${ondalik(u['uzaklikKm'])} km' : ''}', style: Yazi.govde)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(u['yolTarifi']), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.navigation_outlined, size: 20),
                      label: const Text('Yol tarifi al'),
                    ),
                    if (u['harita'] != null)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(u['harita']), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_new, size: 20),
                        label: const Text('Haritada aç'),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final k in u['uzmanliklar'] as List)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                        child: Text(katalog.hizmetAdi('$k'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                  ]),
                  const Divider(height: 28),
                  Row(children: [
                    const Icon(Icons.directions_car_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        markalar == 'hepsi' ? 'Bütün markalara bakıyor' : 'Baktığı markalar: ${[for (final m in markalar as List) katalog.markaAdi('$m')].join(', ')}',
                        style: Yazi.govdeKalin.copyWith(fontSize: 16),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  if (!await girisIste(context) || !context.mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SohbetEkrani(ustaSlug: widget.slug, baslik: u['ad'])));
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                label: const Text('Ustaya mesaj yaz'),
              ),
              Bolum(
                baslik: 'Boş saatler',
                aciklama: 'Bir gün, sonra bir saat seç.',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GunSekmeleri(gunler: gunler, secili: gun, alt: (g) => '${bos(g).length} boş', onSec: (g) => setState(() => _gun = g)),
                  const SizedBox(height: 16),
                  Text(gunVeTarih(gun), style: Yazi.govdeKalin),
                  const SizedBox(height: 10),
                  if (saatler.isEmpty) ...[
                    const Text('Bu gün boş saat yok. Başka bir gün seç ya da bu gün bir saat boşalınca haber al.', style: Yazi.govde),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        if (!await girisIste(context) || !context.mounted) return;
                        if (Oturum.ben.kullanici?.rol != 'musteri') return bildir(context, 'Bekleme listesine araç sahibi hesabıyla girebilirsin.');
                        final s = await Api.ben.eylem('bekleme-gir', {'slug': widget.slug, 'gun': gun, 'arac': '', 'hizmet': widget.hizmet});
                        if (!context.mounted) return;
                        bildir(context, s.yonlendir?.contains('bekleme=1') == true ? 'Tamam, bu gün boşalınca haber vereceğiz.' : (s.hata ?? 'Kaydedilemedi. Yeniden dene.'));
                      },
                      child: const Text('Bu gün boşalınca haber ver'),
                    ),
                  ]
                  else ...[
                    SaatIzgarasi(saatler: saatler, secili: saat, onSec: (s) => setState(() => _saat = s)),
                    const SizedBox(height: 16),
                    AnaDugme(
                      etiket: 'Bu saatle randevu al',
                      simge: Icons.arrow_forward,
                      onPressed: () async {
                        if (!await girisIste(context) || !context.mounted) return;
                        if (Oturum.ben.kullanici?.rol != 'musteri') return bildir(context, 'Randevuyu araç sahibi hesabıyla alabilirsin.');
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RandevuAlEkrani(slug: widget.slug, gun: gun, saat: saat, hizmet: widget.hizmet)));
                      },
                    ),
                  ],
                ]),
              ),
              Bolum(
                baslik: 'Çalışma saatleri',
                child: Satirlar(children: [
                  for (var i = 0; i < program.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        SizedBox(width: 110, child: Text(const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][i], style: Yazi.govdeKalin)),
                        Expanded(
                          child: Text(
                            program[i]['acik'] == true ? [for (final a in program[i]['araliklar'] as List) '${a['bas']}–${a['bit']}'].join(', ') : 'Kapalı',
                            style: program[i]['acik'] == true ? Yazi.rakam.copyWith(fontSize: 16, fontWeight: FontWeight.w500) : Yazi.ikincil,
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
              Bolum(
                baslik: 'Değerlendirmeler',
                child: yorumlar.isEmpty
                    ? const Panel(child: Text('Bu ustaya henüz yorum yazılmadı.', style: Yazi.govde))
                    : Satirlar(children: [
                        for (final y in yorumlar)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                for (var i = 1; i <= 5; i++) Icon(i <= (y['puan'] as num) ? Icons.star : Icons.star_border, size: 17, color: Renk.lacivert),
                                const SizedBox(width: 8),
                                Text('${y['musteri']} · ${tarihKisa(y['tarih'])}', style: Yazi.kucuk),
                              ]),
                              const SizedBox(height: 4),
                              Text('${y['metin']}', style: Yazi.govde),
                            ]),
                          ),
                      ]),
              ),
            ]);
          },
        ),
      );
}

/* ── Randevu al: araç ve iş → gün ve saat → özet → kod → tamam ───────── */

class RandevuAlEkrani extends StatefulWidget {
  const RandevuAlEkrani({super.key, required this.slug, this.gun, this.saat, this.hizmet = ''});
  final String slug;
  final String? gun, saat;
  final String hizmet;
  @override
  State<RandevuAlEkrani> createState() => _RandevuAlEkraniState();
}

class _RandevuAlEkraniState extends State<RandevuAlEkrani> {
  int _adim = 1;
  Katalog? _katalog;
  Map<String, dynamic>? _usta;
  List<Map<String, dynamic>> _araclar = [];
  String? _arac, _hizmet, _gun, _saat, _k;
  final _not = TextEditingController();
  final _kod = TextEditingController();
  Map<String, dynamic>? _kodBilgisi;
  String? _hata, _uyari;
  bool _yukleniyor = true, _bekliyor = false;

  @override
  void initState() {
    super.initState();
    _gun = widget.gun;
    _saat = widget.saat;
    _ilkYukleme();
  }

  Future<void> _ilkYukleme() async {
    try {
      final katalog = await Katalog.al();
      final araclar = await Api.ben.veri('araclarim');
      final usta = await Api.ben.veri('usta', {'slug': widget.slug});
      _katalog = katalog;
      _araclar = [for (final a in araclar['araclar'] as List) Map<String, dynamic>.from(a)];
      _usta = usta;
      final uygun = _araclar.where(_bakar).toList();
      _arac = uygun.isEmpty ? null : uygun.first['id'];
      final uzm = [for (final x in usta['uzmanliklar'] as List) '$x'];
      final istenen = katalog.grubuBul(widget.hizmet);
      _hizmet = istenen != null && uzm.contains(istenen.kod) && widget.hizmet != istenen.kod
          ? widget.hizmet
          : (uzm.isEmpty ? null : katalog.grubuBul(uzm.first)?.isler.first.kod);
    } on ApiHatasi catch (e) {
      _hata = e.mesaj;
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  bool _bakar(Map<String, dynamic> a) => _usta?['markalar'] == 'hepsi' || (_usta?['markalar'] as List? ?? const []).contains(a['marka']);

  /// Seçilen işin süresiyle saatleri yeniden al (usta o iş için ayrı süre girmiş olabilir).
  Future<void> _saatleriYukle() async {
    setState(() => _yukleniyor = true);
    try {
      _usta = await Api.ben.veri('usta', {'slug': widget.slug, 'hizmet': _hizmet ?? ''});
    } on ApiHatasi catch (e) {
      _hata = e.mesaj;
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  List<String> _bos(String g) => [for (final s in (_usta?['bosSaatler'][g] as List? ?? const [])) '$s'];

  Future<void> _kodIste() async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final s = await Api.ben.eylem('randevu-kod', {'slug': widget.slug, 'arac': _arac, 'hizmet': _hizmet, 'gun': _gun, 'saat': _saat, 'not': _not.text});
    await _sonucuIsle(s);
  }

  Future<void> _onayla() async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final s = await Api.ben.eylem('randevu-onayla', {'k': _k, 'kod': _kod.text});
    await _sonucuIsle(s);
  }

  Future<void> _kodTekrar() async {
    final s = await Api.ben.eylem('randevu-kod-tekrar', {'k': _k});
    await _sonucuIsle(s, yeniKod: true);
  }

  /// Sitedeki yönlendirmeler: adim=kod (kod gönderildi), adim=tamam (talep oluştu), adim=2&hata=1 (saat doldu).
  Future<void> _sonucuIsle(EylemSonucu s, {bool yeniKod = false}) async {
    if (!mounted) return;
    setState(() => _bekliyor = false);
    final adim = s.parametre('adim');
    if (adim == 'kod') {
      _k = s.parametre('k');
      _kod.clear();
      try {
        _kodBilgisi = await Api.ben.veri('kod', {'k': _k!});
      } on ApiHatasi {
        _kodBilgisi = null;
      }
      setState(() {
        _adim = 4;
        _uyari = yeniKod ? 'Yeni kodu gönderdik. Gelen son kodu yaz.' : null;
      });
    } else if (adim == 'tamam') {
      setState(() => _adim = 5);
    } else if (adim == '2') {
      _uyari = 'Bu saat az önce doldu. Başka biri senden önce aldı; başka bir saat seç.';
      _saat = null;
      _adim = 2;
      await _saatleriYukle();
    } else if (s.hata != null) {
      setState(() => _hata = s.hata);
    }
  }

  void _geri() {
    if (_adim > 1 && _adim < 5) {
      setState(() {
        _adim = _adim == 4 ? 3 : _adim - 1;
        _hata = null;
        _uyari = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _adim == 1 || _adim == 5,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _geri();
        },
        child: Scaffold(appBar: ustSerit(context), body: _yukleniyor ? const Iskelet() : _govde()),
      );

  Widget _govde() {
    final usta = _usta;
    final katalog = _katalog;
    if (usta == null || katalog == null) {
      return Sayfa(children: [const SizedBox(height: 16), Uyari(tur: UyariTuru.hata, baslik: 'Sayfa açılamadı.', metin: _hata)]);
    }
    final ust = Konum(baslik: _adim == 5 ? 'Talebin ustaya gitti' : usta['ad'], aciklama: _adim == 5 ? null : 'Adım ${_adim.clamp(1, 4)} / 4 · ${const ['', 'Araç ve iş', 'Gün ve saat', 'Özet', 'Kod'][_adim.clamp(1, 4)]}');
    final uyarilar = [
      if (_uyari != null) ...[Uyari(tur: _adim == 4 ? UyariTuru.basari : UyariTuru.hata, baslik: _uyari!), const SizedBox(height: 16)],
      if (_hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _hata!), const SizedBox(height: 16)],
    ];

    switch (_adim) {
      case 1:
        final uzm = [for (final x in usta['uzmanliklar'] as List) '$x'];
        return Sayfa(children: [
          ust,
          ...uyarilar,
          const Text('Hangi aracın için?', style: Yazi.govdeKalin),
          const SizedBox(height: 8),
          if (_araclar.isEmpty)
            BosEkran(
              baslik: 'Önce aracını ekle',
              aciklama: 'Randevu almak için en az bir aracın kayıtlı olmalı.',
              eylem: 'Araç ekle',
              onEylem: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AracEkleEkrani()));
                setState(() => _yukleniyor = true);
                await _ilkYukleme();
              },
            )
          else
            for (final a in _araclar) ...[
              SecimDugmesi(
                secili: _arac == a['id'],
                yukseklik: 64,
                onTap: _bakar(a) ? () => setState(() => _arac = a['id']) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('${a['markaAdi']} ${a['model']}', style: Yazi.govdeKalin.copyWith(color: _bakar(a) ? Renk.lacivert : Renk.murekkep2)),
                        Text(_bakar(a) ? '${a['plaka']}' : '${a['plaka']} · Bu usta ${a['markaAdi']} markasına bakmıyor', style: Yazi.kucuk),
                      ]),
                    ),
                    if (_arac == a['id']) const Icon(Icons.check_circle, color: Renk.secili),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 12),
          Alan(
            etiket: 'Ne yaptıracaksın?',
            child: SecimKutusu(
              etiket: 'Yapılacak iş',
              baslik: 'Ne yaptıracaksın?',
              deger: _hizmet,
              gruplar: [
                for (final g in katalog.hizmetler.where((g) => uzm.contains(g.kod))) SecenekGrubu([for (final i in g.isler) Secenek(i.kod, i.ad)], baslik: g.ad),
              ],
              onSec: (x) => setState(() => _hizmet = x),
            ),
          ),
          const SizedBox(height: 24),
          AnaDugme(
            etiket: 'Devam et',
            simge: Icons.arrow_forward,
            onPressed: _arac == null || _hizmet == null
                ? null
                : () async {
                    setState(() => _adim = 2);
                    await _saatleriYukle();
                  },
          ),
        ]);

      case 2:
        final gunler = [for (final g in usta['gunler'] as List) '$g'];
        final gun = gunler.contains(_gun) ? _gun! : gunler.firstWhere((g) => _bos(g).isNotEmpty, orElse: () => gunler.first);
        final saatler = _bos(gun);
        final saat = saatler.contains(_saat) ? _saat : null;
        return Sayfa(children: [
          ust,
          ...uyarilar,
          GunSekmeleri(gunler: gunler, secili: gun, alt: (g) => '${_bos(g).length} boş', onSec: (g) => setState(() => _gun = g)),
          const SizedBox(height: 16),
          Text('Saat (${sureYaz((usta['sure'] as num).toInt())}lik randevu)', style: Yazi.ikincil.copyWith(fontSize: 17)),
          const SizedBox(height: 10),
          if (saatler.isEmpty)
            const Text('Bu gün boş saat yok. Başka bir güne bak.', style: Yazi.govde)
          else
            SaatIzgarasi(
              saatler: saatler,
              secili: saat,
              onSec: (s) => setState(() {
                _gun = gun;
                _saat = s;
              }),
            ),
          const SizedBox(height: 24),
          AnaDugme(
            etiket: 'Devam et',
            simge: Icons.arrow_forward,
            onPressed: saat == null
                ? null
                : () => setState(() {
                      _gun = gun;
                      _adim = 3;
                      _uyari = null;
                    }),
          ),
        ]);

      case 3:
        final arac = _araclar.firstWhere((a) => a['id'] == _arac);
        return Sayfa(children: [
          ust,
          ...uyarilar,
          Satirlar(children: [
            _bilgi('Gün ve saat', '${gunVeTarih(_gun!)} · $_saat'),
            _bilgi('Usta', '${usta['ad']} · ${usta['firma']}'),
            _bilgi('Araç ve iş', '${plaka(arac['plaka'])} · ${katalog.hizmetAdi(_hizmet!)}'),
          ]),
          const SizedBox(height: 18),
          Alan(
            etiket: 'Ustaya not (isteğe bağlı)',
            ipucu: 'Örnek: Sabah çalıştırırken ses geliyor.',
            child: MetinKutusu(kontrol: _not, satir: 3),
          ),
          const SizedBox(height: 12),
          const Text('Talebi gönderince sana bir doğrulama kodu yollarız; kodu yazınca talep ustaya gider.', style: Yazi.ikincil),
          const SizedBox(height: 18),
          AnaDugme(etiket: 'Randevu talebini gönder', bekliyor: _bekliyor, onPressed: _kodIste),
        ]);

      case 4:
        final kb = _kodBilgisi;
        return Sayfa(children: [
          ust,
          ...uyarilar,
          Text(
            kb == null
                ? 'Sana 6 haneli bir kod gönderdik.'
                : '${kb['hedef']} ${kb['kanal'] == 'sms' ? 'numarasına SMS ile' : 'adresine e-postayla'} 6 haneli bir kod gönderdik. Kodu yazınca talebin ustaya gider.',
            style: Yazi.govde,
          ),
          const SizedBox(height: 8),
          const Text('Kod 10 dakika geçerli. Bu sürede saat senin adına tutuluyor; başkası alamaz.', style: Yazi.ikincil),
          const SizedBox(height: 16),
          if (kb?['testKodu'] != null) ...[
            Panel(child: Row(children: [
              const Expanded(child: Text('Test modu: ileti gerçekten gönderilmedi. Kodun:', style: Yazi.ikincil)),
              Text('${kb!['testKodu']}', style: Yazi.rakam.copyWith(fontSize: 24)),
            ])),
            const SizedBox(height: 16),
          ],
          Alan(
            etiket: '6 haneli kod',
            child: TextField(
              controller: _kod,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: Yazi.rakam.copyWith(fontSize: 28, letterSpacing: 8),
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          const SizedBox(height: 20),
          AnaDugme(etiket: 'Randevuyu onayla', bekliyor: _bekliyor, onPressed: _onayla),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _kodTekrar, child: const Text('Yeni kod gönder'))),
        ]);

      default:
        return Sayfa(children: [
          ust,
          Uyari(tur: UyariTuru.basari, baslik: 'Randevu talebin gönderildi.', metin: '${usta['ad']} onaylayınca sana haber veririz. O zamana kadar talebin “Onay bekliyor” görünür.'),
          const SizedBox(height: 16),
          Satirlar(children: [
            _bilgi('Gün ve saat', '${gunVeTarih(_gun!)} · $_saat'),
            _bilgi('Usta', '${usta['ad']} · ${usta['firma']}'),
          ]),
          const SizedBox(height: 20),
          AnaDugme(
            etiket: 'Randevularıma git',
            simge: Icons.arrow_forward,
            onPressed: () {
              musteriSekmesi.value = 1;
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
        ]);
    }
  }

  Widget _bilgi(String etiket, String deger) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiket, style: Yazi.ikincil),
          const SizedBox(height: 2),
          Text(deger, style: Yazi.govdeKalin),
        ]),
      );
}

/* ── Randevularım ─────────────────────────────────────────────────────── */

class RandevularimEkrani extends StatelessWidget {
  const RandevularimEkrani({super.key});

  @override
  Widget build(BuildContext context) => VeriEkrani<(Katalog, Map<String, dynamic>)>(
        yenileme: const Duration(seconds: 20),
        yukle: () async => (await Katalog.al(), await Api.ben.veri('randevularim')),
        icerik: (context, veri, yenile) {
          final (katalog, v) = veri;
          final bugun = v['bugun'] as String;
          final hepsi = [for (final r in v['randevular'] as List) Map<String, dynamic>.from(r)];
          final hatirlatmalar = [for (final h in (v['hatirlatmalar'] as List? ?? const [])) Map<String, dynamic>.from(h)];
          final beklemeler = [for (final b in (v['beklemeler'] as List? ?? const [])) Map<String, dynamic>.from(b)];
          final yaklasan = hepsi.where((r) => (r['gun'] as String).compareTo(bugun) >= 0 && (r['durum'] == 'bekliyor' || r['durum'] == 'onaylandi')).toList()
            ..sort((a, b) => '${a['gun']} ${a['saat']}'.compareTo('${b['gun']} ${b['saat']}'));
          final gecmis = hepsi.where((r) => !yaklasan.contains(r)).toList();

          Widget kart(Map<String, dynamic> r) {
            final durum = katalog.isDurumu(r['isDurumu']);
            final bekleyen = (r['bekleyenTeklif'] as num? ?? 0) > 0;
            return Satir(
              sol: BuyukSaat(r['saat']),
              baslik: r['ustaAdi'],
              ayrinti: '${gunVeTarih(r['gun'])} · ${katalog.hizmetAdi(r['hizmet'])} · ${plaka(r['plaka'])}',
              alt: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                DurumRozeti(r['durum']),
                if (durum != null && r['durum'] == 'onaylandi') Padding(padding: const EdgeInsets.only(top: 4), child: Text('Aracın: ${durum.kisa}', style: Yazi.govdeKalin)),
                if (bekleyen) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Ek iş onayın bekleniyor', style: Yazi.govdeKalin.copyWith(color: Renk.bekle))),
              ]),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => RandevuTakipEkrani(id: r['id'])));
                yenile();
              },
            );
          }

          return Sayfa(children: [
            const Konum(baslik: 'Randevularım'),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TekliflerimEkrani())),
              icon: const Icon(Icons.request_quote_outlined),
              label: const Text('Fiyat teklifi iste'),
            ),
            const SizedBox(height: 16),
            for (final h in hatirlatmalar) ...[
              _HatirlatmaKarti(h: h, tur: katalog.hatirlatici(h['tur'])),
              const SizedBox(height: 8),
            ],
            for (final b in beklemeler) ...[
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${b['ustaAdi']} · ${gunVeTarih(b['gun'])}', style: Yazi.govdeKalin),
                  Text(b['bildirildi'] == true ? 'Boş saat açıldı, haber verdik.' : 'Bu gün boşalınca haber vereceğiz.', style: Yazi.ikincil),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UstaDetayEkrani(slug: b['ustaSlug'], gun: b['gun']))),
                        child: const Text('Saatlere bak'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        await Api.ben.eylem('bekleme-cik', {'id': b['id']});
                        if (context.mounted) bildir(context, 'Bekleme kaldırıldı.');
                        yenile();
                      },
                      child: const Text('Vazgeç'),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            if (hatirlatmalar.isNotEmpty || beklemeler.isNotEmpty) const SizedBox(height: 8),
            if (hepsi.isEmpty)
              BosEkran(
                baslik: 'Henüz randevun yok',
                aciklama: 'Yakınındaki ustaların boş saatlerine bak. Birini seçmen yeter, usta onaylayınca sana haber veririz.',
                eylem: 'Usta bul',
                onEylem: () => musteriSekmesi.value = 0,
              ),
            if (yaklasan.isNotEmpty) ...[Text('Yaklaşan', style: Yazi.bolum.copyWith(fontSize: 20)), const SizedBox(height: 10), Satirlar(children: [for (final r in yaklasan) kart(r)])],
            if (gecmis.isNotEmpty) Bolum(baslik: 'Geçmiş', child: Satirlar(children: [for (final r in gecmis) kart(r)])),
          ]);
        },
      );
}

/// Yaklaşan hatırlatma (muayene, sigorta, …): mor zeminli kart; o işe bakan ustalar varsa "Boş saatlere bak".
class _HatirlatmaKarti extends StatelessWidget {
  const _HatirlatmaKarti({required this.h, required this.tur});
  final Map<String, dynamic> h;
  final HatirlaticiTuru? tur;
  @override
  Widget build(BuildContext context) => Panel(
        renk: Renk.bekleZemin,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${tur?.ad ?? h['tur']}: ${gunVeTarih(h['tarih'])}', style: Yazi.govdeKalin.copyWith(color: Renk.bekle)),
          Text('${plaka(h['plaka'])} · ${tur?.oneri ?? ''}', style: Yazi.govde),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              if (tur?.hizmet != null) {
                musteriSekmesi.value = 0;
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AracEkrani(aracId: h['aracId'])));
              }
            },
            child: Text(tur?.hizmet != null ? 'Ustalara bak' : 'Tarihi güncelle'),
          ),
        ]),
      );
}

/// Evet/hayır sorusu (geri alınamayan işlemden önce).
Future<bool> onaySor(BuildContext context, String baslik, String metin, String evet) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Kose.pano)),
        title: Text(baslik, style: Yazi.bolum),
        content: Text(metin, style: Yazi.govde),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Renk.hayir), onPressed: () => Navigator.pop(c, true), child: Text(evet)),
        ],
      ),
    ) ??
    false;

/// Tamamlanan randevuyu puanla: yıldız (zorunlu) ve isteğe bağlı yorum.
class PuanlaEkrani extends StatefulWidget {
  const PuanlaEkrani({super.key, required this.randevu});
  final Map<String, dynamic> randevu;
  @override
  State<PuanlaEkrani> createState() => _PuanlaEkraniState();
}

class _PuanlaEkraniState extends State<PuanlaEkrani> {
  int _puan = 0;
  final _yorum = TextEditingController();
  final _odenen = TextEditingController();
  String? _fiyat;
  EylemSonucu? _sonuc;
  bool _bekliyor = false;
  static const _anlam = ['', 'Çok kötü', 'Kötü', 'İdare eder', 'İyi', 'Çok iyi'];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: Sayfa(children: [
          Konum(baslik: 'Ustayı puanla', aciklama: '${widget.randevu['ustaAdi']} · ${gunVeTarih(widget.randevu['gun'])}'),
          if (_sonuc?.hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 16)],
          const Text('Kaç yıldız?', style: Yazi.govdeKalin),
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 1; i <= 5; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: SecimDugmesi(
                  secili: _puan == i,
                  onTap: () => setState(() => _puan = i),
                  child: Icon(i <= _puan ? Icons.star : Icons.star_border, color: Renk.lacivert, size: 28),
                ),
              ),
            ],
          ]),
          if (_puan > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_anlam[_puan], style: Yazi.govdeKalin)),
          const SizedBox(height: 18),
          FutureBuilder<Katalog>(
            future: Katalog.al(),
            builder: (context, k) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Usta işe başlamadan söylediği fiyat tuttu mu? (isteğe bağlı)', style: Yazi.govdeKalin),
              const SizedBox(height: 8),
              for (final (d, e) in k.data?.fiyatUydu ?? const <(String, String)>[]) ...[
                SecimDugmesi(
                  secili: _fiyat == d,
                  onTap: () => setState(() => _fiyat = _fiyat == d ? null : d),
                  child: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(e, style: Yazi.govde))),
                ),
                const SizedBox(height: 8),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          Alan(
            etiket: 'Toplam ne kadar ödedin? (isteğe bağlı)',
            ipucu: 'TL olarak. Ustalara gösterilmez; bölgedeki fiyatları hesaplamak için kullanılır.',
            hata: _sonuc?.alanlar['odenen'],
            child: MetinKutusu(kontrol: _odenen, klavye: const TextInputType.numberWithOptions(decimal: true), hata: _sonuc?.alanlar['odenen'] != null),
          ),
          const SizedBox(height: 18),
          Alan(
            etiket: 'Yorum (isteğe bağlı)',
            ipucu: 'Diğer araç sahipleri görür. Telefon numarası yazma.',
            hata: _sonuc?.alanlar['yorum'],
            child: MetinKutusu(kontrol: _yorum, satir: 4),
          ),
          const SizedBox(height: 22),
          AnaDugme(
            etiket: 'Puanı gönder',
            bekliyor: _bekliyor,
            onPressed: () async {
              setState(() => _bekliyor = true);
              final s = await Api.ben.eylem('degerlendir', {
                'randevu': widget.randevu['id'],
                'puan': '$_puan',
                'yorum': _yorum.text,
                'odenen': _odenen.text,
                'fiyat': ?_fiyat,
              });
              if (!context.mounted) return;
              setState(() {
                _sonuc = s;
                _bekliyor = false;
              });
              if (s.tamam) {
                bildir(context, 'Puanın kaydedildi. Teşekkürler.');
                Navigator.pop(context);
              }
            },
          ),
        ]),
      );
}

/* ── Araçlarım ────────────────────────────────────────────────────────── */

class AraclarimEkrani extends StatelessWidget {
  const AraclarimEkrani({super.key});
  @override
  Widget build(BuildContext context) => VeriEkrani<Map<String, dynamic>>(
        yukle: () => Api.ben.veri('araclarim'),
        icerik: (context, v, yenile) {
          final araclar = [for (final a in v['araclar'] as List) Map<String, dynamic>.from(a)];
          return Sayfa(children: [
            const Konum(baslik: 'Araçlarım'),
            if (araclar.isEmpty)
              const BosEkran(baslik: 'Henüz aracın yok', aciklama: 'Aracını ekle: ustalar aracına bakıyor mu görürsün, muayene ve sigorta tarihlerini hatırlatırız.')
            else
              Satirlar(children: [
                for (final a in araclar)
                  Satir(
                    baslik: '${a['plaka']}',
                    ayrinti: [ '${a['markaAdi']} ${a['model']}', if (a['yil'] != null) '${a['yil']}', if (a['yakit'] != null) '${a['yakit']}'].join(' · '),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => AracEkrani(aracId: a['id'])));
                      yenile();
                    },
                  ),
              ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AracEkleEkrani()));
                yenile();
              },
              icon: const Icon(Icons.add),
              label: const Text('Araç ekle'),
            ),
          ]);
        },
      );
}

/// Araç ekleme ve düzenleme (arac verilirse düzenleme; silme de buradan).
class AracEkleEkrani extends StatefulWidget {
  const AracEkleEkrani({super.key, this.arac});
  final Map<String, dynamic>? arac;
  @override
  State<AracEkleEkrani> createState() => _AracEkleEkraniState();
}

class _AracEkleEkraniState extends State<AracEkleEkrani> {
  late String? _marka = widget.arac?['marka'];
  late String? _model = widget.arac?['model'];
  late String? _yil = widget.arac?['yil']?.toString();
  late String? _yakit = widget.arac?['yakit'];
  late final _plaka = TextEditingController(text: widget.arac?['plaka'] ?? '');
  EylemSonucu? _sonuc;
  bool _bekliyor = false;

  Future<void> _kaydet() async {
    setState(() => _bekliyor = true);
    final s = await Api.ben.eylem('arac-kaydet', {
      if (widget.arac != null) 'id': widget.arac!['id'],
      'marka': _marka ?? '',
      'model': _model ?? '',
      'yil': _yil ?? '',
      'yakit': _yakit ?? '',
      'plaka': _plaka.text,
    });
    if (!mounted) return;
    setState(() {
      _sonuc = s;
      _bekliyor = false;
    });
    if (s.tamam) {
      bildir(context, widget.arac == null ? 'Aracın kaydedildi.' : 'Aracın güncellendi.');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _sonuc?.alanlar ?? {};
    final buYil = DateTime.now().year;
    return Scaffold(
      appBar: ustSerit(context),
      body: VeriEkrani<Katalog>(
        yukle: Katalog.al,
        icerik: (context, katalog, _) {
          final marka = katalog.markalar.where((m) => m.kod == _marka).firstOrNull;
          return Sayfa(children: [
            Konum(baslik: widget.arac == null ? 'Araç ekle' : 'Aracı düzenle'),
            if (_sonuc?.hata != null && !_sonuc!.tamam) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 16)],
            Alan(
              etiket: 'Marka',
              hata: h['marka'],
              child: SecimKutusu(
                etiket: 'Marka',
                bos: 'Marka seç',
                deger: _marka,
                hata: h['marka'] != null,
                gruplar: [SecenekGrubu([for (final m in katalog.markalar) Secenek(m.kod, m.ad)])],
                onSec: (x) => setState(() {
                  _marka = x;
                  _model = null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            Alan(
              etiket: 'Model',
              hata: h['model'],
              child: SecimKutusu(
                etiket: 'Model',
                bos: marka == null ? 'Önce markayı seç' : 'Model seç',
                deger: _model,
                hata: h['model'] != null,
                gruplar: [SecenekGrubu([for (final m in marka?.modeller ?? const <String>[]) Secenek(m, m)])],
                onSec: (x) => setState(() => _model = x),
              ),
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Alan(
                  etiket: 'Model yılı',
                  hata: h['yil'],
                  child: SecimKutusu(
                    etiket: 'Yıl',
                    deger: _yil,
                    hata: h['yil'] != null,
                    gruplar: [SecenekGrubu([for (var y = buYil + 1; y >= 1970; y--) Secenek('$y', '$y')])],
                    onSec: (x) => setState(() => _yil = x),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Alan(
                  etiket: 'Yakıt',
                  hata: h['yakit'],
                  child: SecimKutusu(
                    etiket: 'Yakıt',
                    deger: _yakit,
                    hata: h['yakit'] != null,
                    gruplar: [SecenekGrubu([for (final y in katalog.yakitlar) Secenek(y, y)])],
                    onSec: (x) => setState(() => _yakit = x),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Alan(etiket: 'Plaka', ipucu: 'Örnek: 34 ABC 123', hata: h['plaka'], child: MetinKutusu(kontrol: _plaka, hata: h['plaka'] != null)),
            const SizedBox(height: 24),
            AnaDugme(etiket: 'Aracı kaydet', bekliyor: _bekliyor, onPressed: _kaydet),
            if (widget.arac != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Renk.hayir, side: const BorderSide(color: Renk.hayir, width: 1.5)),
                onPressed: () async {
                  final evet = await onaySor(context, 'Aracı sil', '${widget.arac!['plaka']} listenden kalkacak.', 'Evet, aracı sil');
                  if (!evet) return;
                  await Api.ben.eylem('arac-sil', {'id': widget.arac!['id']});
                  if (!context.mounted) return;
                  bildir(context, 'Araç silindi.');
                  Navigator.pop(context, true);
                },
                child: const Text('Bu aracı sil'),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

/* ── Hesabım ──────────────────────────────────────────────────────────── */

class HesabimEkrani extends StatelessWidget {
  const HesabimEkrani({super.key});
  @override
  Widget build(BuildContext context) {
    final k = Oturum.ben.kullanici;
    if (k == null) return const SizedBox.shrink();
    return Sayfa(children: [
      const Konum(baslik: 'Hesabım'),
      Panel(
        child: Row(children: [
          const CircleAvatar(radius: 28, backgroundColor: Renk.lacivert, child: Icon(Icons.person_outline, color: Colors.white, size: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.ad, style: Yazi.bolum.copyWith(fontSize: 21)),
              Text(k.telefon != null ? telefonYaz(k.telefon!) : (k.eposta ?? ''), style: Yazi.ikincil),
            ]),
          ),
        ]),
      ),
      Bolum(
        baslik: 'Teklifler',
        child: Satirlar(children: [
          Satir(
            baslik: 'Tekliflerim',
            ayrinti: 'Fiyatı belirsiz işe ustalardan fiyat al',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TekliflerimEkrani())),
          ),
        ]),
      ),
      Bolum(
        baslik: 'Bilgilerim',
        child: Satirlar(children: [
          if (k.telefon != null) Satir(baslik: 'Telefon', ayrinti: telefonYaz(k.telefon!)),
          if (k.eposta != null) Satir(baslik: 'E-posta', ayrinti: k.eposta),
          Satir(baslik: 'Yer', ayrinti: [k.ilce, k.il].whereType<String>().join(', ')),
        ]),
      ),
      Bolum(
        baslik: 'Güvenlik ve yardım',
        child: Satirlar(children: [
          Satir(baslik: 'Şifremi değiştir', ayrinti: 'Sitede, sana bir kod göndeririz', onTap: () => siteyiAc('/sifremi-unuttum')),
          Satir(baslik: 'Kullanım Koşulları', onTap: () => siteyiAc('/kosullar')),
          Satir(baslik: 'KVKK Aydınlatma Metni', onTap: () => siteyiAc('/kvkk')),
          Satir(baslik: 'Hesabımı sil', ayrinti: 'Sitede, şifrenle', onTap: () => siteyiAc('/hesabim')),
        ]),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Renk.hayir),
        onPressed: Oturum.ben.cikis,
        icon: const Icon(Icons.logout),
        label: const Text('Çıkış yap'),
      ),
    ]);
  }
}
