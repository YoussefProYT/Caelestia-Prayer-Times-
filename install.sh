#!/usr/bin/env bash
set -Eeuo pipefail

# Caelestia Prayer Times: install without cloning, compiling, sudo, or editing /usr.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PAYLOAD="$SCRIPT_DIR/prayer-times"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
USER_SHELL="$CONFIG_HOME/quickshell/caelestia"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_HOME/caelestia-prayer-times"
MANIFEST="$STATE_DIR/manifest"
MODE=install
ASSUME_YES=0
TARGET_ARG=""
TARGET=""
SYSTEM_SOURCE=""
COPY_CREATED=0
BASELINE_HASH=""
CONTENT_BACKUP=""
PATCHED_CONTENT=0
NEW_FILES=()
FILES=(
    "modules/dashboard/PrayerTimes.qml"
    "services/PrayerService.qml"
    "services/Adhan.js"
    "services/ADHAN-JS-LICENSE.txt"
)

usage() {
    cat <<'EOF'
Caelestia Prayer Times

الاستخدام المعتاد:
  ./install.sh             اكتشاف Caelestia والتثبيت تلقائيًا
  ./install.sh --update    تحديث ملفات الإضافة المثبتة
  ./install.sh --uninstall إزالة الإضافة والرجوع للحالة السابقة

خيارات إضافية:
  --check                  فحص فقط، بلا تعديل
  --target PATH            مسار shell غير قياسي (اختياري)
  --yes                    عدم طلب تأكيد تفاعلي
  --help                   عرض هذه المساعدة
EOF
}

fail() { printf '[خطأ] %s\n' "$*" >&2; exit 1; }
info() { printf '[معلومة] %s\n' "$*"; }
ok() { printf '[تم] %s\n' "$*"; }

is_shell_dir() {
    local d="${1%/}"
    [[ -f "$d/shell.qml" && -f "$d/modules/dashboard/Content.qml" && -f "$d/services/Weather.qml" ]]
}

is_system_path() {
    case "$(realpath -e -- "$1" 2>/dev/null || printf '%s' "$1")" in
        /usr/*|/etc/xdg/*|/opt/*) return 0 ;;
        *) return 1 ;;
    esac
}

find_system_shell() {
    local candidate base pkg path
    local -a bases=()
    IFS=: read -r -a bases <<< "${XDG_CONFIG_DIRS:-/etc/xdg}"
    for base in "${bases[@]}"; do
        candidate="${base%/}/quickshell/caelestia"
        if is_shell_dir "$candidate"; then printf '%s\n' "$candidate"; return 0; fi
    done
    for candidate in \
        /etc/xdg/quickshell/caelestia \
        /usr/share/quickshell/caelestia \
        /usr/lib/quickshell/caelestia \
        /usr/share/caelestia/shell \
        /usr/lib/caelestia/shell; do
        if is_shell_dir "$candidate"; then printf '%s\n' "$candidate"; return 0; fi
    done
    # Arch/CachyOS package fallback: ask pacman where Caelestia installed shell.qml.
    if command -v pacman >/dev/null 2>&1; then
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] || continue
            while IFS= read -r path; do
                candidate="${path%/shell.qml}"
                if is_shell_dir "$candidate"; then printf '%s\n' "$candidate"; return 0; fi
            done < <(pacman -Ql "$pkg" 2>/dev/null | awk '$2 ~ /\/shell\.qml$/ {print $2}')
        done < <(pacman -Qq 2>/dev/null | grep -i 'caelestia' || true)
    fi
    return 1
}

tree_hash() {
    python3 - "$1" <<'PY'
import hashlib, os, sys
from pathlib import Path
root = Path(sys.argv[1])
h = hashlib.sha256()
for p in sorted(root.rglob("*"), key=lambda x: x.as_posix()):
    rel = p.relative_to(root).as_posix().encode()
    if p.is_symlink():
        payload = b"L\0" + rel + b"\0" + os.readlink(p).encode()
    elif p.is_file():
        payload = b"F\0" + rel + b"\0"
        h.update(len(payload).to_bytes(8, "big")); h.update(payload)
        with p.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        continue
    else:
        continue
    h.update(len(payload).to_bytes(8, "big")); h.update(payload)
print(h.hexdigest())
PY
}

content_patch() {
    local operation="$1" file="$2"
    python3 - "$operation" "$file" <<'PY'
import os, re, sys, tempfile
from pathlib import Path
mode, name = sys.argv[1:]
p = Path(name)
text = p.read_text()

def write_atomic(value):
    fd, tmp = tempfile.mkstemp(prefix=p.name + ".", dir=p.parent)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(value)
        os.chmod(tmp, p.stat().st_mode & 0o777)
        os.replace(tmp, p)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

kinds = ("tab", "component")
if mode == "install":
    if "caelestia-prayer-times:" in text or "prayerTimesComponent" in text:
        raise SystemExit("Content.qml already contains a prayer tab or partial installer markers; refusing to duplicate it.")
    all_tabs = re.search(r"\bconst\s+allTabs\s*=\s*\[", text)
    if not all_tabs:
        raise SystemExit("Cannot find the Dashboard tab array (const allTabs = [); this Caelestia version needs an updated installer.")
    close = re.search(r"(?m)^[ \t]*\];[ \t]*$", text[all_tabs.end():])
    if not close:
        raise SystemExit("Cannot find the end of the Dashboard tab array; no files were changed.")
    close_start = all_tabs.end() + close.start()
    indent = re.match(r"[ \t]*", text[close_start:]).group(0)
    before = text[:close_start].rstrip()
    needs_comma = bool(before) and not before.endswith(",")
    tab = f"{indent}// >>> caelestia-prayer-times:tab\n"
    if needs_comma:
        tab += f"{indent},\n"
    tab += (
        f"{indent}{{\n"
        f"{indent}    component: prayerTimesComponent,\n"
        f"{indent}    iconName: \"schedule\",\n"
        f"{indent}    text: Tr.tr(\"Prayer times\"),\n"
        f"{indent}    enabled: true\n"
        f"{indent}}},\n"
        f"{indent}// <<< caelestia-prayer-times:tab\n"
    )
    text = before + "\n" + tab + text[close_start:]
    root_close = text.rfind("\n}")
    if root_close < 0:
        raise SystemExit("Cannot locate the root closing brace in Content.qml; no files were changed.")
    component = (
        "\n    // >>> caelestia-prayer-times:component\n"
        "    Component {\n"
        "        id: prayerTimesComponent\n\n"
        "        Item {\n"
        "            implicitWidth: prayerLoader.item?.implicitWidth ?? 840\n"
        "            implicitHeight: prayerLoader.item?.implicitHeight ?? 480\n\n"
        "            Loader {\n"
        "                id: prayerLoader\n"
        "                anchors.fill: parent\n"
        "                source: Qt.resolvedUrl(\"PrayerTimes.qml\")\n"
        "            }\n\n"
        "            Text {\n"
        "                anchors.centerIn: parent\n"
        "                visible: prayerLoader.status === Loader.Error\n"
        "                text: qsTr(\"Prayer times could not be loaded.\")\n"
        "            }\n"
        "        }\n"
        "    }\n"
        "    // <<< caelestia-prayer-times:component\n"
    )
    text = text[:root_close] + component + text[root_close:]
    write_atomic(text)
elif mode == "uninstall":
    for kind in kinds:
        start = f"// >>> caelestia-prayer-times:{kind}"
        end = f"// <<< caelestia-prayer-times:{kind}"
        starts, ends = text.count(start), text.count(end)
        if starts != ends or starts > 1:
            raise SystemExit(f"The {kind} marker block was edited or duplicated; refusing to change Content.qml.")
        if starts == 1:
            pattern = re.compile(r"(?m)^[ \t]*" + re.escape(start) + r"\n.*?^[ \t]*" + re.escape(end) + r"\n?", re.S)
            match = pattern.search(text)
            count = 1 if match else 0
            if count != 1:
                raise SystemExit(f"Could not safely remove the {kind} block.")
            start_at = match.start()
            if kind == "component" and start_at > 0 and text[start_at - 1] == "\n":
                start_at -= 1
            text = text[:start_at] + text[match.end():]
    if "caelestia-prayer-times:" in text:
        raise SystemExit("Unrecognized installer markers remain in Content.qml.")
    write_atomic(text)
else:
    raise SystemExit("Unknown patch operation")
PY
}

confirm() {
    (( ASSUME_YES )) && return 0
    [[ -t 0 ]] || fail "No interactive terminal. Re-run with --yes if you want to proceed."
    local answer
    read -r -p "$1 [Y/n] " answer
    [[ -z "$answer" || "$answer" == [yY]* ]]
}

resolve_target() {
    if [[ -n "$TARGET_ARG" ]]; then
        local resolved
        is_shell_dir "$TARGET_ARG" || fail "Not a Caelestia shell directory: $TARGET_ARG"
        resolved="$(realpath -e -- "$TARGET_ARG")"
        if is_system_path "$resolved" || [[ ! -w "$resolved/modules/dashboard/Content.qml" ]]; then
            SYSTEM_SOURCE="$resolved"
            if is_shell_dir "$USER_SHELL"; then
                TARGET="$(realpath -e -- "$USER_SHELL")"
            else
                TARGET="$USER_SHELL"
                COPY_CREATED=1
            fi
        else
            TARGET="$resolved"
        fi
    elif is_shell_dir "$USER_SHELL"; then
        TARGET="$(realpath -e -- "$USER_SHELL")"
    else
        SYSTEM_SOURCE="$(find_system_shell || true)"
        [[ -n "$SYSTEM_SOURCE" ]] || fail "Could not find Caelestia automatically. Install the shell first, or pass --target /path/to/caelestia."
        TARGET="$USER_SHELL"
        COPY_CREATED=1
    fi

    if (( COPY_CREATED )); then
        [[ ! -e "$TARGET" ]] || fail "$TARGET already exists but is not the detected shell; refusing to overwrite it."
        BASELINE_HASH="$(tree_hash "$SYSTEM_SOURCE")"
    else
        [[ -w "$TARGET/modules/dashboard/Content.qml" ]] || fail "Cannot write to $TARGET. The system copy is never edited; run without --target to create a user copy."
    fi
}

install_addon() {
    [[ -d "$PAYLOAD" ]] || fail "Missing addon payload folder: $PAYLOAD"
    [[ -f "$PAYLOAD/modules/dashboard/PrayerTimes.qml" && -f "$PAYLOAD/services/PrayerService.qml" && -f "$PAYLOAD/services/Adhan.js" ]] || fail "The addon payload is incomplete."
    command -v python3 >/dev/null 2>&1 || fail "python3 is required for the safe QML registration step."
    [[ ! -e "$MANIFEST" ]] || fail "The addon is already installed. Use --update to apply a newer addon bundle."

    resolve_target
    if (( COPY_CREATED )); then
        printf 'Detected system shell: %s\nA personal copy will be created at: %s\n' "$SYSTEM_SOURCE" "$TARGET"
        PREFLIGHT_ROOT="$SYSTEM_SOURCE"
    else
        printf 'Detected user shell: %s\n' "$TARGET"
        PREFLIGHT_ROOT="$TARGET"
    fi
    printf 'The installer will add the prayer tab and four QML/library files. It will not use sudo, edit /usr, or build C++.\n'
    for rel in "${FILES[@]}"; do
        [[ ! -e "$PREFLIGHT_ROOT/$rel" ]] || fail "Refusing to overwrite existing file: $PREFLIGHT_ROOT/$rel"
    done
    preflight="$(mktemp)"
    cp "$PREFLIGHT_ROOT/modules/dashboard/Content.qml" "$preflight"
    if ! content_patch install "$preflight"; then
        rm -f "$preflight"
        fail "This Caelestia version could not be patched safely; no shell files were changed."
    fi
    rm -f "$preflight"

    if (( ! ASSUME_YES )); then
        confirm "Install Caelestia Prayer Times into this user shell copy?" || { info "Cancelled; nothing changed."; exit 0; }
    fi

    if (( COPY_CREATED )); then
        mkdir -p "$(dirname "$TARGET")"
        cp -a --no-preserve=ownership "$SYSTEM_SOURCE" "$TARGET" || { rm -rf "$TARGET"; fail "Could not create the user-owned shell copy."; }
        chmod -R u+w "$TARGET"
        is_shell_dir "$TARGET" || { rm -rf "$TARGET"; fail "The copied shell did not pass validation; it was removed."; }
    fi

    mkdir -p "$STATE_DIR/backups"
    CONTENT_BACKUP="$STATE_DIR/backups/Content.qml.$(date +%Y%m%d-%H%M%S).bak"
    cp -p "$TARGET/modules/dashboard/Content.qml" "$CONTENT_BACKUP"
    for rel in "${FILES[@]}"; do
        [[ ! -e "$TARGET/$rel" ]] || fail "Refusing to overwrite existing file: $TARGET/$rel"
    done

    for rel in "${FILES[@]}"; do
        if ! install -D -m 644 "$PAYLOAD/$rel" "$TARGET/$rel"; then
            rm -f "$TARGET/$rel"
            for made in "${NEW_FILES[@]}"; do rm -f "$TARGET/$made"; done
            (( COPY_CREATED )) && rm -rf "$TARGET"
            fail "Could not copy addon files; changes were rolled back."
        fi
        NEW_FILES+=("$rel")
    done

    if ! content_patch install "$TARGET/modules/dashboard/Content.qml"; then
        for made in "${NEW_FILES[@]}"; do rm -f "$TARGET/$made"; done
        cp -p "$CONTENT_BACKUP" "$TARGET/modules/dashboard/Content.qml"
        (( COPY_CREATED )) && rm -rf "$TARGET"
        fail "Could not register the tab; changes were rolled back."
    fi

    {
        printf '# caelestia-prayer-times v7\n'
        printf '# target=%s\n# copy_created=%s\n# source=%s\n# baseline_hash=%s\n' "$TARGET" "$COPY_CREATED" "$SYSTEM_SOURCE" "$BASELINE_HASH"
        for rel in "${FILES[@]}"; do
            printf 'F\t%s\t%s\n' "$(sha256sum "$TARGET/$rel" | cut -d' ' -f1)" "$rel"
        done
    } > "$MANIFEST.tmp" || {
        content_patch uninstall "$TARGET/modules/dashboard/Content.qml" || true
        for rel in "${FILES[@]}"; do rm -f "$TARGET/$rel"; done
        (( COPY_CREATED )) && rm -rf "$TARGET"
        fail "Could not record installation state; changes were rolled back."
    }
    chmod 600 "$MANIFEST.tmp"
    mv -f "$MANIFEST.tmp" "$MANIFEST"
    ok "Prayer-times tab installed. Caelestia watches QML files; if it does not reload automatically, restart the shell."
    if (( COPY_CREATED )); then
        info "A user copy now takes precedence over the package shell. The installer can remove it on uninstall if it remains unchanged."
    fi
    info "Location options are stored in: $CONFIG_HOME/caelestia/prayer-times.json (see README.md)."
}

update_addon() {
    [[ -f "$MANIFEST" ]] || fail "No installed addon manifest found at $MANIFEST. Install the addon first."
    [[ -f "$PAYLOAD/services/PrayerService.qml" && -f "$PAYLOAD/modules/dashboard/PrayerTimes.qml" ]] || fail "The update payload is incomplete."

    TARGET="$(sed -n 's/^# target=//p' "$MANIFEST" | head -n1)"
    local copied source baseline rel previous current backup_dir temp_manifest
    copied="$(sed -n 's/^# copy_created=//p' "$MANIFEST" | head -n1)"
    source="$(sed -n 's/^# source=//p' "$MANIFEST" | head -n1)"
    baseline="$(sed -n 's/^# baseline_hash=//p' "$MANIFEST" | head -n1)"
    [[ -n "$TARGET" && -d "$TARGET" ]] || fail "The installed shell directory no longer exists: $TARGET"

    for rel in "${FILES[@]}"; do
        [[ -f "$PAYLOAD/$rel" ]] || fail "The update is missing $rel."
        [[ -f "$TARGET/$rel" ]] || fail "Installed addon file is missing: $TARGET/$rel. Reinstall instead of updating."
        previous="$(awk -F '\t' -v path="$rel" '$1 == "F" && $3 == path { print $2 }' "$MANIFEST")"
        [[ -n "$previous" ]] || fail "The installation manifest does not track $rel."
        current="$(sha256sum "$TARGET/$rel" | cut -d' ' -f1)"
        [[ "$current" == "$previous" ]] || fail "Refusing to overwrite a locally modified addon file: $TARGET/$rel"
    done

    printf 'Updating the prayer-times files in: %s\n' "$TARGET"
    if (( ! ASSUME_YES )); then
        confirm "Update the installed prayer-times addon?" || { info "Cancelled; nothing changed."; exit 0; }
    fi

    backup_dir="$STATE_DIR/backups/update.$(date +%Y%m%d-%H%M%S).$$"
    mkdir -p "$backup_dir"
    for rel in "${FILES[@]}"; do
        mkdir -p "$backup_dir/$(dirname "$rel")"
        cp -p "$TARGET/$rel" "$backup_dir/$rel"
    done

    for rel in "${FILES[@]}"; do
        local staged="$TARGET/$rel.update.$$"
        if ! install -m 644 "$PAYLOAD/$rel" "$staged" || ! mv -f "$staged" "$TARGET/$rel"; then
            rm -f "$staged"
            for rel in "${FILES[@]}"; do cp -p "$backup_dir/$rel" "$TARGET/$rel"; done
            rm -rf "$backup_dir"
            fail "Update failed; the original addon files were restored."
        fi
    done

    temp_manifest="$MANIFEST.tmp"
    {
        printf '# caelestia-prayer-times v7\n'
        printf '# target=%s\n# copy_created=%s\n# source=%s\n# baseline_hash=%s\n' "$TARGET" "$copied" "$source" "$baseline"
        for rel in "${FILES[@]}"; do
            printf 'F\t%s\t%s\n' "$(sha256sum "$TARGET/$rel" | cut -d' ' -f1)" "$rel"
        done
    } > "$temp_manifest" || {
        for rel in "${FILES[@]}"; do cp -p "$backup_dir/$rel" "$TARGET/$rel"; done
        rm -rf "$backup_dir"
        fail "Could not update the manifest; the original addon files were restored."
    }
    chmod 600 "$temp_manifest"
    mv -f "$temp_manifest" "$MANIFEST"
    rm -rf "$backup_dir"
    ok "Prayer-times addon updated. If Caelestia does not reload the QML automatically, restart the shell."
}

uninstall_addon() {
    [[ -f "$MANIFEST" ]] || fail "No installation manifest found at $MANIFEST. Nothing to uninstall."
    TARGET="$(sed -n 's/^# target=//p' "$MANIFEST" | head -n1)"
    local copied source baseline
    copied="$(sed -n 's/^# copy_created=//p' "$MANIFEST" | head -n1)"
    source="$(sed -n 's/^# source=//p' "$MANIFEST" | head -n1)"
    baseline="$(sed -n 's/^# baseline_hash=//p' "$MANIFEST" | head -n1)"
    [[ -n "$TARGET" && -d "$TARGET" ]] || fail "The installed shell directory no longer exists: $TARGET"
    printf 'Shell to clean: %s\n' "$TARGET"
    if (( ! ASSUME_YES )); then
        confirm "Remove the prayer tab and only the unchanged addon files?" || { info "Cancelled; nothing changed."; exit 0; }
    fi
    content_patch uninstall "$TARGET/modules/dashboard/Content.qml" || fail "Could not safely remove the marked QML registration."
    local removed=0 kept=0 sha rel
    while IFS=$'\t' read -r kind sha rel; do
        [[ "$kind" == F && -n "$rel" ]] || continue
        if [[ ! -e "$TARGET/$rel" ]]; then continue; fi
        if [[ "$(sha256sum "$TARGET/$rel" | cut -d' ' -f1)" == "$sha" ]]; then
            rm -f "$TARGET/$rel"
            removed=$((removed + 1))
        else
            printf '[تحذير] تُرك الملف لأنه عُدّل بعد التثبيت: %s\n' "$TARGET/$rel"
            kept=$((kept + 1))
        fi
    done < <(grep -v '^#' "$MANIFEST")
    mv "$MANIFEST" "$STATE_DIR/manifest.uninstalled.$(date +%Y%m%d-%H%M%S)"
    ok "Removed $removed addon files; preserved $kept files changed by you."

    if [[ "$copied" == 1 && -n "$baseline" && -d "$TARGET" ]]; then
        local current
        current="$(tree_hash "$TARGET")"
        if [[ "$current" == "$baseline" ]]; then
            rm -rf -- "$TARGET"
            ok "Removed the untouched user-copy created for this addon; the packaged Caelestia shell is active again."
        else
            info "Kept the user shell copy because it contains changes beyond the addon: $TARGET"
            info "Delete it manually only if you want to return fully to the packaged shell."
        fi
    fi
    info "Your prayer-times.json preferences are left untouched."
}

while (($#)); do
    case "$1" in
        --install) MODE=install ;;
        --update) MODE=update ;;
        --uninstall) MODE=uninstall ;;
        --check) MODE=check ;;
        --target) shift; (($#)) || fail "--target needs a path"; TARGET_ARG="$1" ;;
        --yes|-y) ASSUME_YES=1 ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1 (use --help)" ;;
    esac
    shift
done

if [[ "$MODE" == uninstall ]]; then
    uninstall_addon
elif [[ "$MODE" == update ]]; then
    update_addon
elif [[ "$MODE" == check ]]; then
    resolve_target
    printf '[تم] Caelestia found: %s\n' "${SYSTEM_SOURCE:-$TARGET}"
    if (( COPY_CREATED )); then printf '[معلومة] Install will create a user copy at: %s\n' "$TARGET"; fi
    printf '[تم] QML tab registration check: '
    CHECK_ROOT="$TARGET"
    (( COPY_CREATED )) && CHECK_ROOT="$SYSTEM_SOURCE"
    tmp="$(mktemp)"; cp "$CHECK_ROOT/modules/dashboard/Content.qml" "$tmp"
    if content_patch install "$tmp" >/dev/null; then echo compatible; else rm -f "$tmp"; fail "Dashboard layout is not supported by this installer."; fi
    rm -f "$tmp"
else
    install_addon
fi
