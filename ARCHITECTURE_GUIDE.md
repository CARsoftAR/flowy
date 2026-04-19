# Flowy Architecture & Developer Guide (v9)

Flowy is a high-performance, premium music streaming application built with **Flutter**. It is designed as a cross-platform solution with specific optimizations for **Windows Desktop** and **Android TV**, maintaining a unified "Mica/Glassmorphic" visual identity while adapting interaction patterns (Mouse vs. Remote).

---

## 1. Technical Stack
- **Framework:** Flutter (latest stable).
- **State Management:** `Provider` (ChangeNotifier) for general state and specific feature logic.
- **Dependency Injection:** `get_it` (aliased as `sl`) following a Service Locator pattern.
- **Audio Engine:** `just_audio` + `audio_service`. Supports background playback, notification controls, and metadata syncing.
- **LocalStorage:** `sqflite` (database) and `shared_preferences` (settings/cache).
- **Visuals:** Custom "FlowyTheme" using HSL-based dynamic colors, `BackdropFilter` for glass effects, and `flutter_animate` for micro-interactions.

---

## 2. Architecture (DDD-Lite / Clean Architecture)
The project is modular:
- `core/`: DI, Theme, Layout (Universal Shells), Constants.
- `domain/`: Pure entities and Repository interfaces.
- `data/`: Real implementations of Repositories and local/remote data sources.
- `features/`: Home, Player, Library, Search, Stats. Each with its own Providers/Widgets.

---

## 3. Platform & Shell Logic

### The Universal Large Screen Shell (`DesktopShell`)
Flowy uses a unified shell (`lib/core/layout/desktop_shell.dart`) for Windows and TV. It detects the environment via `main.dart`:
- **Windows Mode:** Optimized for Mouse/Keyboard. Uses `MouseRegion` for hover.
- **TV Mode (`isTV: true`):** Switches to a **Focus-Driven Engine**. It uses `Shortcuts` and `Actions` to map D-Pad.

### TV Focus Engine (`Android TV`)
- **Visual Feedback:** Focused elements grow by **1.15x** and emit a **Blue Accent Glow** (`Colors.blueAccent`).
- **Navegación:** `FocusTraversalGroup` ensures the D-pad flow.
- **OK Button:** Native `InkWell` and explicit mapping for `LogicalKeyboardKey.select`.

---

## 4. Design Guidelines
1. **Glassmorphism:** Use `FlowyTheme.glassDecoration()` for containers.
2. **Ambient Background:** The `AmbientBackground` widget reacts to the current song's thumbnail.
3. **TV Clipping:** Always use `clipBehavior: Clip.antiAlias` on cards.
4. **Information Density:** Large screen layouts use 115% scaling for TV visibility.

---

## 5. Development Maintenance
- **Kotlin:** Using version `2.1.0` in `settings.gradle.kts`.
- **Flutter Build:** For TV, use `flutter build apk --release --target-platform android-arm,android-arm64,android-x64 --no-tree-shake-icons`.
- **Flavor:** Set to `AppFlavor.premium` in `app_constants.dart` for full feature access.
