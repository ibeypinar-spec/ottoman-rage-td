# Sprite'lar — görselleri yükseltme rehberi

Oyun, bu klasörde **doğru isimli** PNG bulursa çizim yerine o görseli kullanır.
Dosya yoksa mevcut (kod-tabanlı) çizime döner. Yani istediğin kadarını ekleyebilirsin.

## Nereye ne koyulur

| Klasör | Dosya adları (birebir) |
|--------|------------------------|
| `sprites/towers/` | `sipahi.png` `yeniceri.png` `deli.png` `abdal.png` `ozan.png` `imam.png` |
| `sprites/enemies/` | `eskiya.png` `asker.png` `strigoi.png` `zirhli.png` `yarasa.png` `hortlak.png` `vukodlak.png` `vlad.png` |
| `sprites/` | `menu_bg.jpg` (menü arka planı — zaten var) |

## Teknik özellikler
- **Format:** PNG, **saydam (transparent) arka plan**.
- **Boyut:** kare, 256×256 (veya 512×512). Oyun otomatik ölçekler.
- **Bakış açısı:** üstten/çeyrek (top-down ~3/4) — tower defense tahtasına uygun, tek figür ortada.
- **Çerçeve yok:** sadece birim/figür; kart/arka plan ekleme (oyun kendi zeminini çiziyor).

## Gemini ile üretim (konsept görselinle aynı tarz)

Her birim için şu kalıbı kullan (tek figür, saydam zemin iste):

> *"Ottoman Rage oyunu için **{BİRİM}**, top-down 3/4 bakış, tek figür ortada, **saydam arka plan**, illüstrasyon tarzı, Osmanlı askeri teması, bordo-altın tonlar, mobil tower-defense birimi, 256x256, çerçevesiz."*

**Kule birimleri:**
- `sipahi` → atlı okçu / nişancı (yay)
- `yeniceri` → tüfekli yeniçeri, kavuğu/börkü ile
- `deli` → iki el kılıçlı cengâver, vahşi görünüm
- `abdal` → asa/nazarlıklı derviş (doğa/büyü)
- `ozan` → sazlı ozan (destek)
- `imam` → asa/kutsal kitaplı bilge büyücü

**Düşman birimleri (Vlad'ın ordusu):**
- `eskiya` → eşkıya/haydut
- `asker` → zırhsız Eflak askeri
- `strigoi` → soluk vampir, hızlı
- `zirhli` → ağır zırhlı muhafız
- `yarasa` → yarasa sürüsü (uçan)
- `hortlak` → yenilenen ölü/revenant
- `vukodlak` → kurt adam (mini-boss)
- `vlad` → Vlad Dracul, karanlık lord (final boss)

## Ekledikten sonra
PNG'leri ilgili klasöre koy, oyunu yeniden başlat (Godot otomatik import eder).
Birim o görselle çıkar; menü/harita ekranları zaten konsept görseli kullanıyor.
