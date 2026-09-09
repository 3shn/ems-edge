# epc-tl3576-me

Bring-up. Identified 2026-09-09 from the unit's I/O panel; four LAN ports is
unique to `-ME` in this family.

## Not done, and nothing should pretend otherwise

- **`parameter.txt` does not exist yet.** The A/B partition table has to come
  from the vendor's `update.img` or from the running unit. Writing plausible
  offsets by hand would produce a file that looks authoritative and bricks a
  board, so there is no placeholder here on purpose.
- **No device node in `io.yaml` is filled in.** Every one is `null` pending
  `/proc/device-tree` on the booted unit. The vendor's datasheet and its DTS
  already disagree on port counts, so neither is trusted for names.
- **Which LAN sockets are gigabit is unknown**, and it decides northbound and
  southbound separation.
- **DI/DO are unverified** — the datasheet gives 4 and 4, but they are not on
  the photographed face.

## Closing these

Boot the unit and read `/proc/device-tree/model`, the `serial*` aliases, and the
network interfaces. Record what you observe, with the command, into `io.yaml`
and flip each `evidence:` list to include `on-unit`.
