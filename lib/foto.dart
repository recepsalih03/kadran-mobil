import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'bilesenler.dart';
import 'tema.dart';

/* Fotoğraf seçme: kamerayla çek ya da galeriden seç. Fotoğraf telefonda küçültülür (en çok 1600 px, JPEG %75;
   genelde 200–500 KB) ve sunucuya { dosya: base64, tur, ad } olarak gider (sitedeki dosya kutusunun aynısı).
   Sunucudaki sınır fotoğraf başına 4 MB. */

const _enBuyuk = 4 * 1024 * 1024;

class SecilenFoto {
  SecilenFoto(this.ad, this.tur, this.bayt);
  final String ad, tur;
  final Uint8List bayt;

  /// Eylem alanı olarak (sunucu dosyaya çevirir).
  Map<String, String> get alan => {'dosya': base64Encode(bayt), 'tur': tur, 'ad': ad};
}

String _tur(String ad) {
  final u = ad.toLowerCase();
  if (u.endsWith('.png')) return 'image/png';
  if (u.endsWith('.webp')) return 'image/webp';
  if (u.endsWith('.heic')) return 'image/heic';
  if (u.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

/// Kamera mı galeri mi diye sorar, seçilen fotoğrafları döner (vazgeçilirse boş). [enCok] 1'den büyükse
/// galeriden birden çok seçilebilir.
Future<List<SecilenFoto>> fotoSec(BuildContext context, {int enCok = 1}) async {
  final kaynak = await showModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Kose.pano))),
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Fotoğraf ekle', style: Yazi.bolum),
        const SizedBox(height: 14),
        AnaDugme(etiket: 'Fotoğraf çek', simge: Icons.photo_camera_outlined, onPressed: () => Navigator.pop(c, ImageSource.camera)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(c, ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(enCok > 1 ? 'Galeriden seç (en çok $enCok)' : 'Galeriden seç'),
        ),
      ]),
    ),
  );
  if (kaynak == null) return const [];
  final secici = ImagePicker();
  final List<XFile> dosyalar;
  try {
    if (kaynak == ImageSource.gallery && enCok > 1) {
      dosyalar = await secici.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 75, limit: enCok);
    } else {
      final d = await secici.pickImage(source: kaynak, maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
      dosyalar = d == null ? const [] : [d];
    }
  } on Exception {
    if (context.mounted) bildir(context, kaynak == ImageSource.camera ? 'Kamera açılamadı. Ayarlardan kamera iznini kontrol et.' : 'Galeri açılamadı.');
    return const [];
  }
  final sonuc = <SecilenFoto>[];
  for (final d in dosyalar.take(enCok)) {
    final bayt = await d.readAsBytes();
    if (bayt.length > _enBuyuk) {
      if (context.mounted) bildir(context, 'Bir fotoğraf çok büyük (en çok 4 MB). Başka bir fotoğraf seç.');
      continue;
    }
    sonuc.add(SecilenFoto(d.name, _tur(d.name), bayt));
  }
  return sonuc;
}

/// Form içinde fotoğraf alanı: küçük önizlemeler (kaldırılabilir) ve "Fotoğraf çek ya da seç" düğmesi.
class FotoAlani extends StatelessWidget {
  const FotoAlani({super.key, required this.fotolar, required this.onDegis, this.enCok = 1, this.hata});
  final List<SecilenFoto> fotolar;
  final ValueChanged<List<SecilenFoto>> onDegis;
  final int enCok;
  final String? hata;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (fotolar.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < fotolar.length; i++)
              Stack(clipBehavior: Clip.none, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Kose.orta),
                  child: Image.memory(fotolar[i].bayt, width: 92, height: 92, fit: BoxFit.cover, semanticLabel: 'Eklenen fotoğraf ${i + 1}'),
                ),
                Positioned(
                  top: -10,
                  right: -10,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Renk.lacivert, minimumSize: const Size(40, 40)),
                    tooltip: 'Fotoğraf ${i + 1}: kaldır',
                    onPressed: () => onDegis([...fotolar]..removeAt(i)),
                    icon: const Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ]),
          ]),
          const SizedBox(height: 10),
        ],
        if (fotolar.length < enCok)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              onPressed: () async {
                final yeni = await fotoSec(context, enCok: enCok - fotolar.length);
                if (yeni.isNotEmpty) onDegis([...fotolar, ...yeni]);
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(fotolar.isEmpty ? 'Fotoğraf çek ya da seç' : 'Bir fotoğraf daha ekle'),
            ),
          ),
        if (hata != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(hata!, style: Yazi.govdeKalin.copyWith(color: Renk.hayir))),
      ]);
}
