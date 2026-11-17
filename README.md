# Kadran mobil

Kadran'ın Flutter uygulaması (Android ve iOS). Sitenin sunucusunu kullanır; ayrı bir veritabanı ya da sunucu yoktur.
Kurallar, hata metinleri, saat tutma, bildirimler sitedekiyle birdir: uygulama sitenin `/api/m` uçlarına bağlanır
ve sitedeki sunucu eylemlerini aynen çalıştırır.

**Tasarım** sitenin aynısı: lacivert üst şerit ve KADRAN logosu, açık gri gruplar, turuncu seçili durum, Inter yazı,
gövde 17 px, dokunma alanları en az 48 px, yüklenirken iskelet (dönen halka yok).

## Ekranlar

- **Girişsiz:** usta bul (il/ilçe, iş, marka süzgeci, gün sekmeleri), usta sayfası. Randevu ve mesaj için giriş istenir.
- **Araç sahibi:** Usta bul · Randevular · Mesajlar · Araçlarım · Hesabım. Randevu: araç ve iş → gün ve saat → özet → kod → tamam.
  Randevu iptali, puanlama, ustaya mesaj, yol tarifi (Google Haritalar).
- **Usta:** Özet · Randevular · Mesajlar · Takvim. Talebi onayla/reddet, sonuçlandır, iptal et, elden randevu ekle, saat kapat,
  müşteriyi ara, müşteriye yaz. Çalışma saatleri, belgeler ve başvuru sitede düzenlenir (uygulama bağlantıyla açar).
- Sitede kalanlar: usta başvurusu ve belge yükleme, şifre yenileme, hesap silme, yönetim paneli.

## Dosyalar

| Yol | İçerik |
|---|---|
| `lib/main.dart` | Giriş noktası; oturuma göre araç sahibi ya da usta yüzü |
| `lib/api.dart` | Siteyle konuşan tek yer (oturum çerezi güvenli depoda) |
| `lib/tema.dart` | Renkler, köşeler, yazılar (sitenin `globals.css` değerleri) |
| `lib/bilesenler.dart` | Ortak parçalar: başlık, panel, satırlar, seçim sayfası, saat ızgarası, rozetler, iskelet, alt çubuk |
| `lib/ekranlar/` | `giris.dart`, `musteri.dart`, `usta.dart`, `mesajlar.dart` |
| `test/` | Birim ve bileşen denemeleri: `flutter test` |
| `araclar/onizleme.mjs` | Web önizlemesi (uygulamayı tarayıcıda siteyle aynı adresten açar) |

## Çalıştırma

Araçlar `C:\Users\recep\gelistirme` altında: Flutter, Android SDK, JDK 17 (ortam değişkenleri kullanıcı hesabına yazıldı).

```bash
flutter pub get
flutter analyze
flutter test
```

**Telefonda deneme (bilgisayardaki siteye bağlı):** bilgisayarda siteyi aç (`kadran` klasöründe `npm run dev`), telefon aynı
Wi-Fi'de olsun. `build/app/outputs/flutter-apk/app-debug.apk` dosyasını telefona at ve kur (bilinmeyen kaynaklardan
yüklemeye izin vermen gerekir). Bu APK `http://192.168.1.218:3000` adresine bağlanır; bilgisayarın adresi değişirse yeniden derle:

```bash
flutter build apk --debug --dart-define=KADRAN_SITE=http://BILGISAYARIN-IP-ADRESI:3000
```

Windows güvenlik duvarı ilk seferde Node.js için izin isteyebilir; "Özel ağlar"a izin ver.

**Tarayıcıda önizleme:** `flutter build web --no-web-resources-cdn`, sonra `node araclar/onizleme.mjs 3300 http://localhost:3000`
ve `http://localhost:3300`.

## Yayın

1. Site yayına çıkınca uygulamayı gerçek adresle derle:
   `flutter build appbundle --release --dart-define=KADRAN_SITE=https://kadran.com.tr`
2. **Google Play:** Play Console hesabı (tek seferlik ücret). Uygulamayı imzalamak için bir yükleme anahtarı (keystore)
   oluşturulur ve `android/key.properties` ile tanıtılır; anahtar dosyası kaybedilmemeli, depoya konmamalı.
   Şu an yayın derlemesi geliştirme anahtarıyla imzalanıyor (`android/app/build.gradle.kts`); mağazaya göndermeden önce değişmeli.
3. **App Store:** Apple Developer hesabı (yıllık ücret) ve derleme için bir Mac gerekir; kod hazır (`ios/`).
4. Uygulama kimliği: `com.kadran.kadran`. Mağazaya göndermeden önce kesinleştir; sonradan değiştirilemez.

## Bilinen eksikler

- Telefona anlık bildirim (FCM/APNs) yok: yeni mesaj ve talepler uygulama açıkken birkaç saniyede kendiliğinden görünür.
  Uygulama kapalıyken bildirim için Firebase projesi gerekir.
- Mesaja fotoğraf ekleme uygulamada yok (görüntüleme var); sitede var.
- Konumla arama ("yakınımdaki ustalar") yok; il ve ilçe seçilir.
