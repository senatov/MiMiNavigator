# FavoritesKit

Переиспользуемый Swift Package для навигации по Favorites в macOS.

## Возможности

- **FavoritesTreeView** — основной popup для отображения дерева фаворитов
- **FavoritesScanner** — сканер для Favorites, iCloud, OneDrive и volumes
- **FavoritesBookmarkStore** — управление security-scoped bookmarks (sandbox-friendly)
- **FavoriteItem** — модель для элементов фаворитов

## Установка

### Через Xcode (Local Package)

1. File → Add Package Dependencies...
2. Выбрать "Add Local..." 
3. Указать папку `Packages/FavoritesKit` внутри проекта

### Через Package.swift

```swift
dependencies: [
    .package(path: "../Packages/FavoritesKit"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["FavoritesKit"]
    ),
]
```

## Использование

### 1. Импорт

```swift
import FavoritesKit
```

### 2. Реализация делегата навигации

```swift
@MainActor
class MyNavigationDelegate: FavoritesNavigationDelegate {
    var focusedPanel: FavPanelSide = .left
    
    func navigateToPath(_ path: String, panel: FavPanelSide) async {
        // Ваша логика навигации
    }
    
    func navigateBack(panel: FavPanelSide) { /* ... */ }
    func navigateForward(panel: FavPanelSide) { /* ... */ }
    func navigateUp(panel: FavPanelSide) { /* ... */ }
    func canGoBack(panel: FavPanelSide) -> Bool { false }
    func canGoForward(panel: FavPanelSide) -> Bool { false }
    func currentPath(for panel: FavPanelSide) -> String { "/" }
    func setFocusedPanel(_ panel: FavPanelSide) { focusedPanel = panel }
}
```

### 3. Сканирование и отображение

```swift
@State private var favorites: [FavoriteItem] = []
@State private var showPopup = false

let scanner = FavoritesScanner()
let delegate = MyNavigationDelegate()

// Сканирование
Task {
    favorites = await scanner.scanFavoritesAndVolumes()
}

// View
FavoritesTreeView(
    items: $favorites,
    isPresented: $showPopup,
    panelSide: .left,
    navigationDelegate: delegate
)
```

## Архитектура

```
FavoritesKit/
├── FavoritesProtocols.swift    # Протоколы для интеграции
├── FavoriteItem.swift          # Модель данных
├── FavoritesBookmarkStore.swift # Управление bookmarks
├── FavoritesScanner.swift      # Сканер директорий
├── FavoritesTreeView.swift     # Главный popup
└── FavoritesRowView.swift      # Строка в дереве
```

## Динамическая библиотека

Пакет компилируется как `.dylib` (type: .dynamic в Package.swift).
Результат: `libFavoritesKit.dylib`

## Требования

- macOS 15.0+
- Swift 6.0+
- Xcode 16.0+
