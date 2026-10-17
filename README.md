# TP-Link Archer T2U Plus (Realtek RTL8811AU) — Definitive 5 GHz Disconnect & `speedtest.net` Freeze Fix

[🇹🇷 Türkçe Rehber (README.tr.md)](README.tr.md) | [🔬 Binary Disassembly Analysis](docs/BINARY_DISASSEMBLY_ANALYSIS.md)

This repository provides the **verified, root-cause engineered solution** for the **TP-Link Archer T2U Plus (`USB\VID_2357&PID_0120`, Realtek RTL8811AU)** external USB 2.0 Wi-Fi adapter where the 5 GHz connection freezes during **`speedtest.net` (16+ parallel TCP streams)**—causing the speed gauge to stall and outbound traffic to die completely while Windows still reports the Wi-Fi status as "Connected".

---

## 💡 Plain-Language Summary: What Was Broken & How We Fixed It

1. **Why Earlier Fixes Failed (`802.11ac` VHT Deadlock Under 16 Streams):**
   * Normal downloads open 1–3 TCP streams, which can pass in `802.11ac` mode. However, **`speedtest.net` opens 16 simultaneous TCP/WebSocket streams**, generating thousands of outbound TCP ACK packets per second while receiving heavy inbound bursts over a half-duplex USB 2.0 (`480 Mbps`) bus.
   * Reverse-engineering `C:\Windows\System32\drivers\rtwlanu.sys` (`v1030.52.1216.2025`) at offset `0x2351EC` (`cmp dword ptr [rcx + 0x61D910], 0x10`) proved that when operating in **`802.11ac` (`VHT`)** mode (`0x10`), the driver dynamically rewrites `REG_RXDMA_AGG_PG_TH` (`0x0280`) every 2 seconds and uses the VHT A-MSDU/LDPC TX pipeline, which **deadlocks outbound TX over the air after ~4 seconds (`~83.5 MB`) of 16-stream load**.
   * Additionally, the router (`ZTE ZXHN H3601P V9.0`) was broadcasting on congested **Channel 36** (colliding with a neighboring `802.11ax` router at 69% signal strength) with `80 MHz` channel bonding.

2. **How We Permanently Solved It:**
   * **Switched the 5 GHz Radio to `802.11a/n` (`HT40`, `150 Mbps` PHY) on Clean Channel 44:** By configuring the router's 5 GHz radio (`DEV.WIFI.RD2`) to `Standard = a,n`, `BandWidth = 40MHz`, and `Channel = 44`, the adapter stays on the interference-free **5 GHz band** while forcing `rtwlanu.sys` (`0x2351EC`) to use the rock-solid **`802.11n` (`HT40`)** code path (`REG_RXDMA_AGG_PG_TH = 0x0000`).
   * **Hardened Driver Registry Parameters:** Configured `BWSetting=1`, `BW40MHzFor5G=1`, `bFwCtrlLPS=0`, `bLowPowerEnable=0`, `TxDutyEnable=0`, `DynamicTxDutySW=0`, `SendPacketByTimer=1`, `TcpReorder=1`, and `HangDetection=1`.

---

## 📊 Second-by-Second Proof: `802.11ac` vs `5 GHz 802.11a/n` (16 Parallel TCP Streams)

Live measurements on the exact same 5 GHz network (`TurkNet1000Mbps_309BA_5G`, Channel 44, `40 MHz`) under **16 simultaneous TCP streams**:

| Second | `802.11ac` (`Standard = a,n,ac`) | `5 GHz 802.11a/n` (`Standard = a,n`, HT40) |
| :---: | :--- | :--- |
| **1s** | `167.08 Mbps` (`20.08 MB`) — Ping: `OK` | `126.61 Mbps` (`15.17 MB`) — Ping: `OK` |
| **3s** | `161.20 Mbps` (`64.06 MB`) — Ping: `OK` | `120.23 Mbps` (`48.09 MB`) — Ping: `OK` |
| **4s** | `136.54 Mbps` (`83.52 MB`) — **Ping: `TIMEOUT`** | `120.68 Mbps` (`64.63 MB`) — **Ping: `OK`** |
| **5s** | **`14.99 Mbps` (`85.85 MB`) — TX WEDGED** | **`121.59 Mbps` (`81.36 MB`) — Ping: `OK`** |
| **6..30s** | **`0.00 Mbps` (`85.85 MB` frozen) — `100% TIMEOUT`** | **`114.42 – 122.43 Mbps` (`453.66 MB`) — ZERO STALLS** |
| **30..60s** | **Shows Connected, 0% Traffic Passes** | **`115.88 – 118.40 Mbps` (`859.32 MB`) — ZERO STALLS** |

---

## ✅ Verified Official `speedtest.net` (`speedtest.exe`) Benchmarks

Four back-to-back official Ookla Speedtest runs (with 120ms gauge tick logging) after applying the fix:

| Run | Server | Download | Upload | Idle Ping | Packet Loss | Gauge Behavior | Official Result URL |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **1** | Kapteyan Bilişim - Istanbul | **`115.93 Mbps`** | **`96.66 Mbps`** | `4.92 ms` | **`0%`** | Zero freeze (120ms logged) | [speedtest.net/result/c/69c0748e...](https://www.speedtest.net/result/c/69c0748e-6414-4141-aeaa-8b0d025277f2) |
| **2** | Kapteyan Bilişim - Istanbul | **`106.44 Mbps`** | **`94.14 Mbps`** | `5.86 ms` | **`0%`** | Zero freeze (120ms logged) | [speedtest.net/result/c/2ca2adb7...](https://www.speedtest.net/result/c/2ca2adb7-21fb-4f28-9232-eb4fef89c0ff) |
| **3** *(Post-859 MB Stress)* | PremierDC - Istanbul | **`101.91 Mbps`** | **`101.26 Mbps`** | `5.10 ms` | **`0%`** | Zero freeze | [speedtest.net/result/c/3f960f16...](https://www.speedtest.net/result/c/3f960f16-6f29-4310-a5be-37084a234700) |
| **4** *(Default Routing)* | TurkNet - Istanbul | **`102.31 Mbps`** | **`93.19 Mbps`** | `8.66 ms` | **`0%`** | Zero freeze | [speedtest.net/result/c/02b8fc5d...](https://www.speedtest.net/result/c/02b8fc5d-8d72-4ab4-9444-f07abc2d8cdf) |

---

## 🚀 Quick Start

1. **Configure ZTE ZXHN H3601P 5 GHz Radio (`DEV.WIFI.RD2`):**
   Run `scripts\configure-zte-h3601p-5ghz.bat` (sets 5 GHz to **Channel `44`**, **Bandwidth `40MHz`**, **Mode `802.11a/n`**).
2. **Install WHQL Driver & Registry Fix:**
   Right-click `scripts\install-driver-and-registry-fix.bat` and select **Run as administrator**.
3. **Verify Under 16-Stream Load:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\verify-16stream-stability.ps1
   ```
