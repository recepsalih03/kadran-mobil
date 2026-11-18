# Kadran'ı iPhone'a kurmak (kendi MacBook'unla)

Ücretsiz Apple hesabınla, kablo ile kendi iPhone'una kurarsın. Ücretli geliştirici üyeliği gerekmez. Tek eksiği: uygulama **7 günde bir** yeniden kurulmalı (aşağıdaki 11. adımı tekrarlamak yeter, yaklaşık 2 dakika).

İlk kurulum yaklaşık 1–1,5 saat sürer; çoğu Xcode'un inmesini beklemek.

---

## Bir kez yapılacaklar

### 1. Xcode

1. Mac'te **App Store** > "Xcode" ara > **Al / Yükle** (yaklaşık 10 GB, uzun sürer).
2. Xcode'u bir kez aç. Lisansı kabul et. "iOS" platformunu indirmeni isterse indir (Xcode > Settings > Components > iOS).
3. **Terminal**'i aç (Spotlight: Cmd + Boşluk > "Terminal") ve:
   ```bash
   sudo xcodebuild -license accept
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
   Şifre sorarsa Mac'inin şifresi (yazarken görünmez, normal).

### 2. Homebrew, Flutter, CocoaPods

Terminal'de sırayla:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Kurulumun sonunda "Next steps" altında iki satırlık bir komut yazar (`echo ... >> ~/.zprofile` ve `eval ...`). **O iki satırı kopyalayıp çalıştır.** Sonra:

```bash
brew install --cask flutter
brew install cocoapods
flutter --version
flutter doctor
```

- `flutter --version` **3.50 veya üstü** olmalı (Windows'taki proje bu sürümle yazıldı).
- `flutter doctor` çıktısında **Xcode** satırı ✓ olmalı. Android ile ilgili ✗'ler önemli değil.

### 3. Projeyi indir

Depo gizli olduğu için GitHub'a giriş gerekir. En kolayı:

```bash
brew install gh
gh auth login
```

Sorulara: GitHub.com → HTTPS → Yes → **Login with a web browser**. Ekrandaki kodu tarayıcıda gir. Sonra:

```bash
cd ~/Desktop
gh repo clone recepsalih03/kadran-mobil
cd kadran-mobil
flutter pub get
```

### 4. iPhone'u hazırla

1. iPhone'u **kabloyla** Mac'e tak. iPhone'da "Bu bilgisayara güvenilsin mi?" → **Güven**, iPhone şifreni gir.
2. iPhone'da **Ayarlar > Gizlilik ve Güvenlik > Geliştirici Modu** → aç → iPhone yeniden başlar → açılınca "Geliştirici Modunu aç" → **Aç**.
   - "Geliştirici Modu" görünmüyorsa: önce 5. adımı yap, Xcode iPhone'u görünce bu seçenek çıkar.

### 5. Xcode'da imza (ücretsiz Apple hesabı)

1. Terminal'de (kadran-mobil klasöründeyken):
   ```bash
   flutter build ios --debug --no-codesign
   open ios/Runner.xcworkspace
   ```
2. Xcode açılınca soldaki listede en üstteki mavi **Runner**'a tıkla > ortada **TARGETS** altında **Runner** > üstte **Signing & Capabilities** sekmesi.
3. **Automatically manage signing** işaretli olsun.
4. **Team** kutusu > **Add an Account…** > Apple ID'nle giriş yap > geri dönünce Team olarak **"Adın (Personal Team)"** seç.
5. **Bundle Identifier** `com.kadran.kadran`. Altında kırmızı "cannot be registered" yazarsa bu kimliği başkası almış demektir: sonuna bir şey ekle (ör. `com.kadran.kadran2`) ve bana yaz, projede de değiştireyim.
6. Kırmızı hata kalmayınca Xcode'u kapatabilirsin.

---

## Her kurulumda (ve 7 günde bir)

### 6. Siteyi Windows bilgisayarda aç

Uygulama bilgisayardaki siteye bağlanır. Windows'ta (kadran klasöründe):

```bash
npm run build
npm run start -- -p 3000 -H 0.0.0.0
```

- **Mac, iPhone ve Windows aynı Wi-Fi'de** olmalı; Windows'ta güvenlik duvarı izni (sitenin test planı 0.6).
- **Kontrol:** iPhone'da Safari'ye `http://192.168.1.218:3000` yaz. Site açılmalı. Açılmazsa Windows'ta PowerShell'de `ipconfig` > Wi-Fi > IPv4 Address'e bak; adres farklıysa aşağıdaki komutta onu kullan.

### 7. Uygulamayı iPhone'a kur

iPhone kabloyla takılıyken Mac'te Terminal (kadran-mobil klasöründe):

```bash
cd ~/Desktop/kadran-mobil
git pull
flutter pub get
flutter devices
flutter run --release -d <iPhone'un adı ya da kimliği> --dart-define=KADRAN_SITE=http://192.168.1.218:3000
```

- `flutter devices` listesinde iPhone'unu görürsün (ör. "Recep'in iPhone'u"). `-d` yanına o satırdaki adı ya da kimliği yaz. Tek cihaz bağlıysa `-d …` kısmını yazmasan da olur.
- İlk derleme 5–10 dakika sürebilir; sonrakiler daha kısa.
- `--release` önemli: bununla kurulan uygulama kablo çıkınca da ana ekrandan açılır.
- `git pull` her seferinde son sürümü getirir; ben güncelleme yaptıktan sonra bu adımı tekrarla.

### 8. İlk açılış

1. İlk açılışta "Güvenilmeyen Geliştirici" derse: iPhone'da **Ayarlar > Genel > VPN ve Cihaz Yönetimi** > Apple ID'n > **Güven**. Sonra uygulamayı yeniden aç.
2. "Kadran yerel ağdaki aygıtları bulmak istiyor" → **İzin Ver** (bilgisayardaki siteye bağlanmak için gerekli).
3. Kamera ve fotoğraf izinleri ilk fotoğraf eklerken sorulur.

Bundan sonra uygulamayı denemek için test planı: `TEST-SENARYOLARI.md` (Android için yazıldı; iPhone'da da aynı. Geri tuşu yerine soldan sağa kaydırma ya da sol üstteki geri oku).

---

## Sorun çıkarsa

| Ne oldu | Ne yap |
|---|---|
| Uygulamada "Sunucuya ulaşılamadı" | iPhone Safari'de `http://192.168.1.218:3000` açılıyor mu? Açılmıyorsa sorun ağda (aynı Wi-Fi, Windows güvenlik duvarı, adres). Açılıyorsa iPhone **Ayarlar > Kadran > Yerel Ağ** açık mı bak. |
| `flutter devices` iPhone'u göstermiyor | Kabloyu çıkarıp tak, iPhone'un kilidi açık olsun, "Güven" dedin mi bak. Xcode > Window > Devices and Simulators'da iPhone görünüyor mu? |
| "Developer Mode disabled" | 4. adım: Geliştirici Modu. |
| "No valid code signing certificates" ya da "Signing for Runner requires a development team" | 5. adım: Xcode'da Team seçimi. |
| CocoaPods hatası | `cd ios && pod install --repo-update && cd ..`, sonra 7. adımı tekrarla. |
| 7 gün sonra uygulama açılmıyor | Ücretsiz hesabın sınırı. 7. adımı tekrarla. |
| Başka bir hata | Terminal'deki son 20–30 satırı kopyalayıp bana gönder. |

---

## Sonra: başkalarına dağıtmak ve App Store

Başka iPhone'lara kurmak (TestFlight) ve App Store için **Apple Developer Program** üyeliği gerekir (yıllık 99 dolar). O aşamada:

- `ios/Runner/Info.plist` içindeki **NSAppTransportSecurity / NSAllowsArbitraryLoads** bölümü kaldırılacak (site https olacak; Apple bu ayarı gerekçesiz kabul etmez).
- Uygulama `--dart-define=KADRAN_SITE=https://alan-adin.com` ile derlenecek.
- Mağaza için gizlilik beyanı (App Privacy) doldurulacak. Uygulama reklam kimliği kullanmaz, kullanıcıyı başka uygulamalarda izlemez; toplananlar hesap bilgileri, randevu ve mesaj içerikleri, isteğe bağlı fotoğraflar ve kimliksiz kullanım sayıları.
