# Developer Mode install (no root) — Windows walkthrough

This installs **Custom Home** as a normal app tile using LG's official
**Developer Mode**. No rooting, no factory reset, fully reversible.

**What you get:** a "Custom Home" tile you open yourself (or launch from your PC
over the network).
**What you don't get:** auto-launch on boot or replacing the LG home screen —
webOS Dev Mode can't do that; only root can. See the main README for the rooted
path if you change your mind.

Requirements: a **Windows laptop on the same Wi-Fi/network as the TV**.

---

## Step 1 — LG developer account

1. Go to <https://webostv.developer.lge.com> and **Sign Up** (free).
2. Verify the account by email.

## Step 2 — Enable Developer Mode on the TV

1. On the TV, open **LG Content Store**, search **"Developer Mode"**, install the
   **Developer Mode** app.
2. Open it and **log in** with your LG developer account.
3. Turn **Dev Mode Status** → **ON**. The TV reboots once.
   *(This is a normal reboot, not a reset — your channels, apps and settings stay.)*
4. Reopen the Developer Mode app and note two things on screen:
   - the **IP address**
   - the **passphrase** (6 characters)
5. Leave **Key Server** enabled.

> The Dev Mode session lasts ~50 hours. To keep installed dev apps working, open
> the Developer Mode app occasionally and press **Extend**. If it lapses, dev
> apps just stop launching until you re-enable — still no reset.

## Step 3 — Install the tools on the Windows laptop

1. Install **Node.js LTS**: <https://nodejs.org> (default options).
2. Open **PowerShell** (Start → type "PowerShell").
3. Install the webOS CLI:
   ```powershell
   npm install -g @webosose/ares-cli
   ```
4. Check it works:
   ```powershell
   ares-setup-device --version
   ```

## Step 4 — Pair the laptop with the TV

Run the interactive wizard (easiest on Windows — avoids quoting headaches):

```powershell
ares-setup-device
```

Choose **add**, then enter:

| Prompt | Value |
|---|---|
| Device name | `tv` |
| IP address | *(the IP from the Developer Mode app)* |
| Port | `9922` |
| SSH user | `prisoner` |
| authentication | ssh key |

Then fetch the TV's dev key (it will prompt for the **6-char passphrase**):

```powershell
ares-novacom --device tv --getkey
```

Verify the connection:

```powershell
ares-device-info --device tv
```

You should see model/version info printed back.

## Step 5 — Install the app

Put the provided `com.tstef.customhome_1.0.0_all.ipk` in a known folder (e.g.
`Downloads`), then:

```powershell
cd $HOME\Downloads
ares-install --device tv com.tstef.customhome_1.0.0_all.ipk
```

Confirm it's installed:

```powershell
ares-install --device tv --list
```

## Step 6 — Launch it

Either open the **Custom Home** tile on the TV, or launch it from the laptop:

```powershell
ares-launch --device tv com.tstef.customhome
```

---

## Customising the tiles

The tiles use common webOS 4.x app ids as placeholders. Get your TV's real ids:

```powershell
ares-shell --device tv -r "luna-send -n 1 -f luna://com.webos.applicationManager/listApps '{}'"
```

Edit the `APPS` array in `launcher-app/index.html`, rebuild and reinstall:

```powershell
ares-package launcher-app -o dist
ares-install --device tv dist\com.tstef.customhome_1.0.0_all.ipk
```

> Note: a Dev Mode app runs sandboxed. Launching other apps via the Luna bus
> works on webOS 4.x, but if a tile ever returns a permission error, that's a
> Dev Mode limit — only root lifts it.

---

## Revert — leave no trace (no reset)

1. Remove the app:
   ```powershell
   ares-install --device tv --remove com.tstef.customhome
   ```
2. On the TV, open the **Developer Mode** app and turn **Dev Mode Status** →
   **OFF** (the TV reboots once).
3. *(Optional)* Uninstall the **Developer Mode** app from the LG Content Store.

None of this is a factory reset — the system partition is never touched.
