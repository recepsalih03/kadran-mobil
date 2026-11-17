import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../bilesenler.dart';
import '../dert.dart';
import '../katalog.dart';
import '../oturum.dart';
import '../tema.dart';
import 'giris.dart' show girisIste;
import 'musteri.dart' show UstaBulEkrani;
import 'teklif.dart' show TeklifIsteEkrani;

/* "Aracında ne oluyor?" soru ağacı (sitedeki /dert). Ağaç sunucudan gelir. Kayıt ilk cevapta açılır;
   sonuca gelince ve kişi devam edince sunucuya yazılır (yönlendirme verisi). Girişsiz de kullanılır;
   teklif istemek için giriş gerekir. */

class DertEkrani extends StatefulWidget {
  const DertEkrani({super.key});
  @override
  State<DertEkrani> createState() => _DertEkraniState();
}

class _DertEkraniState extends State<DertEkrani> {
  final _metin = TextEditingController();
  String? _k;
  List<String> _yol = const [];
  List<String> _oneriler = const [];
  bool _bekliyor = false;
  String? _kaydedilenSonuc;

  Future<(Katalog, Map<String, dynamic>)> _yukle() async => (await Katalog.al(), await Api.ben.veri('dert-agaci'));

  Future<void> _basla(String ilk) async {
    setState(() => _bekliyor = true);
    final s = await Api.ben.eylem('dert-baslat', {'metin': _metin.text, 'ilk': ilk});
    final k = s.parametre('k');
    var oneriler = const <String>[];
    if (_metin.text.trim().isNotEmpty) {
      try {
        oneriler = [for (final x in (await Api.ben.veri('dert-oneri', {'metin': _metin.text}))['oneriler'] as List) '$x'];
      } on ApiHatasi {
        oneriler = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      _bekliyor = false;
      _k = k;
      _yol = [ilk];
      _oneriler = oneriler;
    });
    if (k == null) bildir(context, s.hata ?? 'Kaydedilemedi; yine de sorulara devam edebilirsin.');
  }

  /// Sonuca gelinince (bir kez) ve kişi devam edince sunucuya yazılır. Hata olursa akış durmaz.
  Future<void> _kaydet({String? hedef, String? hizmet}) async {
    if (_k == null) return;
    await Api.ben.eylem('dert-sonuc', {'k': _k, 'yol': _yol.join(','), 'hedef': ?hedef, 'hizmet': ?hizmet});
  }

  Future<void> _ustalar(String hizmet) async {
    await _kaydet(hedef: 'ustalar', hizmet: hizmet);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: ustSerit(context), body: UstaBulEkrani(hizmet: hizmet))));
  }

  Future<void> _teklif(String hizmet, String aciklama) async {
    if (!await girisIste(context) || !mounted) return;
    if (Oturum.ben.kullanici?.rol != 'musteri') return bildir(context, 'Teklifi araç sahibi hesabıyla isteyebilirsin.');
    await _kaydet(hedef: 'teklif', hizmet: hizmet);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => TeklifIsteEkrani(hizmet: hizmet, aciklama: aciklama, dert: _k)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<(Katalog, Map<String, dynamic>)>(
          yukle: _yukle,
          icerik: (context, veri, _) {
            final (katalog, v) = veri;
            final agac = Map<String, dynamic>.from(v['agac']);
            final aciliyet = Map<String, dynamic>.from(v['aciliyet']);
            final adim = dertAdimi(agac, _yol) ?? dertAdimi(agac, const [])!;
            final soru = adim.soru;
            final sonuc = adim.sonuc;
            if (sonuc != null && _kaydedilenSonuc != _yol.join(',')) {
              _kaydedilenSonuc = _yol.join(',');
              WidgetsBinding.instance.addPostFrameCallback((_) => _kaydet());
            }

            Widget secenekler(Map<String, dynamic> s, void Function(String kod) sec) => Satirlar(children: [
                  for (final x in (s['secenekler'] as List).cast<Map<String, dynamic>>())
                    Satir(baslik: x['etiket'], ayrinti: x['ipucu'] as String?, onTap: _bekliyor ? null : () => sec(x['kod'] as String)),
                ]);

            // Başlangıç: kendi sözleri (isteğe bağlı) ve ilk soru.
            if (_yol.isEmpty) {
              return Sayfa(children: [
                const Konum(baslik: 'Aracında ne oluyor?', aciklama: 'Ne olduğunu bilmiyorsan sorun değil. Birkaç soruyla hangi ustaya gideceğini bulalım.'),
                Alan(
                  etiket: 'Kendi sözlerinle anlat (isteğe bağlı)',
                  ipucu: 'Telefon numarası ya da plaka yazma.',
                  child: MetinKutusu(kontrol: _metin, satir: 3, ipucu: 'Örnek: Sabahları çalıştırınca önden tıkırtı geliyor'),
                ),
                const SizedBox(height: 20),
                Text(soru!['soru'], style: Yazi.bolum),
                if (soru['aciklama'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(soru['aciklama'], style: Yazi.ikincil)),
                const SizedBox(height: 10),
                secenekler(soru, _basla),
                const SizedBox(height: 20),
                const Text('Yazdıkların ve seçtiklerin, yönlendirmeyi iyileştirmek için saklanır.', style: Yazi.kucuk),
              ]);
            }

            return Sayfa(children: [
              Konum(baslik: sonuc != null ? 'Olası iş' : soru!['soru'], aciklama: sonuc != null ? null : soru!['aciklama'] as String?),
              if (_oneriler.isNotEmpty && _yol.length <= 1) ...[
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Yazdığına göre şunlar da olabilir:', style: Yazi.govdeKalin),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final h in _oneriler)
                        OutlinedButton(style: OutlinedButton.styleFrom(backgroundColor: Colors.white), onPressed: () => _ustalar(h), child: Text(katalog.hizmetAdi(h))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              for (var i = 0; i < adim.gecmis.length; i++)
                Row(children: [
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${adim.gecmis[i].$1} ', style: Yazi.ikincil),
                      TextSpan(text: adim.gecmis[i].$2, style: Yazi.govdeKalin.copyWith(fontSize: 16)),
                    ])),
                  ),
                  TextButton(onPressed: () => setState(() => _yol = _yol.sublist(0, i)), child: const Text('Değiştir')),
                ]),
              const SizedBox(height: 10),
              if (soru != null) secenekler(soru, (kod) => setState(() => _yol = [..._yol, kod])),
              if (sonuc != null) ...[
                Uyari(
                  tur: switch (sonuc['aciliyet']) { 'dur' => UyariTuru.hata, 'yakinda' => UyariTuru.bilgi, _ => UyariTuru.basari },
                  baslik: aciliyet[sonuc['aciliyet']]['baslik'],
                  metin: aciliyet[sonuc['aciliyet']]['metin'],
                ),
                const SizedBox(height: 14),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(katalog.hizmetAdi(sonuc['hizmet']), style: Yazi.bolum),
                    const SizedBox(height: 6),
                    Text(sonuc['not'], style: Yazi.govde),
                    if ((sonuc['diger'] as List?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Başka olasılıklar: ${(sonuc['diger'] as List).map((h) => katalog.hizmetAdi('$h')).join(', ')}.', style: Yazi.ikincil),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                AnaDugme(etiket: 'Bu işe bakan ustaların boş saatleri', simge: Icons.arrow_forward, onPressed: () => _ustalar(sonuc['hizmet'])),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _teklif(sonuc['hizmet'], dertOzeti(adim, _metin.text)),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Fotoğrafla teklif iste'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _yol = const [];
                    _k = null;
                    _oneriler = const [];
                  }),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Baştan başla'),
                ),
                const SizedBox(height: 12),
                const Text('Bu bir teşhis değil: cevaplarına göre en olası işi gösteriyoruz. Kesin sebebi usta aracı görünce söyler.', style: Yazi.kucuk),
              ],
            ]);
          },
        ),
      );
}
