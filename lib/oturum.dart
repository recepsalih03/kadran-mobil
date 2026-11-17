import 'dart:async';

import 'package:flutter/widgets.dart';

import 'api.dart';

/// Giriş yapan kişi.
class Kullanici {
  Kullanici(this.veri);
  final Map<String, dynamic> veri;
  String get id => veri['id'];
  String get rol => veri['rol'];
  String get ad => veri['ad'];
  String? get eposta => veri['eposta'];
  String? get telefon => veri['telefon'];
  String? get il => veri['il'];
  String? get ilce => veri['ilce'];
  String? get ustaDurumu => veri['ustaDurumu'];
  bool get usta => rol == 'usta';
  String get ilkAd => ad.split(' ').first;
}

/// Uygulamanın oturum durumu: kim giriş yaptı, okunmamış mesaj sayısı.
/// Okunmamış sayısı açıkken 15 saniyede bir yenilenir (sitedeki rozet gibi).
class Oturum extends ChangeNotifier {
  Oturum._();
  static final ben = Oturum._();

  Kullanici? kullanici;
  int okunmamis = 0;
  bool hazir = false;
  Timer? _zamanlayici;

  Future<void> yukle() async {
    try {
      final b = await Api.ben.veri('ben');
      final k = b['kullanici'];
      kullanici = k == null ? null : Kullanici(Map<String, dynamic>.from(k));
      okunmamis = (b['okunmamis'] as num?)?.toInt() ?? 0;
    } on ApiHatasi {
      kullanici = null;
    }
    hazir = true;
    _zamanlayici?.cancel();
    if (kullanici != null) {
      _zamanlayici = Timer.periodic(const Duration(seconds: 15), (_) => _rozetiYenile());
    }
    notifyListeners();
  }

  Future<void> _rozetiYenile() async {
    try {
      final b = await Api.ben.veri('ben');
      final yeni = (b['okunmamis'] as num?)?.toInt() ?? 0;
      if (yeni != okunmamis) {
        okunmamis = yeni;
        notifyListeners();
      }
    } on ApiHatasi catch (e) {
      if (e.giris) await cikisYapildi();
    }
  }

  Future<void> cikis() async {
    await Api.ben.eylem('cikis', {});
    await cikisYapildi();
  }

  Future<void> cikisYapildi() async {
    _zamanlayici?.cancel();
    await Api.ben.oturumuUnut();
    kullanici = null;
    okunmamis = 0;
    notifyListeners();
  }
}
