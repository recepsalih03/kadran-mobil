# Kadran mobil — Test planı (Android)

Uygulamayı gerçek telefonda denemek için. Sitenin planı: `kadran/TEST-SENARYOLARI.md`. İkisi aynı sunucuyu ve aynı hesapları kullanır; bir tarafta yaptığın şey öbür tarafta da görünür.

Her senaryoda **ne yapacağın** ve **ne görmen gerektiği** (→) yazıyor. Olmayanları sonuç bildirme biçimiyle bana yaz.

---

## 0. Hazırlık (bir kez)

### 0.1 Siteyi bilgisayarda aç

Uygulama kendi başına çalışmaz; bilgisayardaki siteye bağlanır. Sitenin planındaki **0.1 – 0.6** adımlarını yap. Kısaca:

```bash
cd C:\Users\recep\Desktop\kadran
npm run build
npm run start -- -p 3000 -H 0.0.0.0
```

- Bilgisayar ve telefon **aynı Wi-Fi**'de olmalı; Wi-Fi profili **Özel**; güvenlik duvarında 3000 açık (site planı 0.6).
- **Kontrol:** telefonun tarayıcısında `http://192.168.1.218:3000` açılıyor mu? Açılmıyorsa uygulama da bağlanamaz. Önce bunu çöz.
- Bilgisayarın adresi değiştiyse (PowerShell'de `ipconfig` > Wi-Fi > IPv4 Address artık 192.168.1.218 değilse) bana yeni adresi yaz; uygulamayı o adresle yeniden derlerim.

### 0.2 Uygulamayı telefona kur

Dosya: `C:\Users\recep\Desktop\kadran-mobil\build\app\outputs\flutter-apk\app-debug.apk` (deneme sürümü, yaklaşık 200 MB).

1. Dosyayı telefona at. Seçenekler:
   - **USB kablo:** telefonu bağla, bildirimden "Dosya aktarımı"nı seç, dosyayı telefonun İndirilenler klasörüne kopyala.
   - **Google Drive:** dosyayı Drive'a yükle, telefonda Drive'dan indir.
2. Telefonda **Dosyalar** uygulamasında (ya da Drive'da) apk'ya dokun.
3. "Bilinmeyen uygulamalar" uyarısında **Ayarlar** > bu kaynaktan yüklemeye **izin ver** > geri dön > **Yükle**.
4. Play Protect uyarırsa **Yine de yükle** (imzasız deneme sürümü olduğu için uyarır).
5. Ana ekranda **Kadran** simgesi çıkar.

**Güncelleme:** yeni sürüm verdiğimde aynı adımlarla kur; eskinin üstüne yüklenir, hesabın açık kalır. Sorun çıkarsa önce eskisini kaldır (simgeye basılı tut > Kaldır).

### 0.3 Hesaplar

Sitedeki test hesaplarını kullan (site planı 0.5): Araç sahibi A, Araç sahibi B, Usta, Yönetici. Uygulamada yeni hesap da açabilirsin. Yönetim paneli uygulamada yok; yönetici işlerini sitede yap.

### 0.4 Uygulamada olmayanlar (bilerek)

- **Uygulama kapalıyken bildirim** yok (Firebase gerekir). Uygulama açıkken yeni mesaj ve talepler birkaç saniyede kendiliğinden görünür.
- **Konumla arama** yok; il ve ilçe seçilir.
- Usta başvurusu, belge yükleme, çalışma saatlerini düzenleme, şifre değiştirme ve hesap silme **sitede** yapılır. Uygulama bunları telefonun tarayıcısında açar (tarayıcıda ayrıca giriş yapman gerekebilir).

---

## Sonuçları nasıl bildireceksin

```
MC3 ✗ · Engelleyici · "Fren yaparken"e dokununca uygulama kapandı. Telefon: Samsung A54, Android 14.
MF2 ✗ · Can sıkıcı · Galeriden 3 fotoğraf seçince yalnız 1'i eklendi.
MJ2 ✗ · Kozmetik · En büyük yazı boyutunda "Randevu al" düğmesi taşıyor. (ekran görüntüsü)
```

**Engelleyici:** iş yapılamıyor ya da uygulama kapanıyor. **Can sıkıcı:** yapılıyor ama zor ya da yanlış. **Kozmetik:** görünüş. Telefon modeli ve Android sürümünü bir kez yazman yeter. Ekran görüntüsü: güç + ses kısma tuşu.

---

## Kısa tur (önce bunlar, yaklaşık 45 dakika)

MA1, MA3, MA5 · MB1, MB3, MB4 · MC1, MC4 · MD1, MD3 · ME2 · MF1, MF3 · MG1, MG2 · MH1, MH3, MH4, MH7 · MK1

---

## MA. Açılış ve giriş

- [ ] **MA1 ★ · İlk açılış.** Uygulamayı aç. → Lacivert açılış, sonra girişsiz "Boş saatler" ekranı; sağ üstte "Giriş yap".
- [ ] **MA2 · Girişsiz bakma.** İl/ilçe, iş, marka seç; bir ustaya dokun. → Usta sayfası açılır; randevu ya da mesaj için giriş istenir.
- [ ] **MA3 ★ · Giriş.** "Giriş yap" > Araç sahibi A'nın bilgileri. → Alt çubukta Usta bul · Randevular · Mesajlar · Araçlarım · Hesabım.
- [ ] **MA4 · Yanlış şifre.** → Sitedeki hata yazısının aynısı.
- [ ] **MA5 ★ · Oturum hatırlanır.** Uygulamayı tamamen kapat (son uygulamalardan kaydır), yeniden aç. → Yine girişli.
- [ ] **MA6 · Kayıt.** Çıkış yap > Giriş yap > "Araç sahibi olarak kayıt ol" > bilgiler > "Hesap oluştur" > kod (test modunda ekranda yazar). → Hesap açılır.
- [ ] **MA7 · Usta girişi.** Usta hesabıyla gir. → Alt çubukta Özet · Randevular · Mesajlar · Takvim.
- [ ] **MA8 · Çıkış.** Hesabım (ustada Özet) > Çıkış yap. → Girişsiz ekrana döner.

## MB. Usta bulma ve randevu (araç sahibi)

- [ ] **MB1 ★ · Süzgeçler.** Nerede: İstanbul / Ümraniye; Ne için: Klima gazı dolumu. → Liste ve gün sekmeleri değişir; boş usta yoksa ne yapacağın yazar.
- [ ] **MB2 · Usta sayfası.** → Puan, yorumlar, çalışma saatleri, boş saatler; "Yol tarifi" Google Haritalar'ı açar; "Ustaya mesaj yaz".
- [ ] **MB3 ★ · Randevu al.** Bir saat seç > "Bu saatle randevu al" > araç ve iş > özet > not > gönder > kod. → "Randevu talebin gönderildi"; Randevular sekmesinde "Onay bekliyor".
- [ ] **MB4 ★ · Siteyle aynı.** Aynı randevuyu sitede usta hesabıyla gör ve onayla. → Uygulamada birkaç saniye içinde (ya da aşağı çekip yenileyince) "Onaylandı".
- [ ] **MB5 · Dolu gün.** Boş saati olmayan bir güne dokun > "Bu gün boşalınca haber ver". → "Tamam, bu gün boşalınca haber vereceğiz"; Randevular'ın başında beklenen gün; "Vazgeç" kaldırır.
- [ ] **MB6 · Aracı olmayan.** Aracı olmayan hesapla randevu almayı dene. → Araç ekleme ekranına yönlendirir; ekleyince kaldığın yere döner.

## MC. Soru ağacı: "Aracında ne oluyor?"

- [ ] **MC1 ★ · Açılış.** Usta bul > "Ne olduğunu bilmiyor musun? Birkaç soruyla bulalım". → Kendi sözlerinle yazma kutusu ve "Aracında ne oluyor?" seçenekleri.
- [ ] **MC2 · Kendi sözleri.** "Sabah akü bitti, marş basmıyor" yaz > "Çalışmıyor ya da zor çalışıyor". → Üstte "Yazdığına göre şunlar da olabilir: Akü…".
- [ ] **MC3 · Sonuç.** "Hiç ses yok, ışıklar sönük". → Aciliyet kutusu, olası iş ("Akü bitiyor ya da akü değişimi"), açıklama, başka olasılıklar.
- [ ] **MC4 ★ · Ustalara geçiş.** "Bu işe bakan ustaların boş saatleri". → Usta listesi o işle süzülmüş açılır.
- [ ] **MC5 · Değiştir ve baştan.** Bir cevabın yanında "Değiştir"; sonra "Baştan başla". → Doğru soruya döner.
- [ ] **MC6 · Teklife geçiş.** Kaporta… > Göçük ya da ezik > "Fotoğrafla teklif iste". → Girişsizsen giriş ister; sonra teklif formu iş seçili ve açıklama cevaplarla dolu açılır.
- [ ] **MC7 · Sitede görünüyor.** Yönetici sitede > Yönetim > Yönlendirme verisi. → Uygulamadan yaptığın kullanım "Uygulama" kaynağıyla listede.

## MD. Randevularım ve iş takibi (araç sahibi)

Önce bugüne bir randevu al ve usta onaylasın.

- [ ] **MD1 ★ · Randevu ayrıntısı.** Randevular > randevuya dokun. → Tarih, usta, araç, durum; "Ustaya yaz"; uygun durumda "Randevuyu iptal et".
- [ ] **MD2 · Aracın durumu.** Usta (sitede ya da uygulamada) durumu "Onarımda" yapsın. → Listede "Aracın: Onarımda"; ayrıntıda durum adımları ve ustanın notu.
- [ ] **MD3 ★ · Ek iş onayı.** Usta fotoğraflı ek iş önersin. → Listede "Ek iş onayın bekleniyor"; ayrıntıda açıklama, fiyat, fotoğraf (dokununca tam ekran, iki parmakla büyür); "Onayla" ya da "İstemiyorum".
- [ ] **MD4 · Servis kaydı ve puan.** Usta servis kaydını yazsın. → Ayrıntıda servis kaydı; "Ustayı puanla" açılır, yıldız + yorum gönderilir.
- [ ] **MD5 · İptal.** Yaklaşan bir randevuyu iptal et > Evet. → "Randevun iptal edildi".
- [ ] **MD6 · Hatırlatmalar.** Aracına 5 gün sonraya muayene koy (ME2). → Randevular'ın başında mor muayene kartı.

## ME. Araçlarım

- [ ] **ME1 · Araç ekle.** Araç ekle > marka (arama kutusunda "ren"), model, yıl, yakıt, plaka `34abc123`. → Listede `34 ABC 123`.
- [ ] **ME2 ★ · Hatırlatıcılar.** Araca dokun > muayene: Gün / Ay / Yıl'a dokunup tarih seç > "Hatırlatıcıları kaydet". → "Hatırlatıcılar kaydedildi". "Temizle" tarihi siler.
- [ ] **ME3 · Ay sonu.** 31 Ocak seçip ayı Şubat yap. → Gün 28'e (ya da 29'a) iner.
- [ ] **ME4 · Servis geçmişi.** Servis kaydı yazılmış aracın sayfası. → Ustanın kaydı, tutar ve km.
- [ ] **ME5 · Düzenle ve sil.** "Aracı düzenle" > değiştir ya da sil.

## MF. Fotoğrafla teklif

- [ ] **MF1 ★ · Talep aç (araç sahibi).** Randevular > "Fiyat teklifi iste" > "Yeni teklif iste" (hiç talebin yoksa "Teklif iste"; ya da Hesabım > Tekliflerim). Araç, iş, açıklama, il/ilçe.
- [ ] **MF2 ★ · Fotoğraf.** "Fotoğraf çek ya da seç" > **Fotoğraf çek** (ilk seferde kamera izni ister) > çek. Sonra "Bir fotoğraf daha ekle" > **Galeriden seç** > 2 fotoğraf. → 3 küçük önizleme; 3'e gelince ekleme düğmesi kaybolur; köşedeki ✕ kaldırır. "Teklif iste" → talep sayfası, fotoğraflar görünür.
- [ ] **MF3 ★ · Usta fiyat verir.** Usta hesabıyla (o işi yapan, aynı bölgede) > Özet > Teklif talepleri > talep > fotoğraflar > en az / en çok > "Teklif ver". → "Teklifin müşteriye gitti"; düğme "Teklifimi güncelle".
- [ ] **MF4 · Karşılaştır.** Araç sahibi talep sayfası. → Teklifler en ucuzdan; "Bu ustadan randevu al" usta sayfasını iş seçili açar; "Ustaya sor".
- [ ] **MF5 · Kapat.** "Talebi kapat". → Usta artık fiyat veremez.

## MG. Mesajlar

- [ ] **MG1 ★ · Yaz.** Usta sayfası > "Ustaya mesaj yaz" > hazır mesaj ya da kendi yazın > Gönder. → Yazışmada görünür.
- [ ] **MG2 ★ · Fotoğraf gönder.** Yazma kutusunun solundaki kamera > çek ya da seç. → Fotoğraf yazışmaya düşer; dokununca büyür.
- [ ] **MG3 · Canlı.** Usta sitede yanıtlasın. → Uygulamada ~4 saniyede görünür; Mesajlar sekmesinde rozet.
- [ ] **MG4 · Randevu satırları.** Randevulu yazışmada üstte randevu kartı ve "Randevu onaylandı" gibi satırlar.

## MH. Usta

- [ ] **MH1 ★ · Özet.** → Onay bekleyen talep sayısı, bugünkü randevular, Teklif talepleri, "Müşterilerine bağlantını ver", İşyerim.
- [ ] **MH2 · Talep onayla / reddet.** Randevular > Onay bekleyen > Onayla; başka birinde Reddet > neden. → Araç sahibinde durum değişir.
- [ ] **MH3 ★ · İş takibi.** Onaylanan > "İş takibi: durum, ek iş, servis" > "Parça bekleniyor" seç > not > "Durumu güncelle". → "Aracın durumu güncellendi"; araç sahibinde görünür.
- [ ] **MH4 ★ · Fotoğraflı ek iş.** Aynı ekranda "Ne gerekiyor?", fiyat, "Fotoğraf çek ya da seç" > gönder. → Araç sahibinde fotoğrafla birlikte onay bekler.
- [ ] **MH5 · Servis kaydı.** Randevu günü: yapılanlar, parçalar, tutar "2.350", km "84.500" > "İşi bitir ve servis kaydını yaz". → Randevu Geçmiş'e geçer; "Servis kaydı" bağlantısı.
- [ ] **MH6 · Elden randevu ve kapalı saat.** Randevular > "Elden randevu ekle ya da saat kapat". → Onaylanan'da "Elden" / "Kapalı saat"; sitede o saat dolu.
- [ ] **MH7 ★ · Bağlantı paylaş.** Özet > "WhatsApp'tan paylaş". → WhatsApp açılır, mesajda bağlantı hazır. "Kopyala" → "Bağlantı kopyalandı". "QR afiş" → tarayıcıda afiş sayfası (tarayıcıda usta girişi gerekebilir).
- [ ] **MH8 · Takvim.** Takvim sekmesi. → Çalışma saatleri, süreler, izinler; "Takvimi sitede düzenle" tarayıcıyı açar.
- [ ] **MH9 · Müşteriyi ara.** Telefonla kayıtlı müşterinin kartında "Ara". → Telefon uygulaması numarayla açılır.

## MI. Siteye açılan bağlantılar

- [ ] **MI1 ·** Hesabım > Şifremi değiştir / Kullanım Koşulları / KVKK / Hesabımı sil. → Her biri telefonun tarayıcısında doğru sayfayı açar.

## MJ. Görünüş ve erişilebilirlik

- [ ] **MJ1 · Küçük ekran.** Mümkünse küçük bir telefonda. → Yazılar kesilmiyor, yana kaydırma yok.
- [ ] **MJ2 · Büyük yazı.** Telefon Ayarlar > Ekran > Yazı tipi boyutu en büyük. → Ekranlar kullanılabilir kalıyor; düğme yazıları taşmıyor. (Bitince eski boyuta al.)
- [ ] **MJ3 · Geri tuşu.** Android geri tuşu / hareketi her ekranda bir önceki ekrana döner; ana ekranda uygulamadan çıkar.
- [ ] **MJ4 · Ekran okuyucu (isteğe bağlı).** Ayarlar > Erişilebilirlik > TalkBack açık. → Alt çubuk sekmeleri ve düğmeler adlarıyla okunuyor, çift dokunmayla çalışıyor.

## MK. Bağlantı ve hata durumları

- [ ] **MK1 ★ · İnternet kesilir.** Bir ekrandayken Wi-Fi'yi kapat, aşağı çekip yenile. → "Sayfa açılamadı… İnternet bağlantını kontrol et" ve "Yeniden dene". Wi-Fi'yi aç > Yeniden dene → ekran gelir.
- [ ] **MK2 · Site kapalı.** Bilgisayardaki siteyi durdur (`Ctrl+C`), uygulamada bir işlem yap. → Aynı anlaşılır hata; uygulama kapanmaz.
- [ ] **MK3 · Oturum düşer.** Sitede aynı hesabı sil ya da yönetici askıya alsın. → Uygulama bir sonraki işlemde girişsiz ekrana döner.
