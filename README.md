# Aklıma Geldi

Aklına gelen düşünceyi veya yapacağın işi kaybolmadan yakalayan küçük bir macOS
menü çubuğu uygulaması.

## Özellikler

- Menü çubuğundaki beyin simgesinden hızlı kayıt
- Enter ile tek hareketle ekleme
- Tamamlandı işaretleme ve silme
- Masaüstünde sürüklenebilir görev paneli
- Tailscale ağındaki Mac'ler arasında otomatik eşitleme
- Hesap, reklam ve harici bulut servisi olmadan yerel saklama

## İndir

Hazır Apple Silicon uygulamasını
[son sürüm sayfasından](https://github.com/benfirad/aklima-geldi/releases/latest)
indirebilirsiniz.

1. `AklimaGeldi-macOS.zip` dosyasını açın.
2. `Aklıma Geldi.app` uygulamasını **Uygulamalar** klasörüne taşıyın.
3. İlk açılışta macOS engellerse uygulamaya sağ tıklayıp **Aç** seçeneğini kullanın.

Gereksinimler: Apple Silicon Mac ve macOS 13 veya üzeri.

## Eşitleme

Eşitleme için uygulamayı diğer Mac'lere de kurun ve bütün cihazlarda Tailscale'i
açın. Uygulama çevrimiçi Mac'leri 20 saniyede bir bulur ve `45831/TCP` üzerinden
iki yönlü eşitler.

Eşitleme servisi yalnızca Tailscale'in `100.64.0.0/10` ve
`fd7a:115c:a1e0::/48` adreslerinden gelen bağlantıları kabul eder. Mevcut sürüm
Windows, Linux, iPhone veya Android istemcileriyle eşitleme yapmaz.

Veriler Mac üzerinde şu konumda tutulur:

```text
~/Library/Application Support/AklimaGeldi/items.json
```

## Kaynaktan derleme

Tam Xcode gerekmeden Apple'ın Swift araçlarıyla derlenebilir:

```sh
swift build -c release
```

Uygulama Swift, SwiftUI, AppKit ve Network framework'leriyle geliştirilmiştir.

## Katkıda bulun

Proje açık geliştirmeye açıktır. Hata bildirimi, fikir ve pull request'ler
memnuniyetle karşılanır. Başlamadan önce [katkı rehberini](CONTRIBUTING.md)
okuyabilirsiniz.

Özellikle gerçek WidgetKit desteği, Intel Mac paketi ve Windows/Linux/mobil
istemciler için katkılar değerlidir.

## Lisans

Bu proje [Apache License 2.0](LICENSE) ile açık kaynak olarak paylaşılmaktadır.

Projeyi veya türev bir sürümünü dağıtanların [`NOTICE`](NOTICE) dosyasındaki şu
atfı koruması gerekir:

> Aklıma Geldi — Fırat ([@benfirad](https://github.com/benfirad))

Atıf; dağıtılan `NOTICE` dosyasında, beraberindeki belgelerde veya uygulamanın
uygun bir “Hakkında/Credits” ekranında yer alabilir.
