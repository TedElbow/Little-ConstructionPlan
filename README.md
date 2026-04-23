# BaseProject

Базовый шаблон iOS-приложения на SwiftUI с веб-интеграцией, аналитикой и заготовкой под игровой режим. Сборка и деплой через Fastlane и GitHub Actions. Используйте этот репозиторий как стартовую точку для своего проекта.

## Возможности

- **Старт приложения:** первый запуск, загрузка, проверка сети, запрос push-уведомлений
- **Режим Game:** экран-заглушка для вашего контента (игры, табы и т.д.)
- **Веб-режим:** отображение контента по URL
- **Инфраструктура:** AppsFlyer, Firebase (Core, Messaging, Remote Config), push-токены, Match (подпись)

## Стек

- **SwiftUI** — UI
- **Firebase** — Core, Messaging, Remote Config
- **AppsFlyer** — аналитика и атрибуция
- **CocoaPods** — зависимости
- **Fastlane** — сборка и загрузка в TestFlight
- **GitHub Actions** — CI

## Требования

- macOS 12+
- Xcode 14+ (рекомендуется 16.x)
- iOS 16.0+ (деплой таргет из Podfile)
- Ruby 3.3+
- Bundler, CocoaPods 1.16+

## Установка

```bash
git clone <https://github.com/GolubWork/IOS-Base-App.git>
cd <путь к проекту>
bundle install
bundle exec pod install
```

Открыть **`BaseProject.xcworkspace`** (не `.xcodeproj`; workspace создаётся после `pod install`). Добавить `GoogleService-Info.plist` в корень проекта при использовании Firebase.

Стартовые URL и ключи (сервер, магазин, Firebase, AppsFlyer и feature flags): `Infrastructure/Configuration/StartupDefaultsConfiguration.swift`. Схемы сборки: Debug, Staging, Release (см. `BuildConfiguration`).

## Запуск

В Xcode: схема **BaseProject** → Run.

## Подробно
Архитектура проекта: [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md).

Как расширять проект вашим приложением: [Docs/EXTENDING.md](Docs/EXTENDING.md).

Правила для GPT для работы с проектом: [Docs/GPTRULES.md](Docs/GPTRULES.md).

Решение проблем с BaseProject: [Docs/TROUBLESHOOTING.md](Docs/TROUBLESHOOTING.md).

Решение проблем с CI: [Docs/TROUBLESHOOTING](https://github.com/GolubWork/IOS-Build-CI/blob/main/Docks/TROUBLESHOOTING.md)

