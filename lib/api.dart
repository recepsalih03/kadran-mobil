import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Kadran sitesinin adresi. Derlerken verilir: flutter build apk --dart-define=KADRAN_SITE=https://kadran.com.tr
/// Verilmezse Android öykünücüsünden bilgisayardaki siteye (10.0.2.2:3000) bağlanır.
/// Web derlemesinde uygulama sitenin kendi adresinden sunulduğu için göreli adres kullanılır.
const _siteAdresi = String.fromEnvironment('KADRAN_SITE', defaultValue: 'http://10.0.2.2:3000');
String get siteAdresi => kIsWeb ? '' : _siteAdresi;

/// Bir eylemin sonucu (sitedeki form sonucunun aynısı).
class EylemSonucu {
  EylemSonucu({this.tamam = false, this.yonlendir, this.hata, this.alanlar = const {}, this.giris = false});
  final bool tamam;
  /// Eylem başarılı olup sitede bir sayfaya yönlendirdiyse o adres (ör. "/dogrula?k=…").
  final String? yonlendir;
  final String? hata;
  final Map<String, String> alanlar;
  /// Oturum düştü: giriş ekranına dönülmeli.
  final bool giris;

  /// Yönlendirme adresindeki bir parametre ("k" gibi).
  String? parametre(String ad) => yonlendir == null ? null : Uri.parse('http://x$yonlendir').queryParameters[ad];
}

class ApiHatasi implements Exception {
  ApiHatasi(this.mesaj, {this.giris = false});
  final String mesaj;
  final bool giris;
  @override
  String toString() => mesaj;
}

/// Siteyle konuşan tek yer. Oturum, sitedeki gibi "kadran_oturum" çereziyle taşınır:
/// telefonda güvenli depoda saklanır ve her isteğe eklenir (web'de tarayıcı kendisi taşır).
class Api {
  Api._();
  static final ben = Api._();

  static const _depo = FlutterSecureStorage();
  static const _anahtar = 'kadran_oturum';
  String? _cerez;
  /// Oturum düşünce (401) dinleyenlere haber verilir; uygulama giriş ekranına döner.
  final oturumDustu = StreamController<void>.broadcast();

  Future<void> hazirla() async {
    if (!kIsWeb) _cerez = await _depo.read(key: _anahtar);
  }

  bool get oturumVar => kIsWeb || _cerez != null;

  /// Fotoğraf gibi doğrudan açılan adresler için oturum başlığı.
  Map<String, String> get fotoBasliklari => {if (_cerez != null) 'Cookie': '$_anahtar=$_cerez'};

  Map<String, String> get _basliklar => {
        'X-Kadran-Istemci': 'mobil',
        'Accept': 'application/json',
        if (!kIsWeb && _cerez != null) 'Cookie': '$_anahtar=$_cerez',
      };

  Future<void> _cerezAl(http.Response y) async {
    if (kIsWeb) return;
    final baslik = y.headers['set-cookie'];
    if (baslik == null) return;
    final m = RegExp(r'kadran_oturum=([^;]*)').firstMatch(baslik);
    if (m == null) return;
    final deger = m.group(1) ?? '';
    final silindi = deger.isEmpty || RegExp(r'Max-Age=0|expires=Thu, 01 Jan 1970', caseSensitive: false).hasMatch(baslik);
    if (silindi) {
      _cerez = null;
      await _depo.delete(key: _anahtar);
    } else {
      _cerez = deger;
      await _depo.write(key: _anahtar, value: deger);
    }
  }

  Future<void> oturumuUnut() async {
    _cerez = null;
    if (!kIsWeb) await _depo.delete(key: _anahtar);
  }

  /// Veri okur: `/api/m/veri/<ad>?…`
  Future<Map<String, dynamic>> veri(String ad, [Map<String, String>? sorgu]) async {
    final adres = Uri.parse('$siteAdresi/api/m/veri/$ad').replace(queryParameters: (sorgu == null || sorgu.isEmpty) ? null : sorgu);
    late http.Response y;
    try {
      y = await http.get(adres, headers: _basliklar).timeout(const Duration(seconds: 20));
    } on Exception {
      throw ApiHatasi('Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip yeniden dene.');
    }
    await _cerezAl(y);
    final govde = _coz(y);
    if (y.statusCode == 401) {
      oturumDustu.add(null);
      throw ApiHatasi(govde['hata'] as String? ?? 'Giriş yapman gerekir.', giris: true);
    }
    if (y.statusCode >= 400) throw ApiHatasi(govde['hata'] as String? ?? 'Bir şey ters gitti. Yeniden dene.');
    return govde;
  }

  /// Eylem çalıştırır: `/api/m/eylem/<ad>`; alanlar sitedeki form alanlarıdır.
  Future<EylemSonucu> eylem(String ad, Map<String, Object?> alanlar) async {
    late http.Response y;
    try {
      y = await http
          .post(Uri.parse('$siteAdresi/api/m/eylem/$ad'),
              headers: {..._basliklar, 'Content-Type': 'application/json'}, body: jsonEncode({'alanlar': alanlar}))
          .timeout(const Duration(seconds: 30));
    } on Exception {
      return EylemSonucu(hata: 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip yeniden dene.');
    }
    await _cerezAl(y);
    final g = _coz(y);
    if (y.statusCode == 401) {
      oturumDustu.add(null);
      return EylemSonucu(giris: true, hata: g['hata'] as String? ?? 'Giriş yapman gerekir.');
    }
    final alanHatalari = <String, String>{};
    final ah = g['alanlar'];
    if (ah is Map) ah.forEach((k, v) => alanHatalari['$k'] = '$v');
    if (y.statusCode >= 400 && g['hata'] == null) return EylemSonucu(hata: 'Bir şey ters gitti. Yeniden dene.');
    return EylemSonucu(tamam: g['tamam'] == true, yonlendir: g['yonlendir'] as String?, hata: g['hata'] as String?, alanlar: alanHatalari);
  }

  /// Sayfa yenileme izi (sitedeki /api/nabiz): değişince ekran yeniden yüklenir.
  Future<String?> nabiz([Map<String, String>? sorgu]) async {
    try {
      final y = await http
          .get(Uri.parse('$siteAdresi/api/nabiz').replace(queryParameters: sorgu), headers: _basliklar)
          .timeout(const Duration(seconds: 10));
      if (y.statusCode != 200) return null;
      return (_coz(y)['iz'] as String?);
    } on Exception {
      return null;
    }
  }

  Map<String, dynamic> _coz(http.Response y) {
    try {
      final v = jsonDecode(utf8.decode(y.bodyBytes));
      return v is Map<String, dynamic> ? v : {};
    } on FormatException {
      return {};
    }
  }
}
