import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:kadran/api.dart';
import 'package:kadran/bilesenler.dart';
import 'package:kadran/ekranlar/takip.dart';
import 'package:kadran/ekranlar/teklif.dart';
import 'package:kadran/foto.dart';
import 'package:kadran/dert.dart';
import 'package:kadran/tema.dart';
import 'package:kadran/zaman.dart';

/* Uygulamanın sunucudan bağımsız parçalarının denemeleri: Türkçe tarih/süre yazımı, eylem sonucunun
   okunması ve ortak bileşenler (seçim sayfası, durum rozeti, alt gezinme rozeti). */

Widget _sar(Widget w) => MaterialApp(theme: kadranTemasi(), home: Scaffold(body: w));

void main() {
  group('zaman', () {
    test('süre yazımı', () {
      expect(sureYaz(45), '45 dakika');
      expect(sureYaz(60), '1 saat');
      expect(sureYaz(90), '1,5 saat');
      expect(sureYaz(480), '8 saat');
    });
    test('telefon ve tarih', () {
      expect(telefonYaz('5551234567'), '0555 123 45 67');
      expect(gunEkle('2026-12-31', 1), '2027-01-01');
      expect(tarihKisa('2026-11-18'), '18 Kasım');
      expect(gunEtiketi(bugunIso()), 'Bugün');
      expect(gunEtiketi(gunEkle(bugunIso(), 1)), 'Yarın');
    });
  });

  test('eylem sonucundaki yönlendirme parametresi', () {
    final s = EylemSonucu(tamam: true, yonlendir: '/randevu/kemal-aydin?arac=1&adim=kod&k=abc-123');
    expect(s.parametre('adim'), 'kod');
    expect(s.parametre('k'), 'abc-123');
    expect(EylemSonucu().parametre('k'), isNull);
  });

  testWidgets('seçim kutusu: sayfa açılır, aranır, seçilir', (t) async {
    String? secilen;
    await t.pumpWidget(_sar(StatefulBuilder(
      builder: (c, yenile) => SecimKutusu(
        etiket: 'İl',
        bos: 'İl seç',
        deger: secilen,
        gruplar: [SecenekGrubu([for (final il in ['Adana', 'Ankara', 'İstanbul', 'İzmir', 'Şanlıurfa', 'Çorum', 'Bursa', 'Konya', 'Kars', 'Muş', 'Rize', 'Van', 'Uşak']) Secenek(il, il)])],
        onSec: (v) => yenile(() => secilen = v),
      ),
    )));
    expect(find.text('İl seç'), findsOneWidget);
    await t.tap(find.text('İl seç'));
    await t.pumpAndSettle();
    // 12'den uzun listede arama kutusu var; Türkçe harf farkı yok sayılır ("sanli" → Şanlıurfa).
    await t.enterText(find.byType(TextField), 'sanli');
    await t.pumpAndSettle();
    expect(find.text('Ankara'), findsNothing);
    await t.tap(find.text('Şanlıurfa'));
    await t.pumpAndSettle();
    expect(secilen, 'Şanlıurfa');
    expect(find.text('Şanlıurfa'), findsOneWidget);
  });

  testWidgets('durum rozeti ve alt gezinme rozeti', (t) async {
    await t.pumpWidget(_sar(Column(children: [
      const DurumRozeti('bekliyor'),
      const DurumRozeti('onaylandi'),
      AltCubuk(secili: 0, onSec: (_) {}, sekmeler: const [AltSekme('Usta bul', Icons.search), AltSekme('Mesajlar', Icons.chat_bubble_outline, rozet: 3)]),
    ])));
    expect(find.text('Onay bekliyor'), findsOneWidget);
    expect(find.text('Onaylandı'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Mesajlar, 3 yeni'), findsOneWidget);
  });

  test('para yazımı (sitedeki tlYaz ile aynı)', () {
    expect(tlYaz(2350), '2.350 TL');
    expect(tlYaz(1250.5), '1.250,50 TL');
    expect(tlYaz(1250000), '1.250.000 TL');
    expect(tlYaz(450), '450 TL');
    expect(fiyatAraligi(2400, 3200), '2.400 TL – 3.200 TL');
    expect(fiyatAraligi(500, 500), '500 TL');
  });

  testWidgets('tarih seçici: gün, ay, yıl seçilir, temizlenir', (t) async {
    String? tarih = '2027-01-31';
    await t.pumpWidget(_sar(StatefulBuilder(builder: (c, yenile) => TarihSecici(etiket: 'Muayene', deger: tarih, onSec: (v) => yenile(() => tarih = v)))));
    expect(find.text('31'), findsOneWidget);
    expect(find.text('Ocak'), findsOneWidget);
    // Şubat seçilince 31 gün yok: ayın son gününe çekilir.
    await t.tap(find.text('Ocak'));
    await t.pumpAndSettle();
    await t.tap(find.text('Şubat'));
    await t.pumpAndSettle();
    expect(tarih, '2027-02-28');
    await t.tap(find.text('Temizle'));
    await t.pump();
    expect(tarih, isNull);
    expect(find.text('Gün'), findsOneWidget);
  });

  testWidgets('fotoğraf alanı: önizleme, kaldırma, sınır', (t) async {
    // 1x1 PNG
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    var fotolar = [SecilenFoto('a.png', 'image/png', png), SecilenFoto('b.png', 'image/png', png)];
    await t.pumpWidget(_sar(StatefulBuilder(builder: (c, yenile) => FotoAlani(fotolar: fotolar, enCok: 2, onDegis: (f) => yenile(() => fotolar = f)))));
    // Sınıra gelince ekleme düğmesi yok.
    expect(find.text('Fotoğraf çek ya da seç'), findsNothing);
    expect(find.text('Bir fotoğraf daha ekle'), findsNothing);
    await t.tap(find.byTooltip('Fotoğraf 1: kaldır'));
    await t.pump();
    expect(fotolar.map((f) => f.ad), ['b.png']);
    expect(find.text('Bir fotoğraf daha ekle'), findsOneWidget);
    expect(fotolar.first.alan['tur'], 'image/png');
    expect(base64Decode(fotolar.first.alan['dosya']!), png);
  });

  test('soru ağacı: yürüme, sonuç, geçersiz yol, özet', () {
    final agac = <String, dynamic>{
      'kok': {
        'soru': 'Aracında ne oluyor?',
        'secenekler': [
          {'kod': 'ses', 'etiket': 'Bir ses geliyor', 'sonraki': 'ses'},
          {'kod': 'bilmiyorum', 'etiket': 'Tarif edemiyorum', 'sonuc': {'hizmet': 'cihaz', 'aciliyet': 'yakinda', 'not': 'x'}},
        ],
      },
      'ses': {
        'soru': 'Ses ne zaman geliyor?',
        'secenekler': [
          {'kod': 'fren', 'etiket': 'Fren yaparken (cızırtı)', 'sonuc': {'hizmet': 'balata', 'aciliyet': 'dur', 'not': 'y'}},
        ],
      },
    };
    expect(dertAdimi(agac, const [])!.soruKodu, 'kok');
    expect(dertAdimi(agac, ['ses'])!.soru!['soru'], 'Ses ne zaman geliyor?');
    final son = dertAdimi(agac, ['ses', 'fren'])!;
    expect(son.sonuc!['hizmet'], 'balata');
    expect(son.gecmis.length, 2);
    expect(dertAdimi(agac, ['ses', 'yok']), isNull);
    expect(dertAdimi(agac, ['bilmiyorum', 'fazla']), isNull);
    expect(dertOzeti(son, 'Önden ses var'), 'Önden ses var\nSoru ağacındaki cevaplarım: Bir ses geliyor → Fren yaparken.');
  });

  testWidgets('saat ızgarası seçili saati işaretler', (t) async {
    String? secili;
    await t.pumpWidget(_sar(StatefulBuilder(builder: (c, yenile) => SaatIzgarasi(saatler: const ['09:00', '09:30', '10:00'], secili: secili, onSec: (s) => yenile(() => secili = s)))));
    await t.tap(find.text('09:30'));
    await t.pump();
    expect(secili, '09:30');
  });
}
