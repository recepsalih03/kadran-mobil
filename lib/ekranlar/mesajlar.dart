import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../bilesenler.dart';
import '../katalog.dart';
import '../oturum.dart';
import '../tema.dart';
import '../zaman.dart';

/* Mesajlar: yazışma listesi ve tek yazışma. Araç sahibi ve usta aynı ekranları kullanır.
   Yazışma açıkken 4 saniyede bir yenilenir; karşı tarafın yazdığı sayfa yenilemeden görünür. */

class MesajlarEkrani extends StatelessWidget {
  const MesajlarEkrani({super.key});
  @override
  Widget build(BuildContext context) {
    final usta = Oturum.ben.kullanici?.usta == true;
    return VeriEkrani<Map<String, dynamic>>(
      yenileme: const Duration(seconds: 10),
      yukle: () => Api.ben.veri('konusmalar'),
      icerik: (context, v, yenile) {
        final liste = [for (final c in v['konusmalar'] as List) Map<String, dynamic>.from(c)];
        return Sayfa(children: [
          const Konum(baslik: 'Mesajlar'),
          if (liste.isEmpty)
            BosEkran(
              baslik: 'Henüz mesajın yok',
              aciklama: usta ? 'Müşteriler sana yazınca burada görürsün.' : 'Bir ustanın sayfasından “Ustaya mesaj yaz” ile yazışma başlatabilirsin.',
            )
          else
            Satirlar(children: [
              for (final c in liste)
                Satir(
                  baslik: usta ? c['musteri'] : '${c['ustaAdi']} · ${c['firma']}',
                  ayrinti: _sonMesaj(c, usta),
                  alt: (c['okunmamis'] as num) > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: Renk.lacivert, borderRadius: BorderRadius.circular(99)),
                          child: Text('${c['okunmamis']} yeni', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        )
                      : null,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => SohbetEkrani(konusmaId: c['id'], baslik: usta ? c['musteri'] : c['ustaAdi'])));
                    yenile();
                    Oturum.ben.yukle();
                  },
                ),
            ]),
        ]);
      },
    );
  }

  String _sonMesaj(Map<String, dynamic> c, bool usta) {
    final s = c['son'];
    if (s == null) return 'Henüz mesaj yok';
    final kim = s['kimden'] == 'sistem' ? '' : ((s['kimden'] == 'usta') == usta ? 'Sen: ' : '');
    final metin = s['foto'] == true && (s['metin'] as String).isEmpty ? 'Fotoğraf' : s['metin'];
    final ne = s['gun'] == bugunIso() ? s['saat'] : tarihKisa(s['gun']);
    return '$kim$metin · $ne';
  }
}

/// Tek yazışma. Yeni yazışma için konusmaId yerine ustaSlug (araç sahibi) ya da randevuId (usta) verilir;
/// ilk mesaj gidince yazışma açılır.
class SohbetEkrani extends StatefulWidget {
  const SohbetEkrani({super.key, this.konusmaId, this.ustaSlug, this.randevuId, required this.baslik});
  final String? konusmaId, ustaSlug, randevuId;
  final String baslik;
  @override
  State<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani> {
  late String? _id = widget.konusmaId;
  final _metin = TextEditingController();
  final _kaydirma = ScrollController();
  final _anahtar = GlobalKey<VeriEkraniState<Map<String, dynamic>?>>();
  bool _bekliyor = false;
  String? _hata;
  int _sonSayi = 0;

  bool get _usta => Oturum.ben.kullanici?.usta == true;
  List<String> get _hazir => _usta
      ? const ['Aracını bekliyorum.', 'Aracın hazır, alabilirsin.', 'Parça bekliyorum, haber vereceğim.']
      : const ['Merhaba, randevuma geliyorum.', 'Biraz gecikeceğim.', 'Fiyat bilgisi alabilir miyim?'];

  Future<Map<String, dynamic>?> _yukle() async {
    if (_id == null) return null;
    final v = await Api.ben.veri('konusma', {'id': _id!});
    return Map<String, dynamic>.from(v['konusma']);
  }

  Future<void> _gonder(String metin) async {
    if (metin.trim().isEmpty) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final alanlar = <String, Object?>{
      'm': metin,
      if (_id != null) 'konusma': _id else if (widget.ustaSlug != null) 'usta': widget.ustaSlug else 'randevu': widget.randevuId,
    };
    final s = await Api.ben.eylem('mesaj-gonder', alanlar);
    if (!mounted) return;
    setState(() => _bekliyor = false);
    if (s.hata != null) return setState(() => _hata = s.hata);
    final yeni = s.yonlendir == null ? null : RegExp(r'/mesajlar/([0-9a-f-]{36})').firstMatch(s.yonlendir!)?.group(1);
    if (yeni != null && _id == null) setState(() => _id = yeni);
    _metin.clear();
    await _anahtar.currentState?.yenile();
  }

  void _sonaKaydir(int sayi) {
    if (sayi == _sonSayi) return;
    _sonSayi = sayi;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kaydirma.hasClients) _kaydirma.animateTo(_kaydirma.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: Column(children: [
          Expanded(
            child: VeriEkrani<Map<String, dynamic>?>(
              key: _anahtar,
              yenileme: const Duration(seconds: 4),
              yukle: _yukle,
              icerik: (context, c, _) {
                final mesajlar = c == null ? const <Map<String, dynamic>>[] : [for (final m in c['mesajlar'] as List) Map<String, dynamic>.from(m)];
                _sonaKaydir(mesajlar.length);
                final randevu = c?['randevu'];
                return ListView(controller: _kaydirma, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                  Konum(baslik: widget.baslik),
                  if (randevu != null) ...[
                    FutureBuilder<Katalog>(
                      future: Katalog.al(),
                      builder: (_, k) => Panel(
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${gunVeTarih(randevu['tarih'])} · ${randevu['saat']}', style: Yazi.govdeKalin),
                              Text('${randevu['arac']} · ${k.data?.hizmetAdi(randevu['hizmet']) ?? ''}', style: Yazi.ikincil),
                            ]),
                          ),
                          DurumRozeti(randevu['durum']),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (mesajlar.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('İlk mesajı sen yaz. Telefon numarası paylaşabilirsin.', style: Yazi.ikincil)),
                  for (var i = 0; i < mesajlar.length; i++) ...[
                    if (i == 0 || mesajlar[i]['gun'] != mesajlar[i - 1]['gun'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(child: Text(gunVeTarih(mesajlar[i]['gun']), style: Yazi.kucuk.copyWith(fontWeight: FontWeight.w600))),
                      ),
                    _Balon(mesaj: mesajlar[i], benim: mesajlar[i]['kimden'] == (_usta ? 'usta' : 'musteri')),
                  ],
                  if (c?['engelli'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Panel(child: Text(_usta ? 'Bu müşteriyi engelledin. Engeli kaldırmak için siteyi kullan.' : 'Bu usta senden mesaj kabul etmiyor.', style: Yazi.govde)),
                    ),
                ]);
              },
            ),
          ),
          _yazmaKutusu(),
        ]),
      );

  Widget _yazmaKutusu() => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Renk.cizgi))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_hata != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(_hata!, style: Yazi.govdeKalin.copyWith(color: Renk.hayir))),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final h in _hazir)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        onPressed: _bekliyor ? null : () => _gonder(h),
                        child: Text(h),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: TextField(controller: _metin, minLines: 1, maxLines: 5, maxLength: 1000, style: Yazi.govde, decoration: const InputDecoration(hintText: 'Mesaj yaz', counterText: ''))),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _bekliyor ? null : () => _gonder(_metin.text),
                    child: _bekliyor ? const Text('Bekle…') : const Row(children: [Text('Gönder'), SizedBox(width: 6), Icon(Icons.send, size: 18)]),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      );
}

class _Balon extends StatelessWidget {
  const _Balon({required this.mesaj, required this.benim});
  final Map<String, dynamic> mesaj;
  final bool benim;
  @override
  Widget build(BuildContext context) {
    if (mesaj['kimden'] == 'sistem') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Renk.bant, borderRadius: BorderRadius.circular(Kose.orta)),
            child: Text('${mesaj['metin']} · ${mesaj['saat']}', textAlign: TextAlign.center, style: Yazi.kucuk.copyWith(fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }
    final metin = (mesaj['metin'] as String?) ?? '';
    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: benim ? Renk.lacivert : Renk.bant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Kose.panel),
            topRight: const Radius.circular(Kose.panel),
            bottomLeft: Radius.circular(benim ? Kose.panel : 4),
            bottomRight: Radius.circular(benim ? 4 : Kose.panel),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (mesaj['foto'] == true)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: benim ? Colors.white : Renk.lacivert, padding: EdgeInsets.zero),
              onPressed: () => _fotografiAc(context, mesaj['id']),
              icon: const Icon(Icons.photo_outlined),
              label: const Text('Fotoğrafı aç'),
            ),
          if (metin.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text(metin, style: Yazi.govde.copyWith(color: benim ? Colors.white : Renk.lacivert))),
          const SizedBox(height: 2),
          Text(
            '${mesaj['saat']}${benim ? (mesaj['okundu'] == true ? ' · Okundu' : ' · Gönderildi') : ''}',
            style: TextStyle(fontSize: 13, color: benim ? Colors.white70 : Renk.murekkep2),
          ),
        ]),
      ),
    );
  }

  void _fotografiAc(BuildContext context, String id) => showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(children: [
            InteractiveViewer(
              child: Image.network(
                '$siteAdresi/mesaj-foto/$id',
                headers: kIsWeb ? null : Api.ben.fotoBasliklari,
                errorBuilder: (_, _, _) => const Padding(padding: EdgeInsets.all(24), child: Text('Fotoğraf açılamadı.', style: TextStyle(color: Colors.white))),
              ),
            ),
            Positioned(top: 4, right: 4, child: IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close, color: Colors.white))),
          ]),
        ),
      );
}
