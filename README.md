# Hide & Hunt

Flutter + Flame hide-and-seek for Android. Five maps, 48 randomized hiding objects,
one hunter, three rebels, solo bots, and local multiplayer over Wi-Fi / hotspot.

## Play locally on 2–4 phones

1. Install the same APK on every phone.
2. Connect all phones to the same Wi-Fi network. Alternatively, enable a phone's
   hotspot in Android Settings and connect the other phones to it. Internet is
   not required. The hotspot phone can also host the game.
3. Open **Local play**, choose the host map, and tap **Host**.
4. On the other phones, open **Local play**, enter a host IPv4 address and the
   six-digit room code displayed by the host, then tap **Join room**.
5. The host starts once at least one friend joins. The host is the hunter; guests
   take rebel slots. Bots fill empty slots, up to four players total.

Keep the host app in the foreground. Host pause freezes the whole match; a guest's
pause menu only stops their own movement. A disconnected guest becomes a bot.
The host can start another round after the result screen. Leaving closes the
host's room or removes the guest. Rejoining an active match and host migration
are not supported; create a new room after a host disconnect.

If joining fails, verify the address and code. Guest Wi-Fi / client isolation and
VPN routing can block peer connections; try a phone hotspot. Multiple host
addresses may be listed: use the one associated with Wi-Fi or hotspot.

This version uses manual address entry, not automatic discovery. Bluetooth,
Wi-Fi Direct, automatic hotspot creation, online matchmaking, and audio are not
implemented. The local multiplayer implementation currently targets Android;
other platform runners and the web build are not validated.

## Rules and controls

The home screen contains three main buttons: **Play Solo**, **Local Play**, and
**How to Play**. Solo map and role selection live in the solo setup screen;
instructions are available from How to Play. The renderer includes shaded props,
stone paths and walls, distinct character outfits, and animated capture rings.

Rebels have 20 seconds to hide, followed by a three-minute hunt. **Hide** enters
an existing nearby, unoccupied object. Move or tap **Leave** to exit. **Vanish**
hides a rebel from the hunter and Sense for three seconds, with a 20-second
cooldown. Vanish does not grant capture immunity. Rebels can see their allies.

The hunter's **Capture** checks a 75-unit radius, with an animated circle and
hit/miss feedback. Walls block capture. **Sense** reports nearby rebels. Three
captures win immediately; two captures win when time expires.

Move with the joystick or WASD / arrows. E: Capture / Hide. Q: Sense / Vanish.

## Build and validate

The Android runner is included. Do not regenerate it: it includes local-network
permissions and Android Wi-Fi routing support. The project requires Dart >=3.11
and currently builds with Flutter 3.47.9. The Android build is configured for the
locally installed NDK 29.0.14206865.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

The debug APK can be shared between test devices. Configure your own release
signing before distribution.

Validation: gameplay and UI tests plus real loopback WebSocket tests cover
unique concurrent seats, room code/capacity rejection, input ownership and
normalization, stale-input stopping, hiding/capture/vanish synchronization,
pause, rematch, disconnect-to-bot takeover, and host loss. Real multi-phone
hotspot/Wi-Fi testing remains necessary; loopback tests do not validate Android
network routing or a router's client isolation.

## Implementation

- `lib/features/local/data/local_session.dart`: room lifecycle and WebSocket
  transport. The host simulates at approximately 30 Hz and sends full snapshots
  at approximately 15 Hz. Clients send bounded movement and action requests;
  the host decides outcomes and ignores client-supplied game state or seat IDs.
- `lib/features/local/data/match_snapshot.dart`: synchronized state, including
  prop occupancy, cooldowns, capture effects, timer, and win state.
- `lib/features/local/presentation/local_lobby.dart`: host/join flow.
- `lib/features/hunt/domain/match.dart`: simulation, shared by solo and host.
- `lib/features/hunt/game/`: rendering and game loop.
- `lib/features/hunt/presentation/`: controls and match UI.

Rooms use plain local WebSockets on TCP port 45873 and a per-room six-digit code.
They are for trusted local networks, not public internet hosting. Guests render
host snapshots without prediction/interpolation, so responsiveness depends on
LAN latency. Android guests temporarily bind app sockets to connected Wi-Fi so
an internet-less hotspot is not bypassed for mobile data, and release that
binding when leaving. See Android's
[network binding API](https://developer.android.com/reference/android/net/ConnectivityManager#bindProcessToNetwork(android.net.Network)).

The current Android target is API 36 with `INTERNET` and `ACCESS_NETWORK_STATE`.
When raising the target to API 37+, add the runtime local-network permission
flow described in Android's
[local network permission documentation](https://developer.android.com/privacy-and-security/local-network-permission).
