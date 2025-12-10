# Periphery Troubleshooting Guide

## Проблема: DecodingError с shellScript

### Описание ошибки
```
error: (DecodingError) typeMismatch(Swift.String, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "objects", intValue: nil), _DictionaryCodingKey(stringValue: "977B59492EDF6F9700F7F80F", intValue: nil), CodingKeys(stringValue: "shellScript", intValue: nil)], debugDescription: "Expected to decode String but found an array instead.", underlyingError: nil))
```

Эта ошибка возникает когда в проекте Xcode есть Build Phase Script, который использует массив строк для `shellScript` вместо одной строки. Periphery ожидает строку и не может декодировать массив.

## Решения

### Решение 1: Обновить Periphery (Рекомендуется)

Новые версии Periphery исправили эту проблему:

```bash
# Обновить через Homebrew
brew upgrade peripheryapp/periphery/periphery

# Проверить версию (должна быть >= 2.19.0)
periphery version

# Запустить снова
periphery scan --config .periphery.yml
```

### Решение 2: Использовать skip_build

Я уже обновил `.periphery.yml` с этими настройками:

```yaml
clean_build: false
skip_build: true    # Пропускает build фазу
```

Использование:
```bash
# Сначала сделайте clean build проекта в Xcode
# ⌘⇧K (Clean Build Folder) + ⌘B (Build)

# Затем запустите Periphery
periphery scan --config .periphery.yml
```

**Плюсы**: Быстрее работает при повторных запусках  
**Минусы**: Нужно предварительно собрать проект

### Решение 3: Использовать индексный анализ

Я создал альтернативную конфигурацию `.periphery-index.yml`:

```bash
# Сначала соберите проект с индексацией
xcodebuild -scheme MiMiNavigator \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  build

# Запустите Periphery с индексной конфигурацией
periphery scan --config .periphery-index.yml
```

### Решение 4: Исправить проект Xcode (Ручное)

Если хотите исправить проблему в самом проекте:

1. Откройте проект в Xcode
2. Выберите target MiMiNavigator
3. Перейдите в Build Phases
4. Найдите Run Script фазы (обычно SwiftLint или SwiftFormat)
5. Если скрипт многострочный, объедините его в одну строку

Или отредактируйте `project.pbxproj` вручную:

```bash
# Найдите проблемный скрипт (ID: 977B59492EDF6F9700F7F80F)
grep -A 10 "977B59492EDF6F9700F7F80F" MiMiNavigator.xcodeproj/project.pbxproj

# Измените формат с массива на строку:
# БЫЛО:
# shellScript = (
#   "line1",
#   "line2",
# );

# ДОЛЖНО БЫТЬ:
# shellScript = "line1\nline2\n";
```

⚠️ **Внимание**: Редактирование `project.pbxproj` вручную может повредить проект. Делайте backup!

## Рекомендуемый порядок действий

1. **Попробуйте Решение 2** (skip_build) - самое простое:
   ```bash
   # В Xcode: ⌘⇧K + ⌘B
   periphery scan --config .periphery.yml
   ```

2. Если не помогло, **обновите Periphery** (Решение 1):
   ```bash
   brew upgrade peripheryapp/periphery/periphery
   periphery scan --config .periphery.yml
   ```

3. Если проблема осталась, **используйте индексный анализ** (Решение 3)

## Дополнительная информация

### Проверка версии Periphery
```bash
periphery version
```

### Полная переустановка Periphery
```bash
brew uninstall periphery
brew install peripheryapp/periphery/periphery
```

### Альтернативные конфигурации

У вас есть 2 конфигурации:
- `.periphery.yml` - основная (с skip_build: true)
- `.periphery-index.yml` - индексная (для особо сложных случаев)

### Известные проблемы

- Эта ошибка часто возникает со скриптами SwiftLint/SwiftFormat
- Проблема была исправлена в Periphery 2.19.0+
- Workaround с skip_build работает для большинства проектов

## Полезные ссылки

- [Periphery GitHub Issues](https://github.com/peripheryapp/periphery/issues)
- [Known ShellScript Issue](https://github.com/peripheryapp/periphery/issues/500)
- [Periphery Documentation](https://github.com/peripheryapp/periphery)
