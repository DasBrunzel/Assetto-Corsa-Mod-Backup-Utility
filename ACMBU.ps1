# Variablen für Pfade
$configFolder = "$PSScriptRoot\config"
$logFolder = "$PSScriptRoot\logs"
$currentDate = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$PSScriptRoot\debug_$currentDate.log"
$terminalLogFile = "$PSScriptRoot\terminal_$currentDate.log"
$fileUrl = "https://dl.gamblerpack.de/sonstige/7zr.exe"
$destinationFile = "$configFolder\7zr.exe"
$configFile = "$configFolder\config.json"
$savedSpaceFile = "$configFolder\saved_space.json"

# Standard-Komprimierungsstufe (Ultra)
$defaultCompressionLevel = "-mx9"

# Funktion zum Schreiben in das Debug-Log-File
function Write-DebugLog {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "${timestamp}: ${message}" | Out-File -Append -FilePath $logFile
}

# Funktion zum Schreiben des Terminal-Outputs in eine Log-Datei
function Write-TerminalLog {
    param([string]$message)
    $message | Out-File -Append -FilePath $terminalLogFile
}

# Funktion zum Archivieren der alten Log-Dateien
function Archive-OldLogs {
    if (-Not (Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory | Out-Null
    }

    Get-ChildItem -Path $PSScriptRoot -Filter "*.log" | ForEach-Object {
        Move-Item -Path $_.FullName -Destination $logFolder
    }
    Write-DebugLog "Alte Log-Dateien archiviert."
}

# Funktion zum Erstellen des Config-Ordners
function Create-Config-Folder {
    if (-Not (Test-Path $configFolder)) {
        New-Item -Path $configFolder -ItemType Directory | Out-Null
        Write-DebugLog "Config-Ordner erstellt: $configFolder"
    }
}

# Funktion zum Erstellen des Logs-Ordners
function Create-Logs-Folder {
    if (-Not (Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory | Out-Null
        Write-DebugLog "Logs-Ordner erstellt: $logFolder"
    }
}

# Funktion zum Herunterladen der Datei, wenn sie nicht vorhanden ist
function Download-File {
    if (-Not (Test-Path $destinationFile)) {
        Write-DebugLog "Die Datei 7zr.exe wird heruntergeladen..."
        Invoke-WebRequest -Uri $fileUrl -OutFile $destinationFile
        Write-DebugLog "Download abgeschlossen: $destinationFile"
    } else {
        Write-DebugLog "Die Datei 7zr.exe existiert bereits."
    }
}

# Funktion zum Anzeigen des Headers
function Show-Header {
    Clear-Host
    $header = @"
==============================
 Assetto Corsa Mod Backup Utility
 Version 0.0.1 Powershell Edition
 by Brunzel
==============================
"@
    Write-TerminalLog $header
    Write-Host $header
}

# Funktion zum Öffnen des Dialogfensters für das Quell- und Zielverzeichnis
function Select-Folder {
    param([string]$Message)
    Show-Header
    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = $Message
    $folderBrowser.ShowDialog() | Out-Null
    Write-TerminalLog "Verzeichnis ausgewählt: $($folderBrowser.SelectedPath)"
    return $folderBrowser.SelectedPath
}

# Funktion zum Laden der Konfigurationsdatei
function Load-Config {
    if (Test-Path $configFile) {
        $config = Get-Content $configFile | ConvertFrom-Json
        Write-DebugLog "Konfiguration geladen: $configFile"
    } else {
        $config = [PSCustomObject]@{
            CompressionLevel = $defaultCompressionLevel
            SourceDirectory = ""
            TargetDirectory = ""
        }
        Write-DebugLog "Neue Konfiguration erstellt."
    }
    return $config
}

# Funktion zum Speichern der Konfiguration
function Save-Config {
    param([PSCustomObject]$config)
    $config | ConvertTo-Json | Set-Content $configFile
    Write-DebugLog "Konfiguration gespeichert: $configFile"
}

# Funktion zum Laden der gespeicherten Speicherplatzinformationen
function Load-SavedSpace {
    if (Test-Path $savedSpaceFile) {
        $savedSpace = Get-Content $savedSpaceFile | ConvertFrom-Json
        Write-DebugLog "Gespeicherter Speicherplatz geladen: $savedSpaceFile"
    } else {
        $savedSpace = [PSCustomObject]@{
            TotalSavedSpace = 0
        }
        Write-DebugLog "Keine gespeicherten Speicherplatzinformationen gefunden. Neue Datei erstellt."
    }
    return $savedSpace
}

# Funktion zum Speichern der Speicherplatzinformationen
function Save-SavedSpace {
    param([PSCustomObject]$savedSpace)
    $savedSpace | ConvertTo-Json | Set-Content $savedSpaceFile
    Write-DebugLog "Gespeicherter Speicherplatz gespeichert: $savedSpaceFile"
}

# Funktion zum Packen von Dateien mit 7zr.exe und der gewählten Komprimierungsstufe
function Pack-Files {
    param([string]$sourceDir, [string]$targetDir, [string]$compressionLevel)
    
    $folders = Get-ChildItem -Path $sourceDir -Directory
    $folderCount = $folders.Count
    
    if ($folderCount -eq 0) {
        Write-Host "Keine Ordner zum Packen gefunden."
        Write-TerminalLog "Keine Ordner zum Packen gefunden."
        return
    }

    $totalSizeBefore = 0
    $totalSizeAfter = 0
    $totalSavedSize = 0

    foreach ($folder in $folders) {
        $folderName = $folder.Name
        $targetPath = Join-Path $targetDir "$folderName.7z"
        $sourcePath = $folder.FullName

        if (Test-Path $targetPath) {
            Write-Host "Archiv für $folderName existiert bereits: $targetPath"
            Write-TerminalLog "Archiv für $folderName existiert bereits: $targetPath"
            continue
        }

        # Größe des Ordners vor dem Packen berechnen
        $sizeBefore = (Get-ChildItem -Path $sourcePath -Recurse | Measure-Object -Property Length -Sum).Sum
        $totalSizeBefore += $sizeBefore

        Write-Host "Packe Ordner: $sourcePath -> $targetPath mit Komprimierungsstufe $compressionLevel"
        Write-TerminalLog "Packe Ordner: $sourcePath -> $targetPath mit Komprimierungsstufe $compressionLevel"
        Start-Process -FilePath $destinationFile -ArgumentList "a", "`"$targetPath`"", "`"$sourcePath`"", $compressionLevel -NoNewWindow -Wait

        # Größe des komprimierten Archivs berechnen
        $sizeAfter = (Get-Item $targetPath).Length
        $totalSizeAfter += $sizeAfter

        # Berechnen der gesparten Größe für diese Datei
        $savedSize = $sizeBefore - $sizeAfter
        $totalSavedSize += $savedSize
    }

    $spaceSaved = $totalSizeBefore - $totalSizeAfter
    $folderCount = $folders.Count

    Write-Host "Alle Ordner ($folderCount) wurden erfolgreich gepackt!"
    Write-Host "Gesamter Speicherplatz vor dem Packen: $([math]::round($totalSizeBefore / 1MB, 2)) MB"
    Write-Host "Gesamter Speicherplatz nach dem Packen: $([math]::round($totalSizeAfter / 1MB, 2)) MB"
    Write-Host "Gesparter Speicherplatz: $([math]::round($spaceSaved / 1MB, 2)) MB"
    Write-Host "Gesparte Größe durch Komprimierung: $([math]::round($totalSavedSize / 1MB, 2)) MB"
    
    Write-TerminalLog "Alle Ordner ($folderCount) wurden erfolgreich gepackt!"
    Write-TerminalLog "Gesamter Speicherplatz vor dem Packen: $([math]::round($totalSizeBefore / 1MB, 2)) MB"
    Write-TerminalLog "Gesamter Speicherplatz nach dem Packen: $([math]::round($totalSizeAfter / 1MB, 2)) MB"
    Write-TerminalLog "Gesparter Speicherplatz: $([math]::round($spaceSaved / 1MB, 2)) MB"
    Write-TerminalLog "Gesparte Größe durch Komprimierung: $([math]::round($totalSavedSize / 1MB, 2)) MB"
    
    # Speicherplatz in der Config-Datei speichern
    $savedSpace = Load-SavedSpace
    $savedSpace.TotalSavedSpace += $totalSavedSize
    Save-SavedSpace -savedSpace $savedSpace
}

# Funktion zum Auswählen der Komprimierungsstufe
function Choose-Compression {
    Show-Header
    Write-Host "Wähle die Komprimierungsstufe:"
    Write-Host "1. Nur speichern (-mx0)"
    Write-Host "2. Schnell (-mx1)"
    Write-Host "3. Normal (-mx5)"
    Write-Host "4. Ultra (-mx9)"
    $choice = Read-Host "Gib deine Auswahl ein (1/2/3/4)"

    switch ($choice) {
        1 { return "-mx0" }
        2 { return "-mx1" }
        3 { return "-mx5" }
        4 { return "-mx9" }
        default { 
            Write-Host "Ungültige Auswahl, Standard (Ultra) wird verwendet."
            Write-TerminalLog "Ungültige Auswahl, Standard (Ultra) wird verwendet."
            return "-mx9"
        }
    }
}

# Menü anzeigen und Auswahl treffen
function Show-Menu {
    $savedSpace = Load-SavedSpace
    Show-Header
    Write-Host ""
    Write-Host "====================================="
    Write-Host "             Hauptmenü               "
    Write-Host "====================================="
    Write-Host "1. Dateien Packen"
    Write-Host "2. Quell- und Zielverzeichnis ändern"
    Write-Host "3. Komprimierungsstufe ändern"
    Write-Host "0. Skript beenden"
    Write-Host ""
    Write-Host "Gesparter Speicherplatz insgesamt: $([math]::round($savedSpace.TotalSavedSpace / 1MB, 2)) MB"
    Write-Host ""
    Write-Host "Bitte wähle eine Option aus (1/2/3/0):"
    
    $choice = Read-Host
    return $choice
}

# Hauptlogik
function Main {
    # Logs-Ordner erstellen
    Create-Logs-Folder

    # Archivierung der alten Log-Dateien
    Archive-OldLogs

    # Config-Ordner erstellen
    Create-Config-Folder

    # Datei herunterladen
    Download-File

    # Konfiguration laden
    $config = Load-Config

    # Wenn die Konfiguration nicht existiert, Verzeichnisse abfragen
    if (-Not $config.SourceDirectory -or -Not $config.TargetDirectory) {
        $config.SourceDirectory = Select-Folder -Message "Bitte wähle das Quellverzeichnis 'cars' aus."
        $config.TargetDirectory = Select-Folder -Message "Bitte wähle das Zielverzeichnis aus."
        Save-Config -config $config
        Write-TerminalLog "Konfiguration wurde gespeichert."
    }

    # Hauptmenü anzeigen
    while ($true) {
        $choice = Show-Menu
        switch ($choice) {
            1 {
                # Dateien packen
                Pack-Files -sourceDir $config.SourceDirectory -targetDir $config.TargetDirectory -compressionLevel $config.CompressionLevel
            }
            2 {
                # Quell- und Zielverzeichnis ändern
                $config.SourceDirectory = Select-Folder -Message "Bitte wähle das neue Quellverzeichnis aus."
                $config.TargetDirectory = Select-Folder -Message "Bitte wähle das neue Zielverzeichnis aus."
                Save-Config -config $config
                Write-TerminalLog "Konfiguration wurde aktualisiert."
            }
            3 {
                # Komprimierungsstufe ändern
                $config.CompressionLevel = Choose-Compression
                Save-Config -config $config
                Write-TerminalLog "Komprimierungsstufe wurde aktualisiert: $($config.CompressionLevel)"
            }
            0 {
                # Skript beenden
                Write-Host "Skript wird beendet."
                Write-TerminalLog "Skript wird beendet."
                break
            }
            default {
                Write-Host "Ungültige Auswahl, bitte versuche es erneut."
                Write-TerminalLog "Ungültige Auswahl, bitte versuche es erneut."
            }
        }
    }
}

# Skript starten
Main
