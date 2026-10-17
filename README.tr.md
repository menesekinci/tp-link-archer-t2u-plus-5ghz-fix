# TP-Link Archer T2U Plus (Realtek RTL8811AU) — 5 GHz Kopma ve `speedtest.net` Donma Sorunu Kesin Çözümü

[🇬🇧 English README](README.md) | [🔬 İkili Sürücü (Binary Disassembly) Analizi](docs/BINARY_DISASSEMBLY_ANALYSIS.md)

Bu depo; **TP-Link Archer T2U Plus (`USB\VID_2357&PID_0120`, Realtek RTL8811AU)** harici USB Wi-Fi adaptörünün **5 GHz** ağında yüksek trafik veya **`speedtest.net` (16 eşzamanlı TCP akışı)** altında hız ibresinin takılması, bağlantının "Bağlı" görünmesine rağmen internetin tamamen donması ve kopması sorununun **tersine mühendislik (`rtwlanu.sys`) ve canlı stres testleriyle kanıtlanmış kesin çözümünü** içerir.

---

## 💡 Çok Basit Anlatım: Sorun Neydi ve Nasıl Çözdük?

1. **Neden Kopuyor ve Donuyordu?**
   * Adaptörünüzün içinde iki farklı çalışma vitesi var: **Normal Yüksek Hız (`802.11n` HT40)** ve **Turbo Vites (`802.11ac` VHT)**.
   * Ancak adaptörün bilgisayara bağlandığı USB 2.0 kapısı dar olduğu ve Realtek sürücüsünün (`rtwlanu.sys`) **"Turbo Vites" (`802.11ac`)** kod yolunda bir fabrika hatası (`0x2351EC`) bulunduğu için; `speedtest.net` gibi siteler aynı anda **16 koldan** veri yüklendiğinde adaptörün gönderim (TX) kapısı **4. saniyede tamamen tıkanıyordu**.
   * Kapı tıkandığında Windows hâlâ **"Wi-Fi Bağlı"** gösteriyor ama dışarıya tek bir paket bile çıkamadığı için hız göstergesi donuyor ve internet kesiliyordu.
   * Ayrıca modeminizin 5 GHz yayını, komşu modemlerin yoğun olduğu **Kanal 36** üzerinde `80 MHz` genişliğinde çarpışıyordu.

2. **Nasıl Çözdük?**
   * **Hatalı "Turbo Vitesi" (`802.11ac`) Kapatıp Sağlam Vitese (`5 GHz 802.11a/n HT40`) Sabitledik:** Modeminizin 5 GHz radyosunu (`DEV.WIFI.RD2`), adaptörü kilitleyen `802.11ac` modundan çıkarıp **yine 5 GHz frekansı üzerinde çalışan kaya gibi sağlam `802.11a/n` (`40 MHz`)** moduna aldık.
   * **Modemi Boş Kanala (Kanal 44) Taşıdık:** Komşu `802.11ax` modemle (%69 sinyal) çakışan Kanal 36 yerine, etrafta hiçbir ağın bulunmadığı **Kanal 44**'e sabitledik.
   * **Adaptör Uyku Modunu ve 2.4 GHz'e Kaçışı Kapattık:** Kayıt defterinde `BWSetting=1`, `BW40MHzFor5G=1`, `bFwCtrlLPS=0`, `TxDutyEnable=0` ayarlarını uyguladık ve 2.4 GHz profilinin otomatik geçişini kapattık.

---

## 📊 Saniye Saniye Kanıt: `802.11ac` vs `5 GHz 802.11a/n` (16 Paralel Akış)

Tarayıcıdaki `speedtest.net` davranışını birebir simüle eden **16 eşzamanlı TCP akışı** altında aynı 5 GHz ağı (`TurkNet1000Mbps_309BA_5G`, Kanal 44, `40 MHz`) üzerinde alınan gerçek ölçümler:

| Saniye | `802.11ac` (`Standard = a,n,ac`) | `5 GHz 802.11a/n` (`Standard = a,n`, HT40) |
| :---: | :--- | :--- |
| **1. sn** | `167,08 Mbps` (`20,08 MB`) — Ping: `OK` | `126,61 Mbps` (`15,17 MB`) — Ping: `OK` |
| **3. sn** | `161,20 Mbps` (`64,06 MB`) — Ping: `OK` | `120,23 Mbps` (`48,09 MB`) — Ping: `OK` |
| **4. sn** | `136,54 Mbps` (`83,52 MB`) — **Ping: `TIMEOUT`** | `120,68 Mbps` (`64,63 MB`) — **Ping: `OK`** |
| **5. sn** | **`14,99 Mbps` (`85,85 MB`) — KİLİTLENDİ** | **`121,59 Mbps` (`81,36 MB`) — Ping: `OK`** |
| **6..30. sn** | **`0,00 Mbps` (`85,85 MB` sabit) — `%100 TIMEOUT`** | **`114,42 – 122,43 Mbps` (`453,66 MB`) — KESİNTİSİZ** |
| **30..60. sn** | **Bağlı görünürken internet tamamen kopuk** | **`115,88 – 118,40 Mbps` (`859,32 MB`) — KESİNTİSİZ** |

---

## ✅ Doğrulanmış Resmi `speedtest.net` (`speedtest.exe`) Sonuçları

Çözüm uygulandıktan sonra her `120 ms`'lik hız ibresi (gauge) adımı kaydedilerek arka arkaya çalıştırılan **4 resmi Ookla Speedtest** sonucu:

| Test | Sunucu | İndirme (Download) | Yükleme (Upload) | Ping | Paket Kaybı | İbre (Gauge) Durumu | Doğrulama Bağlantısı |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **1** | Kapteyan Bilişim - İstanbul | **`115,93 Mbps`** | **`96,66 Mbps`** | `4,92 ms` | **`%0`** | Sıfır takılma | [speedtest.net/result/c/69c0748e...](https://www.speedtest.net/result/c/69c0748e-6414-4141-aeaa-8b0d025277f2) |
| **2** | Kapteyan Bilişim - İstanbul | **`106,44 Mbps`** | **`94,14 Mbps`** | `5,86 ms` | **`%0`** | Sıfır takılma | [speedtest.net/result/c/2ca2adb7...](https://www.speedtest.net/result/c/2ca2adb7-21fb-4f28-9232-eb4fef89c0ff) |
| **3** *(859 MB Yük Sonrası)* | PremierDC - İstanbul | **`101,91 Mbps`** | **`101,26 Mbps`** | `5,10 ms` | **`%0`** | Sıfır takılma | [speedtest.net/result/c/3f960f16...](https://www.speedtest.net/result/c/3f960f16-6f29-4310-a5be-37084a234700) |
| **4** *(Varsayılan Yönlendirme)* | TurkNet - İstanbul | **`102,31 Mbps`** | **`93,19 Mbps`** | `8,66 ms` | **`%0`** | Sıfır takılma | [speedtest.net/result/c/02b8fc5d...](https://www.speedtest.net/result/c/02b8fc5d-8d72-4ab4-9444-f07abc2d8cdf) |

---

## 📂 Depo İçeriği ve Kullanım

```text
├── driver/                                    # Resmi Realtek RTL8811AU WHQL Sürücüsü (v1030.52.1216.2025)
├── docs/
│   └── BINARY_DISASSEMBLY_ANALYSIS.md         # rtwlanu.sys (0x2351EC, 0x1C13D3, 0x2407D0) tersine mühendislik analizi
└── scripts/
    ├── configure-zte-h3601p-5ghz.bat          # ZTE H3601P 5 GHz (Kanal 44, 40MHz, 802.11a/n) tek-tık yapılandırıcı
    ├── configure-zte-h3601p-5ghz.ps1          # ZTE H3601P PowerShell yapılandırma betiği
    ├── router_lib.ps1                         # ZTE H3601P RSA+SHA256 HTTP API kütüphanesi
    ├── install-driver-and-registry-fix.bat    # Windows WHQL sürücü + kayıt defteri tek-tık kurulumu
    ├── install-driver-and-registry-fix.ps1    # Windows sürücü ve kayıt defteri betiği
    └── verify-16stream-stability.ps1          # 16 eşzamanlı TCP akışı + modem ping stres testi
```

### Kurulum Adımları
1. **Modem 5 GHz Optimizasyonu (ZTE ZXHN H3601P V9.0):**
   `scripts\configure-zte-h3601p-5ghz.bat` dosyasını çalıştırın (veya modem arayüzünden `Yerel Ağ -> WLAN -> WLAN Genel Yapılandırması -> 5GHz` altından **Kanal = `44`**, **Mod = `Karışık (802.11a/n)`**, **Bant Genişliği = `40MHz`** seçip kaydedin).
2. **Sürücü ve Kayıt Defteri Optimizasyonu:**
   `scripts\install-driver-and-registry-fix.bat` dosyasına sağ tıklayıp **Yönetici olarak çalıştır** deyin.
3. **16-Akışlı Stres Testi ile Doğrulama:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\verify-16stream-stability.ps1
   ```
