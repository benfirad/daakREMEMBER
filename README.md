# daakREMEMBER

Aklına gelen düşünceyi veya yapacağın işi kaybolmadan yakalayan küçük bir macOS
menü çubuğu uygulaması.

## Özellikler

- Menü çubuğundaki beyin simgesinden hızlı kayıt
- Enter ile tek hareketle ekleme
- Tamamlandı işaretleme ve silme
- macOS masaüstüne eklenebilen küçük ve orta boy gerçek WidgetKit widget'ı
- Türkçe, İngilizce ve İspanyolca arayüz
- Uygulama içindeki ayarlardan anında dil değiştirme
- GitHub sürümlerinden güvenli ve otomatik güncelleme
- Tailscale ağındaki Mac'ler arasında otomatik eşitleme
- DAAK NODE üzerinden Android'de notları görüntüleme ve hızlı kayıt
- Hesap, reklam ve harici bulut servisi olmadan yerel saklama

## İndir

Hazır Apple Silicon uygulamasını
[son sürüm sayfasından](https://github.com/benfirad/daakREMEMBER/releases/latest)
indirebilirsiniz.

1. `daakREMEMBER-macOS.zip` dosyasını açın.
2. `daakREMEMBER.app` uygulamasını **Uygulamalar** klasörüne taşıyın.
3. İlk açılışta macOS engellerse uygulamaya sağ tıklayıp **Aç** seçeneğini kullanın.

Gereksinimler: Apple Silicon Mac ve macOS 14 veya üzeri.

## Masaüstü widget'ı

Uygulamayı bir kez açtıktan sonra masaüstüne sağ tıklayın, **Widget'ları
Düzenle** seçeneğini açın ve **daakREMEMBER** widget'ını ekleyin. Bu, macOS'un
normal widget'ıdır; masaüstünün widget düzenleme modunda taşınabilir ve boyutu
değiştirilebilir. Widget'a tıklamak menü çubuğundaki hızlı kayıt penceresini açar.

Üstteki dişli simgesinden Türkçe, English veya Español seçilebilir. Seçim
uygulamayı yeniden başlatmadan ana paneli ve masaüstü widget'ını günceller.

## Eşitleme

Eşitleme için uygulamayı diğer Mac'lere de kurun ve bütün cihazlarda Tailscale'i
açın. Uygulama çevrimiçi Mac'leri 20 saniyede bir bulur ve `45831/TCP` üzerinden
iki yönlü eşitler.

Eşitleme servisi yalnızca Tailscale'in `100.64.0.0/10` ve
`fd7a:115c:a1e0::/48` adreslerinden gelen bağlantıları kabul eder. Android'deki
[DAAK NODE](https://github.com/benfirad/firat-node) köprüsü aynı özel protokolü
kullanarak notları okuyabilir ve telefondan yeni kayıt ekleyebilir. Bağlantı
yokken kayıtlar Android'de sıraya alınır ve Mac yeniden erişilebilir olduğunda
gönderilir. Kurulum ve güvenlik ayrıntıları için
[Android entegrasyonu](docs/android-daak-node.md) belgesine bakın.

Windows, Linux ve iPhone için henüz yerel istemci bulunmuyor.

Uygulama ile widget verileri, Apple takımına bağlı güvenli ortak uygulama
grubunda tutulur. Eski sürümdeki yerel veriler ilk açılışta otomatik taşınır.

## Güncellemeler

daakREMEMBER, yeni GitHub sürümlerini günde bir kez denetler. Güvenli Sparkle
güncelleme sistemi indirilen paketleri EdDSA imzasıyla doğrular ve uygun olduğunda
güncellemeyi arka planda kurar. Alt kısımdaki **Güncellemeleri denetle** düğmesiyle
elle de kontrol edilebilir.

## Kaynaktan derleme

Menü çubuğu uygulamasının temel sürümü Swift araçlarıyla derlenebilir:

```sh
swift build -c release
```

Widget dahil tam uygulama için Xcode 27 ve
[XcodeGen](https://github.com/yonaskolb/XcodeGen) gerekir:

```sh
xcodegen generate
open AklimaGeldi.xcodeproj
```

Xcode'da kendi takımınızı seçtikten sonra uygulama grubu takım kimliğinizden
otomatik oluşturulur. Uygulama Swift, SwiftUI, AppKit, WidgetKit ve Network
framework'leriyle geliştirilmiştir.

## Katkıda bulun

Proje açık geliştirmeye açıktır. Hata bildirimi, fikir ve pull request'ler
memnuniyetle karşılanır. Başlamadan önce [katkı rehberini](CONTRIBUTING.md)
okuyabilirsiniz.

Özellikle Intel Mac paketi ve Windows/Linux/iPhone istemcileri için
katkılar değerlidir.

## Lisans

Bu proje [Apache License 2.0](LICENSE) ile açık kaynak olarak paylaşılmaktadır.

Projeyi veya türev bir sürümünü dağıtanların [`NOTICE`](NOTICE) dosyasındaki şu
atfı koruması gerekir:

> daakREMEMBER — Fırat ([@benfirad](https://github.com/benfirad))

Atıf; dağıtılan `NOTICE` dosyasında, beraberindeki belgelerde veya uygulamanın
uygun bir “Hakkında/Credits” ekranında yer alabilir.
