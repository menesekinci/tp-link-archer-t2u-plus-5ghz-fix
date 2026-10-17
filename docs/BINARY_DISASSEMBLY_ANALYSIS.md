# `rtwlanu.sys` (`v1030.52.1216.2025`) Binary Disassembly & Root-Cause Analysis

## 1. Overview of the Hardware & Driver

- **Adapter:** TP-Link Archer T2U Plus (`USB\VID_2357&PID_0120`)
- **Chipset:** Realtek `RTL8811AU` (1x1 Single-Stream Dual-Band USB 2.0 MAC/BB/RF)
- **Driver Binary:** `C:\Windows\System32\drivers\rtwlanu.sys` (`1030.52.1216.2025`, PE64)

---

## 2. Exact Symptom Under 16-Stream Load (`speedtest.net`)

While 1–3 parallel TCP streams can sustain `160+ Mbps` for 35–60 seconds in `802.11ac` (`VHT40`) mode, opening **16 simultaneous TCP streams** (as `speedtest.net` does in web browsers) triggers an **outbound TX lockup over the air at ~4 seconds (`~83.5 MB` transferred)**:

- **Inbound RX (`ReceivedUnicastPackets` / `ReceivedMulticastPackets`):** Continues incrementing from router beacons and multicast frames; Windows still shows `State: connected` and `Signal: 100%`.
- **Outbound TX (`SentUnicastPackets`):** Increments in NDIS, but frames never leave the RF transmitter (`0%` replies to unicast `ping 192.168.1.1`, `ping fe80::1`, or ARP requests).
- **MAC Re-association Proof:** Running `netsh wlan disconnect` followed by `netsh wlan connect` (which does **not** reset the USB device or reload `rtwlanu.sys`) immediately clears the stuck MAC/PHY TX state machine in 2 seconds.

---

## 3. Disassembly Findings in `rtwlanu.sys` (`1030.52.1216.2025`)

### A. `0x2351EC` — `802.11ac` (`VHT`) vs `802.11n` (`HT`) Hardware DMA & MAC Path
At file offset `0x2351EC`, `rtwlanu.sys` branches on the current wireless mode (`[rcx + 0x61D910]`):

```asm
cmp dword ptr [rcx + 0x61D910], 0x10 ; 0x10 = WIRELESS_MODE_AC_5G
```

1. **When `WirelessMode >= 0x10` (`802.11ac` VHT on 5 GHz):**
   - The driver dynamically rewrites `REG_RXDMA_AGG_PG_TH` (`0x0280`) every 2 seconds (`0x23523C`, `0x2353AB`), alternating between `AcUsbDmaSize`/`AcUsbDmaTime` (`0x04`/`0x05`) and `AcUsbDmaSize2`/`AcUsbDmaTime2` (`0x10`/`0x04`) based on traffic thresholds.
   - It enables VHT A-MSDU inside A-MPDU (`RxAmsduInAmpdu = 1`), VHT LDPC (`LdpcCap = 34`), VHT STBC (`StbcCap = 17`), and VHT Hardware RTS (`HWRTSEnable = 1`).
   - Under a 16-stream TCP burst (thousands of outbound TCP ACK frames colliding with inbound VHT A-MPDU bursts over the half-duplex USB 2.0 bus), the VHT TX FIFO/NAV state machine deadlocks at ~4 seconds.
2. **When `WirelessMode < 0x10` (`802.11n` HT40 on 5 GHz, `WIRELESS_MODE_N_5G = 0x08`):**
   - The driver writes a static `0x0000` to `REG_RXDMA_AGG_PG_TH` (`0x0280` at `0x2351FF`) and uses the standard HT40 MAC/PHY pipeline (`150 Mbps` PHY rate on 5 GHz).
   - **Result:** Even under continuous 16-stream parallel TCP hammering (`859.32 MB` over 60s + 4 consecutive Ookla Speedtests), **zero TX lockups occur**.

### B. `0x00ECC0..0x00FB20` — Undocumented Registry Parameter Table
Disassembling the registry initialization table revealed undocumented keys read directly by `rtwlanu.sys`:

| Registry Key | Struct Offset | Default | Purpose |
| :--- | :---: | :---: | :--- |
| `BW40MHzFor5G` | `0x16B2` | `0` | Forces 40 MHz bandwidth cap on 5 GHz when `BWSetting = 1`. |
| `TxDutyEnable` | `0x121C` (`-> 0x69389E`) | `1` | Enables thermal TX duty-cycle throttling on RTL8811AU (`RTL8811AU_COMMON.reg`). |
| `DynamicTxDutySW` | `0x1794` | `0` | At `0x1C13D3` (`mov byte ptr [rbx + 0x69389E], 1`), dynamically re-enables `TxDutyEnable` at runtime under heavy throughput unless disabled. |
| `HangDetection` | `0x1738` (`-> HalData+0x1264`) | `1` | Controls `RtCheckForHangWorkItemCallback8821A` (`0x2407D0`), which flushes stuck 8821A/8811A TX queues (`[rbp + 0x737F8]`) and resets MAC register `0x05` (`0xBF9FA`). Must remain `1`. |
| `SendPacketByTimer` | `0x121D` | `1` | Enables timer-paced USB 2.0 TX packet aggregation (`UsbTxAggDescNum = 6` at `0x176489`). Must remain `1`. |
| `TcpReorder` | `0x121F` | `1` | Coalesces outbound TCP ACKs (`TcpReorderEnable.reg`). Must remain `1`. |
