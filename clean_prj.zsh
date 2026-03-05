#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────
#  MiMiNavigator — Project Cleanup & Lint
#  Usage: zsh Scripts/project_cleanup.zsh [--fix]
#  --fix   автоматически удаляет мусор (без флага — только отчёт)
# ─────────────────────────────────────────────────────────────

setopt ERR_EXIT PIPE_FAIL
autoload -U colors && colors

PROJECT_ROOT="${1:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || pwd)}"
FIX_MODE=false
[[ "${@[-1]}" == "--fix" ]] && FIX_MODE=true

ISSUES=0
FIXED=0

# ── helpers ──────────────────────────────────────────────────
warn()  { print -P "%F{yellow}⚠  $1%f"; (( ISSUES++ )) }
info()  { print -P "%F{cyan}   $1%f" }
ok()    { print -P "%F{green}✓  $1%f" }
err()   { print -P "%F{red}✗  $1%f"; (( ISSUES++ )) }
fix()   { print -P "%F{magenta}🔧 $1%f"; (( FIXED++ )) }
header(){ print -P "\n%B%F{white}── $1 ──%f%b" }

maybe_delete() {
  local path="$1" reason="$2"
  if $FIX_MODE; then
    rm -rf "$path" && fix "Удалён: $path ($reason)"
  else
    warn "Мусор: $path  ← $reason"
  fi
}

# ── 1. DS_Store / Thumbs.db ───────────────────────────────────
header "macOS мусор"
while IFS= read -r -d '' f; do
  maybe_delete "$f" ".DS_Store"
done < <(find "$PROJECT_ROOT" -name ".DS_Store" -print0)

while IFS= read -r -d '' f; do
  maybe_delete "$f" "Thumbs.db"
done < <(find "$PROJECT_ROOT" -name "Thumbs.db" -print0 2>/dev/null)

# ── 2. Xcode мусор ───────────────────────────────────────────
header "Xcode артефакты"

# *.orig файлы (git merge конфликты)
while IFS= read -r -d '' f; do
  warn "Merge-остаток: $f"
done < <(find "$PROJECT_ROOT" -name "*.orig" -print0)

# xcuserdata (личные настройки — не должны быть в git)
while IFS= read -r -d '' d; do
  warn "xcuserdata в репо: $d  (добавьте в .gitignore)"
done < <(find "$PROJECT_ROOT" -name "xcuserdata" -type d -print0)

# __.swift — случайные дубли-черновики
while IFS= read -r -d '' f; do
  warn "Черновик: $f"
done < <(find "$PROJECT_ROOT" -name "__*.swift" -print0)

# пустые папки (кроме .git)
while IFS= read -r -d '' d; do
  [[ "$d" == */.git/* ]] && continue
  local cnt=$(find "$d" -mindepth 1 -maxdepth 1 | wc -l)
  (( cnt == 0 )) && warn "Пустая папка: $d"
done < <(find "$PROJECT_ROOT" -not -path "*/.git/*" -type d -print0)

# ── 3. Swift форматирование ───────────────────────────────────
header "Swift lint (trailing whitespace / BOM / CRLF)"

local bad_trail=0 bad_bom=0 bad_crlf=0

while IFS= read -r -d '' f; do
  # trailing whitespace
  if grep -qP '\s+$' "$f" 2>/dev/null; then
    warn "Trailing whitespace: $f"
    (( bad_trail++ ))
    if $FIX_MODE; then
      sed -i '' 's/[[:space:]]*$//' "$f" && fix "Исправлено: $f"
    fi
  fi

  # BOM (UTF-8 BOM = EF BB BF)
  if [[ "$(head -c 3 "$f" | xxd -p)" == "efbbbf" ]]; then
    err "BOM найден: $f"
    (( bad_bom++ ))
    if $FIX_MODE; then
      sed -i '' '1s/^\xEF\xBB\xBF//' "$f" && fix "BOM удалён: $f"
    fi
  fi

  # CRLF
  if file "$f" | grep -q CRLF; then
    warn "CRLF окончания строк: $f"
    (( bad_crlf++ ))
    if $FIX_MODE; then
      sed -i '' 's/\r$//' "$f" && fix "CRLF → LF: $f"
    fi
  fi
done < <(find "$PROJECT_ROOT" -name "*.swift" -not -path "*/.git/*" -print0)

[[ $bad_trail -eq 0 ]] && ok "trailing whitespace: чисто"
[[ $bad_bom   -eq 0 ]] && ok "BOM: чисто"
[[ $bad_crlf  -eq 0 ]] && ok "CRLF: чисто"

# ── 4. Markdown форматирование ────────────────────────────────
header "Markdown"
while IFS= read -r -d '' f; do
  if grep -qP '\s+$' "$f" 2>/dev/null; then
    warn "Trailing whitespace в MD: $f"
    if $FIX_MODE; then
      sed -i '' 's/[[:space:]]*$//' "$f" && fix "MD исправлен: $f"
    fi
  fi
  # пустые заголовки (#  )
  if grep -qP '^#{1,6}\s*$' "$f" 2>/dev/null; then
    warn "Пустой заголовок в: $f"
  fi
done < <(find "$PROJECT_ROOT" -name "*.md" -not -path "*/.git/*" -print0)

# ── 5. Большие файлы (>1 MB, не бинарники) ───────────────────
header "Большие файлы (>1 MB)"
while IFS= read -r -d '' f; do
  local sz=$(stat -f%z "$f" 2>/dev/null || echo 0)
  if (( sz > 1048576 )); then
    warn "Крупный файл $(( sz / 1024 )) KB: $f"
  fi
done < <(find "$PROJECT_ROOT" \
    -not -path "*/.git/*" \
    -not -path "*/DerivedData/*" \
    -not -name "*.png" -not -name "*.jpg" -not -name "*.pdf" \
    -not -name "*.zip" -not -name "*.tar*" \
    -type f -print0)

# ── 6. Дубликаты Swift-файлов (одинаковые имена) ─────────────
header "Дубликаты Swift-файлов"
typeset -A seen_swift
while IFS= read -r -d '' f; do
  local base=$(basename "$f")
  if [[ -v seen_swift[$base] ]]; then
    warn "Дубль имени: $f"
    info "  уже есть:  ${seen_swift[$base]}"
  else
    seen_swift[$base]="$f"
  fi
done < <(find "$PROJECT_ROOT" -name "*.swift" -not -path "*/.git/*" -print0)

# ── 7. TODO / FIXME / HACK счётчик ───────────────────────────
header "TODO / FIXME / HACK"
local todos=$(grep -rn --include="*.swift" -E 'TODO|FIXME|HACK' "$PROJECT_ROOT" \
    --exclude-dir=".git" 2>/dev/null | wc -l | tr -d ' ')
if (( todos > 0 )); then
  info "$todos штук найдено:"
  grep -rn --include="*.swift" -E 'TODO|FIXME|HACK' "$PROJECT_ROOT" \
    --exclude-dir=".git" 2>/dev/null | head -20
else
  ok "Нет TODO/FIXME/HACK"
fi

# ── Итог ─────────────────────────────────────────────────────
print ""
print "────────────────────────────────────"
if $FIX_MODE; then
  print -P "%B%F{green}Исправлено: $FIXED  |  Осталось проблем: $ISSUES%f%b"
else
  print -P "%B%F{yellow}Найдено проблем: $ISSUES%f%b"
  (( ISSUES > 0 )) && print -P "%F{cyan}Запустите с --fix для автоисправления%f"
fi
print "────────────────────────────────────"
(( ISSUES == 0 )) && exit 0 || exit 1
