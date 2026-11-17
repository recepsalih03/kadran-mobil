import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'bilesenler.dart';
import 'ekranlar/giris.dart';
import 'ekranlar/musteri.dart';
import 'ekranlar/usta.dart';
import 'oturum.dart';
import 'tema.dart';

/*
  Kadran mobil uygulaması. Web sitesiyle aynı sunucuyu (sitenin /api/m uçlarını) kullanır;
  tasarım sitenin aynısıdır: lacivert üst şerit, açık gri gruplar, turuncu seçili durum, Inter yazı.
  Girişe göre iki yüz: araç sahibi (usta bul, randevular, mesajlar, araçlar, hesap) ve usta
  (özet, randevular, mesajlar, takvim). Giriş yapmadan da ustalara ve boş saatlere bakılabilir.
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Otomatik denemede (web önizlemesi) ekran okuyucu ağacı baştan açılır; düğmeler yazılarıyla bulunur.
  if (const bool.fromEnvironment('ERISILEBILIRLIK_ACIK')) SemanticsBinding.instance.ensureSemantics();
  await Api.ben.hazirla();
  runApp(const KadranUygulamasi());
}

class KadranUygulamasi extends StatelessWidget {
  const KadranUygulamasi({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kadran',
        debugShowCheckedModeBanner: false,
        theme: kadranTemasi(),
        home: const Kok(),
      );
}

/// Kök: oturuma göre doğru yüzü gösterir; oturum düşerse girişsiz yüze döner.
class Kok extends StatefulWidget {
  const Kok({super.key});
  @override
  State<Kok> createState() => _KokState();
}

class _KokState extends State<Kok> {
  StreamSubscription<void>? _dusme;

  @override
  void initState() {
    super.initState();
    Oturum.ben.addListener(_degisti);
    Oturum.ben.yukle();
    _dusme = Api.ben.oturumDustu.stream.listen((_) {
      if (Oturum.ben.kullanici != null) Oturum.ben.cikisYapildi();
    });
  }

  @override
  void dispose() {
    Oturum.ben.removeListener(_degisti);
    _dusme?.cancel();
    super.dispose();
  }

  void _degisti() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final o = Oturum.ben;
    if (!o.hazir) return const _Acilis();
    final k = o.kullanici;
    if (k == null) return const MusteriKabuk(misafir: true);
    if (k.rol == 'musteri') return const MusteriKabuk();
    if (k.rol == 'usta') return k.ustaDurumu == 'onaylandi' ? const UstaKabuk() : UstaBasvuruDurumu(kullanici: k);
    return const YoneticiBilgi();
  }
}

/// Açılış: lacivert zeminde logo (oturum kontrol edilirken bir an görünür).
class _Acilis extends StatelessWidget {
  const _Acilis();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Renk.lacivert,
        body: Center(child: Image.asset('assets/resim/logo-beyaz.png', width: 200, semanticLabel: 'Kadran')),
      );
}

/// Yönetici hesabı: yönetim paneli yalnız sitede.
class YoneticiBilgi extends StatelessWidget {
  const YoneticiBilgi({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: Sayfa(children: [
          const Konum(baslik: 'Yönetim', aciklama: 'Yönetim paneli yalnız sitede açılır.'),
          AnaDugme(etiket: 'Yönetim panelini aç', onPressed: () => siteyiAc('/yonetim')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: Oturum.ben.cikis, child: const Text('Çıkış yap')),
        ]),
      );
}
