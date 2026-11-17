import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../bilesenler.dart';
import '../katalog.dart';
import '../tema.dart';
import '../zaman.dart';
import 'giris.dart' show siteyiAc;
import 'mesajlar.dart';
import 'musteri.dart' show AracEkleEkrani, PuanlaEkrani, onaySor;

/* İş takibi ve aracın sayfası (sitedeki /randevularim/<id>, /usta/randevular/<id>, /araclarim/<id>).
   Usta aracın durumunu günceller, ek iş önerir, servis kaydı yazar; araç sahibi sormadan görür, öneriyi onaylar.
   Araç sayfasında hatırlatıcılar (muayene, sigorta, …) ve servis geçmişi. */

/// "1.250 TL", "1.250,50 TL"
String tlYaz(num? n) {
  if (n == null) return '';
  final kurus = (n * 100).round();
  final tam = (kurus ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final ondalik = kurus % 100;
  return ondalik == 0 ? '$tam TL' : '$tam,${ondalik.toString().padLeft(2, '0')} TL';
}

/// Oturuma bağlı fotoğraf (sitenin /is-foto, /teklif-foto adresleri); dokununca tam ekran.
class OturumFotosu extends StatelessWidget {
  const OturumFotosu(this.yol, {super.key, this.boy = 160, this.etiket = 'Fotoğraf'});
  final String yol;
  final double boy;
  final String etiket;
  @override
  Widget build(BuildContext context) {
    Widget resim(BoxFit sigdir) => Image.network(
          '$siteAdresi$yol',
          headers: Api.ben.fotoBasliklari,
          fit: sigdir,
          semanticLabel: etiket,
          errorBuilder: (_, _, _) => const Center(child: Text('Fotoğraf açılamadı', style: Yazi.kucuk)),
        );
    return Semantics(
      button: true,
      label: '$etiket, büyütmek için dokun',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Kose.orta),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(etiket)),
              body: InteractiveViewer(child: Center(child: resim(BoxFit.contain))),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Kose.orta),
          child: Container(height: boy, width: double.infinity, color: Colors.white, child: resim(BoxFit.cover)),
        ),
      ),
    );
  }
}

/// Fotoğraf ekleme henüz uygulamada yok: siteden eklenebileceğini söyler.
class FotoSitedeNotu extends StatelessWidget {
  const FotoSitedeNotu({super.key, required this.yol, required this.metin});
  final String yol;
  final String metin;
  @override
  Widget build(BuildContext context) => Panel(
        renk: Colors.white,
        dolgu: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.photo_camera_outlined, color: Renk.murekkep2),
          const SizedBox(width: 10),
          Expanded(child: Text(metin, style: Yazi.ikincil)),
          TextButton(onPressed: () => siteyiAc(yol), child: const Text('Sitede aç')),
        ]),
      );
}

/* ── Randevunun iş takibi ─────────────────────────────────────────────── */

class RandevuTakipEkrani extends StatefulWidget {
  const RandevuTakipEkrani({super.key, required this.id, this.usta = false});
  final String id;
  /// true: usta yüzü (durum güncelle, ek iş öner, servis kaydı); false: araç sahibi (gör, onayla).
  final bool usta;
  @override
  State<RandevuTakipEkrani> createState() => _RandevuTakipEkraniState();
}

class _RandevuTakipEkraniState extends State<RandevuTakipEkrani> {
  final _anahtar = GlobalKey<VeriEkraniState<(Katalog, Map<String, dynamic>)>>();
  String? _durum;
  final _not = TextEditingController();
  final _ekAciklama = TextEditingController();
  final _ekTutar = TextEditingController();
  final _yapilanlar = TextEditingController();
  final _parcalar = TextEditingController();
  final _tutar = TextEditingController();
  final _km = TextEditingController();
  EylemSonucu? _ekSonuc, _servisSonuc;
  bool _bekliyor = false;
  bool _servisDuzelt = false;

  static const _iletiler = {
    'durum': 'Aracın durumu güncellendi. Müşteriye haber verdik.',
    'teklif': 'Ek iş önerisi müşteriye gitti.',
    'servis': 'Servis kaydı yazıldı. Aracın servis geçmişine eklendi.',
    'onaylandi': 'Ek işi onayladın. Ustaya haber verdik.',
    'reddedildi': 'Ek işi istemedin. Ustaya haber verdik.',
    'yapilamadi': 'İşlem yapılamadı. Randevunun durumu değişmiş olabilir.',
  };

  Future<void> _yenile() async => _anahtar.currentState?.yenile();

  Future<EylemSonucu> _calistir(String eylem, Map<String, Object?> alanlar) async {
    setState(() => _bekliyor = true);
    final s = await Api.ben.eylem(eylem, alanlar);
    if (!mounted) return s;
    setState(() => _bekliyor = false);
    final islem = s.parametre('islem');
    if (s.hata == null && islem != null) {
      bildir(context, _iletiler[islem] ?? 'Kaydedildi.');
      await _yenile();
    }
    return s;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          key: _anahtar,
          yenileme: const Duration(seconds: 20),
          yukle: () async => (await Katalog.al(), Map<String, dynamic>.from((await Api.ben.veri('randevu', {'id': widget.id}))['randevu'])),
          icerik: (context, veri, yenile) {
            final (katalog, r) = veri;
            final adimlar = [for (final a in r['adimlar'] as List) Map<String, dynamic>.from(a)];
            final teklifler = adimlar.where((a) => a['tur'] == 'teklif').toList();
            final bekleyen = teklifler.where((a) => a['onay'] == 'bekliyor').toList();
            final acik = r['durum'] == 'onaylandi';
            final gunuGeldi = (r['gun'] as String).compareTo(bugunIso()) <= 0;
            final servis = r['servis'] == null ? null : Map<String, dynamic>.from(r['servis']);
            final sonNot = adimlar.where((a) => a['tur'] == 'durum' && a['aciklama'] != null).lastOrNull?['aciklama'] as String?;
            final simdi = katalog.isDurumlari.indexWhere((d) => d.kod == r['isDurumu']);
            final secilebilir = katalog.isDurumlari.where((d) => d.kod != 'teslim_edildi').toList();
            _durum ??= secilebilir.isEmpty ? null : secilebilir[(simdi + 1).clamp(0, secilebilir.length - 1)].kod;

            return Sayfa(children: [
              Konum(
                baslik: widget.usta ? r['musteri'] : r['ustaAdi'],
                aciklama: '${gunVeTarih(r['gun'])} · ${r['saat']}–${r['bitis']} · ${katalog.hizmetAdi(r['hizmet'])}',
              ),
              DurumRozeti(r['durum']),
              const SizedBox(height: 12),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['arac']} · ${plaka(r['plaka'])}', style: Yazi.govdeKalin),
                  if (!widget.usta) Text('${r['firma']}', style: Yazi.ikincil),
                  if (r['not'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${r['not']}”', style: Yazi.govde)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, children: [
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => widget.usta ? SohbetEkrani(randevuId: r['id'], baslik: r['musteri']) : SohbetEkrani(ustaSlug: r['ustaSlug'], baslik: r['ustaAdi']),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(widget.usta ? 'Müşteriye yaz' : 'Ustaya yaz'),
                    ),
                    if (widget.usta && r['telefon'] != null)
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse('tel:0${r['telefon']}')),
                        icon: const Icon(Icons.phone_outlined),
                        label: Text('Ara · ${telefonYaz(r['telefon'])}'),
                      ),
                  ]),
                ]),
              ),

              // Araç sahibi: onayını bekleyen ek iş en üstte.
              if (!widget.usta && bekleyen.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Uyari(tur: UyariTuru.bilgi, baslik: 'Usta bir ek iş öneriyor; onayın bekleniyor.', metin: 'Onaylamadığın iş yapılmaz.'),
                for (final a in bekleyen) ...[
                  const SizedBox(height: 10),
                  _TeklifKarti(
                    a: a,
                    alt: Column(children: [
                      AnaDugme(
                        etiket: 'Onayla',
                        simge: Icons.check,
                        bekliyor: _bekliyor,
                        onPressed: () => _calistir('teklif-karar', {'adim': a['id'], 'randevu': r['id'], 'karar': 'onayla'}),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _bekliyor ? null : () => _calistir('teklif-karar', {'adim': a['id'], 'randevu': r['id'], 'karar': 'reddet'}),
                          child: const Text('İstemiyorum'),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],

              Bolum(
                baslik: 'Aracın durumu',
                aciklama: widget.usta ? 'Güncelledikçe müşteriye haber gider; seni aramak zorunda kalmaz.' : 'Usta güncelledikçe sana haber veririz.',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _DurumListesi(durumlar: katalog.isDurumlari, simdi: simdi),
                  if (sonNot != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Ustanın notu: “$sonNot”', style: Yazi.govde)),
                  if (widget.usta && acik) ...[
                    const SizedBox(height: 16),
                    Text('Şimdiki durum', style: Yazi.govde.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    for (final d in secilebilir) ...[
                      SecimDugmesi(
                        secili: _durum == d.kod,
                        onTap: () => setState(() => _durum = d.kod),
                        child: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(d.ad, style: Yazi.govdeKalin))),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Alan(etiket: 'Kısa not (isteğe bağlı)', child: MetinKutusu(kontrol: _not, ipucu: 'Örnek: Parça yarın öğlen gelecek')),
                    const SizedBox(height: 14),
                    AnaDugme(
                      etiket: 'Durumu güncelle',
                      bekliyor: _bekliyor,
                      onPressed: _durum == null
                          ? null
                          : () async {
                              final s = await _calistir('is-durumu', {'id': r['id'], 'durum': _durum, 'not': _not.text});
                              if (s.hata == null) {
                                _not.clear();
                                _durum = null;
                              }
                            },
                    ),
                  ],
                ]),
              ),

              Bolum(
                baslik: 'Ek iş',
                aciklama: widget.usta ? 'Aracı açınca başka bir şey çıktıysa fiyatıyla öner; müşteri onaylasın.' : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (teklifler.isEmpty && !(widget.usta && acik)) const Panel(child: Text('Ek iş önerisi yok.', style: Yazi.govde)),
                  for (final a in teklifler.where((a) => widget.usta || a['onay'] != 'bekliyor')) ...[_TeklifKarti(a: a), const SizedBox(height: 10)],
                  if (widget.usta && acik)
                    Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_ekSonuc?.hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _ekSonuc!.hata!), const SizedBox(height: 12)],
                        Alan(etiket: 'Ne gerekiyor?', ipucu: 'Örnek: Ön balatalar bitmiş, değişmeli.', hata: _ekSonuc?.alanlar['aciklama'], child: MetinKutusu(kontrol: _ekAciklama, satir: 2, hata: _ekSonuc?.alanlar['aciklama'] != null)),
                        const SizedBox(height: 12),
                        Alan(etiket: 'Fiyatı (TL)', ipucu: 'İşçilik ve parça dahil.', hata: _ekSonuc?.alanlar['tutar'], child: MetinKutusu(kontrol: _ekTutar, klavye: const TextInputType.numberWithOptions(decimal: true), hata: _ekSonuc?.alanlar['tutar'] != null)),
                        const SizedBox(height: 12),
                        FotoSitedeNotu(yol: '/usta/randevular/${r['id']}', metin: 'Fotoğraflı öneri için sitedeki iş takibi sayfasını kullan.'),
                        const SizedBox(height: 14),
                        AnaDugme(
                          etiket: 'Müşterinin onayına gönder',
                          bekliyor: _bekliyor,
                          onPressed: () async {
                            final s = await _calistir('teklif-ekle', {'id': r['id'], 'aciklama': _ekAciklama.text, 'tutar': _ekTutar.text});
                            setState(() => _ekSonuc = s);
                            if (s.hata == null) {
                              _ekAciklama.clear();
                              _ekTutar.clear();
                            }
                          },
                        ),
                      ]),
                    ),
                ]),
              ),

              Bolum(
                baslik: 'Servis kaydı',
                aciklama: widget.usta ? 'İş bitince yapılanları yaz; aracın servis geçmişine eklenir.' : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (servis != null) ServisKarti(s: servis),
                  if (widget.usta && servis != null && !_servisDuzelt)
                    TextButton(
                      onPressed: () => setState(() {
                        _servisDuzelt = true;
                        _yapilanlar.text = servis['yapilanlar'] ?? '';
                        _parcalar.text = servis['parcalar'] ?? '';
                        _tutar.text = servis['tutar'] == null ? '' : '${servis['tutar']}';
                        _km.text = servis['km'] == null ? '' : '${servis['km']}';
                      }),
                      child: const Text('Servis kaydını düzelt'),
                    ),
                  if (widget.usta && ((servis == null && acik && gunuGeldi) || _servisDuzelt))
                    Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_servisSonuc?.hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _servisSonuc!.hata!), const SizedBox(height: 12)],
                        Alan(etiket: 'Yapılanlar', ipucu: 'Örnek: Yağ ve yağ filtresi değişti, fren kontrolü yapıldı.', hata: _servisSonuc?.alanlar['yapilanlar'], child: MetinKutusu(kontrol: _yapilanlar, satir: 3, hata: _servisSonuc?.alanlar['yapilanlar'] != null)),
                        const SizedBox(height: 12),
                        Alan(etiket: 'Değişen parçalar (isteğe bağlı)', child: MetinKutusu(kontrol: _parcalar, satir: 2)),
                        const SizedBox(height: 12),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: Alan(etiket: 'Tutar, TL', hata: _servisSonuc?.alanlar['tutar'], child: MetinKutusu(kontrol: _tutar, klavye: const TextInputType.numberWithOptions(decimal: true)))),
                          const SizedBox(width: 10),
                          Expanded(child: Alan(etiket: 'Kilometre', hata: _servisSonuc?.alanlar['km'], child: MetinKutusu(kontrol: _km, klavye: TextInputType.number))),
                        ]),
                        const SizedBox(height: 14),
                        AnaDugme(
                          etiket: servis != null ? 'Servis kaydını güncelle' : 'İşi bitir ve servis kaydını yaz',
                          bekliyor: _bekliyor,
                          onPressed: () async {
                            final s = await _calistir('servis-kaydet', {'id': r['id'], 'yapilanlar': _yapilanlar.text, 'parcalar': _parcalar.text, 'tutar': _tutar.text, 'km': _km.text});
                            setState(() {
                              _servisSonuc = s;
                              if (s.hata == null && s.alanlar.isEmpty) _servisDuzelt = false;
                            });
                          },
                        ),
                      ]),
                    )
                  else if (servis == null)
                    Panel(
                      child: Text(
                        widget.usta ? (acik ? 'Randevu günü gelince yazılır.' : 'Bu randevu için servis kaydı yazılmadı.') : 'İş bitince ustanın yazdığı kayıt burada görünür.',
                        style: Yazi.govde,
                      ),
                    ),
                ]),
              ),

              if (adimlar.isNotEmpty)
                Bolum(
                  baslik: 'Geçmiş',
                  child: Satirlar(children: [
                    for (final a in adimlar.reversed)
                      Satir(
                        ok: false,
                        baslik: a['tur'] == 'durum' ? (katalog.isDurumu(a['durum'])?.ad ?? 'Durum') : 'Ek iş: ${a['aciklama']}',
                        ayrinti: [
                          '${tarihKisa(a['gun'])} ${a['saat']}',
                          if (a['tur'] == 'durum' && a['aciklama'] != null) '${a['aciklama']}',
                          if (a['tur'] == 'teklif') '${tlYaz(a['tutar'] as num?)} · ${_onayAdi(a['onay'])}',
                        ].join(' · '),
                      ),
                  ]),
                ),

              if (!widget.usta) ...[
                const SizedBox(height: 20),
                if (r['durum'] == 'tamamlandi' && r['puanlandi'] != true)
                  AnaDugme(
                    etiket: 'Ustayı puanla',
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => PuanlaEkrani(randevu: r)));
                      yenile();
                    },
                  ),
                if ((r['durum'] == 'bekliyor' || r['durum'] == 'onaylandi') && (r['gun'] as String).compareTo(bugunIso()) >= 0)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Renk.hayir, side: const BorderSide(color: Renk.hayir, width: 1.5)),
                    onPressed: () async {
                      final evet = await onaySor(context, 'Randevuyu iptal et', '${gunVeTarih(r['gun'])} ${r['saat']} randevun iptal edilecek ve ustaya haber verilecek.', 'Evet, iptal et');
                      if (!evet || !context.mounted) return;
                      final s = await Api.ben.eylem('randevu-iptal', {'id': r['id']});
                      if (!context.mounted) return;
                      bildir(context, s.yonlendir?.contains('iptal=1') == true ? 'Randevun iptal edildi.' : (s.hata ?? 'Randevu iptal edilemedi.'));
                      if (s.hata == null) Navigator.pop(context);
                    },
                    child: const Text('Randevuyu iptal et'),
                  ),
              ],
            ]);
          },
        ),
      );
}

String _onayAdi(Object? onay) => switch (onay) { 'onaylandi' => 'Onaylandı', 'reddedildi' => 'İstenmedi', _ => 'Onay bekliyor' };

/// Ek iş önerisi kartı: açıklama, fiyat, varsa fotoğraf, onay durumu.
class _TeklifKarti extends StatelessWidget {
  const _TeklifKarti({required this.a, this.alt});
  final Map<String, dynamic> a;
  final Widget? alt;
  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text('${a['aciklama']}', style: Yazi.govdeKalin)),
            const SizedBox(width: 8),
            Text(tlYaz(a['tutar'] as num?), style: Yazi.rakam.copyWith(fontSize: 20)),
          ]),
          const SizedBox(height: 4),
          Text('${tarihKisa(a['gun'])} ${a['saat']} · ${_onayAdi(a['onay'])}', style: Yazi.kucuk),
          if (a['foto'] == true) ...[const SizedBox(height: 10), OturumFotosu('/is-foto/${a['id']}', etiket: 'Ek iş fotoğrafı')],
          if (alt != null) ...[const SizedBox(height: 12), alt!],
        ]),
      );
}

/// Durum adımları: geçilenler işaretli, şimdiki kalın, sıradakiler soluk.
class _DurumListesi extends StatelessWidget {
  const _DurumListesi({required this.durumlar, required this.simdi});
  final List<IsDurumu> durumlar;
  final int simdi;
  @override
  Widget build(BuildContext context) {
    if (simdi < 0) return const Panel(child: Text('Usta henüz durum girmedi.', style: Yazi.govde));
    return Panel(
      child: Column(children: [
        for (var i = 0; i < durumlar.length; i++)
          Semantics(
            label: '${durumlar[i].ad}${i == simdi ? ', şimdiki durum' : i < simdi ? ', geçti' : ''}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  i < simdi ? Icons.check_circle : (i == simdi ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                  color: i == simdi ? Renk.secili : (i < simdi ? Renk.ok : Renk.kapali),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(durumlar[i].ad, style: i == simdi ? Yazi.govdeKalin : Yazi.govde.copyWith(color: i < simdi ? Renk.lacivert : Renk.murekkep2)),
                    if (i == simdi) Text(durumlar[i].aciklama, style: Yazi.ikincil),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Servis kaydı özeti (iş takibi ve aracın servis geçmişi).
class ServisKarti extends StatelessWidget {
  const ServisKarti({super.key, required this.s});
  final Map<String, dynamic> s;
  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${tarihKisa(s['tarih'])} · ${s['ustaAdi']}', style: Yazi.govdeKalin),
          const SizedBox(height: 4),
          Text('${s['yapilanlar']}', style: Yazi.govde),
          if (s['parcalar'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Parçalar: ${s['parcalar']}', style: Yazi.ikincil)),
          if (s['tutar'] != null || s['km'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [if (s['tutar'] != null) tlYaz(s['tutar'] as num), if (s['km'] != null) '${_binlik((s['km'] as num).toInt())} km'].join(' · '),
                style: Yazi.ikincil,
              ),
            ),
        ]),
      );
}

String _binlik(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/* ── Aracın sayfası: hatırlatıcılar ve servis geçmişi ─────────────────── */

class AracEkrani extends StatefulWidget {
  const AracEkrani({super.key, required this.aracId});
  final String aracId;
  @override
  State<AracEkrani> createState() => _AracEkraniState();
}

class _AracEkraniState extends State<AracEkrani> {
  final _anahtar = GlobalKey<VeriEkraniState<(Katalog, Map<String, dynamic>)>>();
  Map<String, String>? _tarihler;
  EylemSonucu? _sonuc;
  bool _bekliyor = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          key: _anahtar,
          yukle: () async => (await Katalog.al(), await Api.ben.veri('arac', {'id': widget.aracId})),
          icerik: (context, veri, yenile) {
            final (katalog, v) = veri;
            final a = Map<String, dynamic>.from(v['arac']);
            final servis = [for (final s in v['servis'] as List) Map<String, dynamic>.from(s)];
            _tarihler ??= {for (final h in v['hatirlaticilar'] as List) h['tur'] as String: h['tarih'] as String};
            return Sayfa(children: [
              Konum(
                baslik: plaka(a['plaka']),
                aciklama: ['${a['markaAdi']} ${a['model']}', if (a['yil'] != null) '${a['yil']}', if (a['yakit'] != null) '${a['yakit']}'].join(' · '),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => AracEkleEkrani(arac: a)));
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Aracı düzenle'),
              ),
              Bolum(
                baslik: 'Hatırlatıcılar',
                aciklama: 'Tarihten 7 gün önce telefonuna haber veririz. Bilmediğini boş bırak.',
                child: Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_sonuc?.hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 12)],
                    for (final h in katalog.hatirlaticiTurleri) ...[
                      Alan(
                        etiket: h.ad,
                        ipucu: h.ipucu,
                        hata: _sonuc?.alanlar[h.tur],
                        child: TarihSecici(
                          etiket: h.ad,
                          deger: _tarihler![h.tur],
                          onSec: (t) => setState(() => t == null ? _tarihler!.remove(h.tur) : _tarihler![h.tur] = t),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    AnaDugme(
                      etiket: 'Hatırlatıcıları kaydet',
                      bekliyor: _bekliyor,
                      onPressed: () async {
                        setState(() => _bekliyor = true);
                        final s = await Api.ben.eylem('hatirlatici-kaydet', {
                          'arac': a['id'],
                          for (final h in katalog.hatirlaticiTurleri) h.tur: _tarihler![h.tur] ?? '',
                        });
                        if (!context.mounted) return;
                        setState(() {
                          _bekliyor = false;
                          _sonuc = s;
                        });
                        if (s.hata == null && s.yonlendir != null) bildir(context, 'Hatırlatıcılar kaydedildi. Her tarihten 7 gün önce haber veririz.');
                      },
                    ),
                  ]),
                ),
              ),
              Bolum(
                baslik: 'Servis geçmişi',
                aciklama: "Ustaların Kadran'da yazdığı kayıtlar.",
                child: servis.isEmpty
                    ? const Panel(child: Text("Henüz kayıt yok. Kadran'dan randevu aldığın işler bitince ustanın yazdığı kayıt burada görünür.", style: Yazi.govde))
                    : Column(children: [for (final s in servis) ...[ServisKarti(s: s), const SizedBox(height: 10)]]),
              ),
            ]);
          },
        ),
      );
}

/// Tarih seçici: gün, ay, yıl (Türkçe, bağımsız seçim sayfalarıyla); "Temizle" ile boşaltılır.
class TarihSecici extends StatelessWidget {
  const TarihSecici({super.key, required this.etiket, required this.deger, required this.onSec});
  final String etiket;
  final String? deger;
  final ValueChanged<String?> onSec;

  static const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

  @override
  Widget build(BuildContext context) {
    final bugun = bugunIso();
    final yil = deger == null ? null : int.parse(deger!.substring(0, 4));
    final ay = deger == null ? null : int.parse(deger!.substring(5, 7));
    final gun = deger == null ? null : int.parse(deger!.substring(8, 10));
    final buYil = int.parse(bugun.substring(0, 4));

    String yap(int y, int a, int g) {
      final sonGun = DateTime.utc(y, a + 1, 0).day;
      return '${y.toString().padLeft(4, '0')}-${a.toString().padLeft(2, '0')}-${g.clamp(1, sonGun).toString().padLeft(2, '0')}';
    }

    Future<void> sec(String parca) async {
      final y0 = yil ?? buYil, a0 = ay ?? int.parse(bugun.substring(5, 7)), g0 = gun ?? int.parse(bugun.substring(8, 10));
      final secenekler = switch (parca) {
        'gun' => [for (var i = 1; i <= 31; i++) Secenek('$i', '$i')],
        'ay' => [for (var i = 1; i <= 12; i++) Secenek('$i', _aylar[i - 1])],
        _ => [for (var i = buYil - 1; i <= buYil + 3; i++) Secenek('$i', '$i')],
      };
      final s = await secimSayfasi(context, baslik: '$etiket: ${switch (parca) { 'gun' => 'gün', 'ay' => 'ay', _ => 'yıl' }}', arama: false, gruplar: [SecenekGrubu(secenekler)]);
      if (s == null) return;
      final n = int.parse(s);
      onSec(switch (parca) { 'gun' => yap(y0, a0, n), 'ay' => yap(y0, n, g0), _ => yap(n, a0, g0) });
    }

    Widget parca(String ad, String? metin, int esneklik) => Expanded(
          flex: esneklik,
          child: SecimDugmesi(
            secili: false,
            onTap: () => sec(ad),
            child: Text(metin ?? switch (ad) { 'gun' => 'Gün', 'ay' => 'Ay', _ => 'Yıl' }, style: Yazi.govdeKalin.copyWith(color: metin == null ? Renk.murekkep2 : Renk.lacivert)),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        parca('gun', gun?.toString(), 2),
        const SizedBox(width: 6),
        parca('ay', ay == null ? null : _aylar[ay - 1], 3),
        const SizedBox(width: 6),
        parca('yil', yil?.toString(), 2),
      ]),
      if (deger != null) TextButton(onPressed: () => onSec(null), child: const Text('Temizle')),
    ]);
  }
}
