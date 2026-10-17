# Ottoman Rage: Kuşatma 🏰

Osmanlı temalı **tower defense** oyunu — Godot 4.3, dikey (mobil) düzen, Play Store hedefli.

Vlad Dracul'un orduları Bükreş'ten İstanbul'a yürüyor; Osmanlı kuleleriyle (Yeniçeri, Sipahi, Abdal, İmam, Topçu) hattı savun.

## Çalıştırma

1. [Godot 4.3](https://godotengine.org/download) indir.
2. Godot'u aç → **Import** → bu klasördeki `project.godot`'u seç.
3. **Play (F5)**.

Veya komut satırından:
```
Godot_v4.3-stable_win64.exe --path .
```

## Yapı

| Dosya | İşlev |
|-------|-------|
| `project.godot` | Proje ayarları (720×1280 portrait, mobil renderer) |
| `globals/Defs.gd` | Tüm veri: kuleler, düşmanlar, dalgalar, haritalar |
| `globals/GameData.gd` | Meta ilerleme + kayıt (`user://save.json`) |
| `Main.gd` / `Main.tscn` | Sahne yöneticisi |
| `MainMenu.gd` | Ana menü |
| `GameScreen.gd` | TD seviyesi: simülasyon + çizim + dokunmatik HUD |

**Veri-tabanlı:** yeni kule/düşman/harita eklemek = `Defs.gd`'ye veri eklemek.

## Yol haritası

- [x] Çekirdek döngü: yol, kule yerleştirme, dalgalar, altın, kazan/kaybet
- [ ] 6 sınıf + dallanan yükseltme ağacı
- [ ] Çeşitli düşman/boss + aktif yetenekler
- [ ] Harita/biyom çeşitliliği (orman, çöl, bataklık, step)
- [ ] Meta ilerleme (kalıcı altın, açılabilirler, sihirdar ağacı)
- [ ] Android export (.aab) → Play Store

---
*Ottoman Rage evreninin hafif, mobil tower defense sürümü.*
