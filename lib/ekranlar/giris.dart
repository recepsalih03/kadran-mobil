import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../bilesenler.dart';
import '../katalog.dart';
import '../oturum.dart';
import '../tema.dart';

/* Giriş, kayıt ve doğrulama kodu. Kurallar ve hata metinleri sitedekiyle aynıdır (sunucu doğrular). */

/// Sitede bir sayfayı tarayıcıda açar (usta başvurusu, şifre yenileme, koşullar gibi uygulamada olmayanlar).
Future<void> siteyiAc(String yol) async {
  final taban = siteAdresi.isEmpty ? Uri.base.origin : siteAdresi;
  await launchUrl(Uri.parse('$taban$yol'), mode: LaunchMode.externalApplication);
}

/// Giriş. Başarılı olunca true döner (randevu gibi bir işin ortasından açıldıysa oraya dönülür).
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});
  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _kimlik = TextEditingController();
  final _sifre = TextEditingController();
  EylemSonucu? _sonuc;
  bool _bekliyor = false;
  bool _goster = false;

  Future<void> _gir() async {
    setState(() => _bekliyor = true);
    final s = await Api.ben.eylem('giris', {'kimlik': _kimlik.text, 'sifre': _sifre.text});
    if (!mounted) return;
    setState(() {
      _sonuc = s;
      _bekliyor = false;
    });
    if (s.yonlendir?.startsWith('/dogrula') == true) {
      // Hesap doğrulanmamış: kod gönderildi.
      final tamam = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DogrulaEkrani(k: s.parametre('k')!)));
      if (tamam == true && mounted) Navigator.pop(context, true);
      return;
    }
    if (s.tamam) {
      await Oturum.ben.yukle();
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _sonuc?.alanlar ?? {};
    return Scaffold(
      appBar: ustSerit(context),
      body: AutofillGroup(
        child: Sayfa(children: [
          const Konum(baslik: 'Giriş yap', aciklama: 'Telefon numaran ya da e-postan ve şifrenle.'),
          if (_sonuc?.hata != null && !_sonuc!.tamam) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 16)],
          Alan(
            etiket: 'Telefon numarası ya da e-posta',
            ipucu: 'Telefon: başında 0 olmadan 10 hane. E-posta: ornek@site.com',
            hata: h['kimlik'],
            child: MetinKutusu(kontrol: _kimlik, hata: h['kimlik'] != null, klavye: TextInputType.emailAddress, otomatik: const [AutofillHints.username]),
          ),
          const SizedBox(height: 18),
          Alan(
            etiket: 'Şifre',
            hata: h['sifre'],
            child: Stack(alignment: Alignment.centerRight, children: [
              MetinKutusu(kontrol: _sifre, gizli: !_goster, hata: h['sifre'] != null, otomatik: const [AutofillHints.password]),
              TextButton(onPressed: () => setState(() => _goster = !_goster), child: Text(_goster ? 'Gizle' : 'Göster')),
            ]),
          ),
          const SizedBox(height: 24),
          AnaDugme(etiket: 'Giriş yap', bekliyor: _bekliyor, onPressed: _gir, simge: Icons.arrow_forward),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => siteyiAc('/sifremi-unuttum'), child: const Text('Şifremi unuttum'))),
          const SizedBox(height: 16),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hesabın yok mu?', style: Yazi.govdeKalin),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final tamam = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const KayitEkrani()));
                    if (tamam == true && context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Araç sahibi olarak kayıt ol'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => siteyiAc('/usta-kayit'), child: const Text('Usta olarak başvur'))),
              const SizedBox(height: 6),
              const Text('Usta başvurusu belge yüklemeyle birlikte sitede yapılır.', style: Yazi.kucuk),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Araç sahibi kaydı: ad, telefon ya da e-posta, il ve ilçe, şifre, onay.
class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});
  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  final _ad = TextEditingController();
  final _telefon = TextEditingController();
  final _eposta = TextEditingController();
  final _sifre = TextEditingController();
  String _yontem = 'telefon';
  String? _il, _ilce;
  bool _onay = false;
  bool _bekliyor = false;
  EylemSonucu? _sonuc;

  Future<void> _kaydol() async {
    setState(() => _bekliyor = true);
    final s = await Api.ben.eylem('kayit', {
      'yontem': _yontem,
      'ad': _ad.text,
      'telefon': _telefon.text,
      'eposta': _eposta.text,
      'il': _il ?? '',
      'ilce': _ilce ?? '',
      'sifre': _sifre.text,
      if (_onay) 'kvkk': 'on',
    });
    if (!mounted) return;
    setState(() {
      _sonuc = s;
      _bekliyor = false;
    });
    final k = s.parametre('k');
    if (s.tamam && k != null) {
      final tamam = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DogrulaEkrani(k: k)));
      if (tamam == true && mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _sonuc?.alanlar ?? {};
    return Scaffold(
      appBar: ustSerit(context),
      body: VeriEkrani<Katalog>(
        yukle: Katalog.al,
        icerik: (context, katalog, _) => Sayfa(children: [
          const Konum(baslik: 'Kayıt ol', aciklama: 'Bir dakikada hesabını aç, ustalardan randevu al.'),
          if (_sonuc?.hata != null && !_sonuc!.tamam) ...[
            Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!, metin: h.isNotEmpty ? 'Kırmızı yazılı kutuları düzeltip tekrar dene.' : null),
            const SizedBox(height: 16),
          ],
          Alan(etiket: 'Ad soyad', hata: h['ad'], child: MetinKutusu(kontrol: _ad, hata: h['ad'] != null, otomatik: const [AutofillHints.name])),
          const SizedBox(height: 18),
          const Text('Neyle kayıt olmak istersin?', style: Yazi.ikincil),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: SecimDugmesi(
                secili: _yontem == 'telefon',
                onTap: () => setState(() => _yontem = 'telefon'),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.smartphone, size: 20), SizedBox(width: 8), Text('Telefonla', style: Yazi.govdeKalin)]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SecimDugmesi(
                secili: _yontem == 'eposta',
                onTap: () => setState(() => _yontem = 'eposta'),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.mail_outline, size: 20), SizedBox(width: 8), Text('E-postayla', style: Yazi.govdeKalin)]),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('Seçtiğine bir doğrulama kodu göndeririz. Sonra girişte de onu kullanırsın.', style: Yazi.ikincil),
          const SizedBox(height: 18),
          if (_yontem == 'telefon')
            Alan(
              etiket: 'Telefon numarası',
              ipucu: 'Başında 0 olmadan, 10 hane: 5XX XXX XX XX',
              hata: h['telefon'],
              child: MetinKutusu(kontrol: _telefon, hata: h['telefon'] != null, klavye: TextInputType.phone, otomatik: const [AutofillHints.telephoneNumberNational]),
            )
          else
            Alan(etiket: 'E-posta', hata: h['eposta'], child: MetinKutusu(kontrol: _eposta, hata: h['eposta'] != null, klavye: TextInputType.emailAddress, otomatik: const [AutofillHints.email])),
          const SizedBox(height: 18),
          Alan(
            etiket: 'Hangi ildesin?',
            hata: h['il'],
            child: SecimKutusu(
              etiket: 'İl',
              bos: 'İl seç',
              deger: _il,
              hata: h['il'] != null,
              gruplar: [SecenekGrubu([for (final il in katalog.iller.keys) Secenek(il, il)])],
              onSec: (v) => setState(() {
                _il = v;
                _ilce = null;
              }),
            ),
          ),
          const SizedBox(height: 18),
          Alan(
            etiket: 'Hangi ilçedesin?',
            ipucu: 'Sana yakın ustaları önce gösteririz.',
            hata: h['ilce'],
            child: SecimKutusu(
              etiket: 'İlçe',
              bos: _il == null ? 'Önce ili seç' : 'İlçe seç',
              deger: _ilce,
              hata: h['ilce'] != null,
              gruplar: [SecenekGrubu([for (final i in katalog.iller[_il] ?? const <String>[]) Secenek(i, i)])],
              onSec: (v) => setState(() => _ilce = v),
            ),
          ),
          const SizedBox(height: 18),
          Alan(etiket: 'Şifre', ipucu: 'En az 8 karakter.', hata: h['sifre'], child: MetinKutusu(kontrol: _sifre, gizli: true, hata: h['sifre'] != null, otomatik: const [AutofillHints.newPassword])),
          const SizedBox(height: 18),
          InkWell(
            onTap: () => setState(() => _onay = !_onay),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: _onay, onChanged: (v) => setState(() => _onay = v ?? false), activeColor: Renk.lacivert),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(children: [
                    _baglanti('Kullanım koşullarını', '/kosullar'),
                    const Text(' kabul ediyorum, ', style: Yazi.govde),
                    _baglanti('aydınlatma metnini', '/kvkk'),
                    const Text(' okudum.', style: Yazi.govde),
                  ]),
                ),
              ),
            ]),
          ),
          if (h['kvkk'] != null) Text(h['kvkk']!, style: Yazi.govdeKalin.copyWith(color: Renk.hayir)),
          const SizedBox(height: 24),
          AnaDugme(etiket: 'Hesap oluştur', bekliyor: _bekliyor, onPressed: _kaydol, simge: Icons.arrow_forward),
        ]),
      ),
    );
  }

  Widget _baglanti(String yazi, String yol) => GestureDetector(
        onTap: () => siteyiAc(yol),
        child: Text(yazi, style: Yazi.govdeKalin.copyWith(decoration: TextDecoration.underline)),
      );
}

/// Doğrulama kodu (kayıt ya da doğrulanmamış hesapla giriş). Doğrulanınca oturum açılır, true döner.
class DogrulaEkrani extends StatefulWidget {
  const DogrulaEkrani({super.key, required this.k});
  final String k;
  @override
  State<DogrulaEkrani> createState() => _DogrulaEkraniState();
}

class _DogrulaEkraniState extends State<DogrulaEkrani> {
  late String _k = widget.k;
  final _kod = TextEditingController();
  EylemSonucu? _sonuc;
  bool _bekliyor = false;
  bool _yeni = false;
  final _anahtar = GlobalKey<VeriEkraniState<Map<String, dynamic>>>();

  Future<void> _dogrula() async {
    setState(() => _bekliyor = true);
    final s = await Api.ben.eylem('dogrula', {'k': _k, 'kod': _kod.text});
    if (!mounted) return;
    setState(() {
      _sonuc = s;
      _bekliyor = false;
    });
    if (s.tamam) {
      await Oturum.ben.yukle();
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _tekrar() async {
    final s = await Api.ben.eylem('kod-tekrar', {'k': _k});
    if (!mounted) return;
    final yeni = s.parametre('k');
    if (yeni != null) {
      setState(() {
        _k = yeni;
        _yeni = true;
        _sonuc = null;
      });
      _anahtar.currentState?.yenile();
    } else {
      setState(() => _sonuc = s);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: ustSerit(context),
        body: VeriEkrani<Map<String, dynamic>>(
          key: _anahtar,
          yukle: () => Api.ben.veri('kod', {'k': _k}),
          icerik: (context, kod, _) => Sayfa(children: [
            const Konum(baslik: 'Hesabını doğrula'),
            Text('${kod['hedef']} ${kod['kanal'] == 'sms' ? 'numarasına SMS ile' : 'adresine e-postayla'} 6 haneli bir kod gönderdik. Kod 10 dakika geçerli.', style: Yazi.govde),
            const SizedBox(height: 16),
            if (_yeni) ...[const Uyari(tur: UyariTuru.basari, baslik: 'Yeni kodu gönderdik. Gelen son kodu yaz.'), const SizedBox(height: 12)],
            if (kod['testKodu'] != null) ...[
              Panel(child: Row(children: [
                const Expanded(child: Text('Test modu: ileti gerçekten gönderilmedi. Kodun:', style: Yazi.ikincil)),
                Text('${kod['testKodu']}', style: Yazi.rakam.copyWith(fontSize: 24)),
              ])),
              const SizedBox(height: 16),
            ],
            if (_sonuc?.hata != null) ...[Uyari(tur: UyariTuru.hata, baslik: _sonuc!.hata!), const SizedBox(height: 16)],
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
            AnaDugme(etiket: 'Doğrula', bekliyor: _bekliyor, onPressed: _dogrula),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _tekrar, child: const Text('Yeni kod gönder'))),
          ]),
        ),
      );
}

/// Girişsiz kişi giriş gerektiren bir şeye dokununca: giriş ekranını açar, girdiyse true.
Future<bool> girisIste(BuildContext context) async {
  if (Oturum.ben.kullanici != null) return true;
  final tamam = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const GirisEkrani()));
  return tamam == true && Oturum.ben.kullanici != null;
}
