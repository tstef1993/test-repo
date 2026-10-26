# Custom Home for LG webOS TV

A custom boot launcher for a rooted LG TV. On every boot an autostart script
brings a custom home screen (clock + app tiles) to the foreground instead of
leaving you on LG's stock launcher.

Built for and tested against:

| | |
|---|---|
| Model | OLED65C8PLA (LG C8, 2018) |
| webOS | 4.4.3 (goldilocks) |

It should work on any rooted webOS 3.x–7.x set — you may just need to tweak app
ids in the launcher.

> **Two ways to run this app:**
> - **Rooted (Homebrew Channel)** — the app launches automatically on **every
>   boot** via the autostart hook. This is the full experience; see the rest of
>   this README.
> - **Developer Mode (no root)** — the app installs as a normal **tile you open
>   yourself** (or launch over the network). webOS Dev Mode cannot auto-start an
>   app on boot or replace the home screen — that needs root. Dev Mode is fully
>   reversible with **no factory reset**. See
>   [DEVELOPER-MODE.md](DEVELOPER-MODE.md) for the Windows walkthrough.

---

## What's in here

```
launcher-app/            The custom home screen (a webOS web app)
  appinfo.json           App manifest (id: com.tstef.customhome)
  index.html             The UI: clock, date, remote-navigable app tiles
  icon.png               App icon
autostart/
  webosbrew-autostart.sh  Runs at boot, launches the app on top of the UI
scripts/
  build-ipk.sh           Package launcher-app into an .ipk
  install.sh             Push the .ipk + autostart script to the TV over SSH
```

---

## Prerequisites — root first

This all depends on the TV being rooted with the **Homebrew Channel** installed.
If you haven't done that yet:

1. On a computer, go to **https://rootmy.tv** and follow the guide for webOS 4.x.
2. It installs root + the **Homebrew Channel** app.
3. In the Homebrew Channel app, enable:
   - **SSH** (so these scripts can reach the TV)
   - **Block OTA updates** (so LG can't patch the exploit out from under you)
   - **Run startup scripts** (this is what runs the autostart hook — leave it on)

> ⚠️ Rooting can void warranty and, done wrong, soft-brick the set (recoverable
> via USB firmware). The autostart approach here is deliberately *non-destructive*:
> it launches a new app **on top of** the stock launcher. It never deletes or
> overwrites LG's home app, so if anything misbehaves you still have a fallback —
> just disable "Run startup scripts" and reboot.

---

## Install

### 1. Build the app package

Needs the webOS CLI once:

```bash
npm install -g @webosose/ares-cli
./scripts/build-ipk.sh          # -> dist/com.tstef.customhome_1.0.0_all.ipk
```

### 2. Push it to the TV

Find the TV's IP in **Settings > Network**, then:

```bash
TV_HOST=192.168.1.50 ./scripts/install.sh
```

This installs the app and drops the autostart script at
`/var/lib/webosbrew/init.d/30-custom-home.sh`.

#### Windows (PowerShell, no bash)

Windows 10/11 has a built-in `ssh`/`scp`. Enable **SSH** in the Homebrew Channel
first, then (replace the IP and the `.ipk` filename):

```powershell
$TV = "192.168.1.50"
# 1. copy the app + autostart script up
scp .\dist\com.tstef.customhome_1.0.0_all.ipk root@${TV}:/tmp/app.ipk
ssh root@$TV "mkdir -p /var/lib/webosbrew/init.d"
scp .\autostart\webosbrew-autostart.sh root@${TV}:/var/lib/webosbrew/init.d/30-custom-home.sh
# 2. install the app + make the hook executable
ssh root@$TV "chmod +x /var/lib/webosbrew/init.d/30-custom-home.sh; luna-send -n 1 -w 60000 -f luna://com.webos.appInstallService/dev/install '{\"id\":\"com.tstef.customhome\",\"ipkUrl\":\"/tmp/app.ipk\",\"subscribe\":false}'"
# 3. test the launch without rebooting
ssh root@$TV "sh /var/lib/webosbrew/init.d/30-custom-home.sh"
```

### 3. Flip the switch

In the **Homebrew Channel** app, make sure **"Run startup scripts"** is on, then
reboot the TV. Your custom home should come up after the boot animation.

---

## Customising the launcher

Open `launcher-app/index.html` and edit the `APPS` array. Each entry is a tile:

```js
{ label:"Netflix", emoji:"🎬", id:"netflix" }
```

To get the **exact** app ids installed on your TV, SSH in and run:

```bash
luna-send -n 1 -f luna://com.webos.applicationManager/listApps '{}' \
  | grep -o '"id":"[^"]*"'
```

Rebuild + reinstall after editing (`build-ipk.sh` then `install.sh`).

Remote control works out of the box: arrow keys move the highlight, **OK/Enter**
launches the selected app.

---

## How the autostart works

The Homebrew Channel executes every script in `/var/lib/webosbrew/init.d/` at
boot (as root) when **"Run startup scripts"** is enabled. Our script
`30-custom-home.sh`:

1. Waits (polls `applicationManager`) until the TV UI is actually up.
2. Waits a few extra seconds so it lands on top of the stock boot app.
3. Calls `luna-send .../launch` to open `com.tstef.customhome`.
4. Reads back `getForegroundAppInfo` to confirm it's in front, and retries a
   few times if not.

Everything it does is logged to `/var/log/custom-home-autostart.log`.

### Troubleshooting

```bash
# See what happened at the last boot:
tail -n 50 /var/log/custom-home-autostart.log

# Run the autostart manually (no reboot needed):
sh /var/lib/webosbrew/init.d/30-custom-home.sh

# Confirm the app is installed:
luna-send -n 1 -f luna://com.webos.applicationManager/listApps '{}' \
  | grep com.tstef.customhome
```

- **App flashes then stock home takes over** → increase the `sleep 4` grace in
  the autostart script; the stock launcher was still settling.
- **Nothing happens** → check "Run startup scripts" is on, and that the script
  is `chmod +x` and lives in `/var/lib/webosbrew/init.d/`.
- **A tile says "not installed"** → the `id` is wrong for your set; get the real
  one with the `listApps` command above.

---

## Reverting

Everything here is reversible **without a factory reset**.

**Remove just this launcher** (keep root):
- Disable **"Run startup scripts"** in the Homebrew Channel (stops autostart
  immediately), then reboot — or go further:
- Delete the hook and uninstall the app:
  ```sh
  rm -f /var/lib/webosbrew/init.d/30-custom-home.sh
  luna-send -n 1 -f luna://com.webos.applicationManager/remove '{"id":"com.tstef.customhome"}'
  ```

**Full un-root back to stock behaviour** (still no factory reset):
1. Do the removal above.
2. In the **Homebrew Channel** app, disable **SSH** and **Block OTA updates**.
3. Uninstall the **Homebrew Channel** app itself (long-press its tile → Delete),
   which removes the root autostart entry.

After that the TV behaves exactly as stock. A factory reset is only needed if you
want a guaranteed bit-for-bit factory image — it is not required to revert.
