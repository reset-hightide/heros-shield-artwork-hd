# Hero's Shield Artwork HD - installer for Windows.
#
#   irm https://raw.githubusercontent.com/reset-hightide/heros-shield-artwork-hd/main/install.ps1 | iex
#
# Copies the mods into Zelda 64: Recompiled's mods folder, downloads Player Model Manager and its
# dependencies from Thunderstore (only the ones that are missing), and picks HW Young Link HD and
# Hero's Shield HD in Player Model Manager (only if nothing else is picked there yet).
# Set RECOMP_DIR to use a different Zelda64Recompiled folder (portable installs).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRaw = 'https://raw.githubusercontent.com/reset-hightide/heros-shield-artwork-hd/main'
$OurFiles = @('hwmm_young_link_hd.nrm', 'hwmm_young_link_hd_textures.rtz', 'hwmm_heros_shield_hd.nrm', 'hwmm_heros_shield_hd_textures.rtz', 'hwmm_heros_shield_aftermatch_heavy.nrm', 'hwmm_heros_shield_aftermatch_heavy_textures.rtz', 'hwmm_heros_shield_n64.nrm')
# Thunderstore packages: namespace, name, version, file that tells us it is already installed
$Deps = @(
    @('YAZMT', 'YAZMT_Core', '0.1.1', 'yazmt_mm_corelib.nrm'),
    @('YAZMT', 'Global_Objects', '0.1.1', 'yazmt_mm_global_objects.nrm'),
    @('LT_Schmiddy', 'RecompExternalPython_for_Zelda64Recompiled', '2.0.0', 'RecompExternalPython_API.nrm'),
    @('YAZMT', 'Player_Model_Manager', '0.6.1', 'yazmt_mm_playermodelmanager.nrm')
)

function Fail($msg) {
    Write-Host ''
    Write-Host "ERRO / ERROR: $msg" -ForegroundColor Red
    throw $msg
}

function Fetch($url, $out) {
    for ($i = 1; $i -le 3; $i++) {
        try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out; return }
        catch { if ($i -eq 3) { Fail "download falhou / download failed: $url" } Start-Sleep -Seconds 2 }
    }
}

Write-Host "=== Hero's Shield Artwork HD ===" -ForegroundColor Yellow

if ($env:RECOMP_DIR) { $App = $env:RECOMP_DIR }
else { $App = Join-Path $env:LOCALAPPDATA 'Zelda64Recompiled' }
if (-not (Test-Path $App)) {
    Fail "Zelda64Recompiled nao encontrado em / not found at: $App`nAbra o Zelda 64: Recompiled pelo menos uma vez antes. / Run Zelda 64: Recompiled once first."
}
$Mods = Join-Path $App 'mods'
New-Item -ItemType Directory -Force -Path $Mods | Out-Null
Write-Host "Pasta de mods / Mods folder: $Mods"

if (Get-Process -Name 'Zelda64Recompiled' -ErrorAction SilentlyContinue) {
    Fail 'Feche o jogo antes de instalar. / Close the game before installing.'
}

$Tmp = Join-Path ([IO.Path]::GetTempPath()) ('heros-shield-artwork-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
try {
    # 1. our mods: from the mods\ folder next to this script (release zip), or from GitHub
    $Here = if ($PSScriptRoot) { $PSScriptRoot } else { '' }
    foreach ($f in $OurFiles) {
        $local = if ($Here) { Join-Path (Join-Path $Here 'mods') $f } else { '' }
        if ($local -and (Test-Path $local)) {
            Copy-Item -Force $local (Join-Path $Mods $f)
        } else {
            Fetch "$RepoRaw/mods/$f" (Join-Path $Tmp $f)
            Copy-Item -Force (Join-Path $Tmp $f) (Join-Path $Mods $f)
        }
        Write-Host "  + $f" -ForegroundColor Green
    }

    # 2. dependencies (skipped when already installed)
    foreach ($d in $Deps) {
        $ns, $name, $ver, $marker = $d
        if (Test-Path (Join-Path $Mods $marker)) {
            Write-Host "  = $name (ja instalado / already installed)"
            continue
        }
        $zip = Join-Path $Tmp "$name.zip"
        $dir = Join-Path $Tmp $name
        Fetch "https://thunderstore.io/package/download/$ns/$name/$ver/" $zip
        Expand-Archive -Force -Path $zip -DestinationPath $dir
        Get-ChildItem $dir | Where-Object {
            $_.Name -notin @('manifest.json', 'README.md', 'CHANGELOG.md', 'icon.png') -and
            $_.Name -notlike 'LICENSE*' -and $_.Name -notlike '*.so' -and $_.Name -notlike '*.so.*' -and
            $_.Name -notlike '*.dylib'
        } | Copy-Item -Recurse -Force -Destination $Mods
        Write-Host "  + $name $ver" -ForegroundColor Green
    }

    # 3. pick the models in Player Model Manager (never overrides the player's own choice)
    $IniDir = Join-Path $App 'mod_data\yazmt_z64_playermodelmanager'
    $Ini = Join-Path $IniDir 'models.ini'
    New-Item -ItemType Directory -Force -Path $IniDir | Out-Null
    $utf8 = New-Object Text.UTF8Encoding($false)
    if (-not (Test-Path $Ini)) {
        $text = "[meta]`ncfg_version = 1`n`n[mm.player1]`nchild = hwmm_young_link_hd`nshield2 = hwmm_heros_shield_hd`n"
        [IO.File]::WriteAllText($Ini, $text, $utf8)
        Write-Host "  * Player Model Manager: HW Young Link HD + Hero's Shield HD"
    } else {
        Copy-Item -Force $Ini "$Ini.before-heros-shield-artwork"
        $text = [IO.File]::ReadAllText($Ini)
        $text = [Regex]::Replace($text, '(?m)^child[ \t]*=[ \t]*(\r?)$', 'child = hwmm_young_link_hd$1')
        $text = [Regex]::Replace($text, '(?m)^shield2[ \t]*=[ \t]*(\r?)$', 'shield2 = hwmm_heros_shield_hd$1')
        [IO.File]::WriteAllText($Ini, $text, $utf8)
        Write-Host '  * Player Model Manager: models.ini atualizado / updated (backup: models.ini.before-heros-shield-artwork)'
    }
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Pronto! Abra o jogo. Para trocar de modelo: menu do Player Model Manager (L + A).' -ForegroundColor Yellow
Write-Host 'Done! Start the game. To switch models: Player Model Manager menu (L + A).' -ForegroundColor Yellow
