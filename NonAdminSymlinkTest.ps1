<#
  Usage:
    管理者として実行してください。
    .\disable-nonadmin-symlink-test.ps1

  概要:
    - HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\AllowDevelopmentWithoutDevLicense をバックアップして 0 にする（Developer Mode を無効化）
    - テスト用のローカル非管理者ユーザーを作成し、そのユーザーでシンボリックリンク作成を試行
    - 結果を表示し、レジストリ値とテストユーザーを元に戻す

  注意:
    - GitHub の共有ホスト上で実行すると他プロセス/ジョブに影響を与える可能性があります。まずは専用環境で試してください。
    - ユーザー権利の変更（secedit を使う方法）はログオフ/再ログオンまたは再起動を要する場合があります。本スクリプトは主に Developer Mode の切り替えを行います。
#>

# 設定（必要なら変更）

$tempDir = "$env:TEMP\symlink-test"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
$target = Join-Path $tempDir 'target.txt'
$link = Join-Path $tempDir 'link.txt'

# 管理者チェック
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

Write-Host ($isAdmin ? "管理者として実行中" : "一般ユーザーとして実行中")

# 1) 現在の Developer Mode (AppModelUnlock) 値を保存
$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
$regName = 'AllowDevelopmentWithoutDevLicense'
$origValue = $null
if (Test-Path $regPath) {
    try { $origValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction Stop).$regName } catch { $origValue = $null }
}

Write-Host "バックアップ: $regPath\$regName の現在値 = $origValue"

# 2) Developer Mode を無効化（存在しなければ作成して 0 を入れる）
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name $regName -Value 0 -Type DWord
Write-Host "Developer Mode を無効化しました（レジストリ: $regPath\$regName = 0）"

# 4) テスト対象ファイルを作る
Set-Content -Path $target -Value "hello symlink test" -Force
if (Test-Path $link) { Remove-Item $link -Force -ErrorAction SilentlyContinue }

Write-Host "シンボリックリンク作成を試行します..."

# 5) シンボリックリンクを作る
New-Item -Path $link -ItemType SymbolicLink -Value $target -ErrorAction Continue

# 6) 結果判定
if (-not $? -and (Test-Path $link)) {
    Write-Host "RESULT: シンボリックリンク作成に成功しました（リンクが作成されています）"
} else {
    Write-Host "RESULT: シンボリックリンク作成に失敗しました（ExitCode=$($LASTEXITCODE)）。リンクの存在: $(Test-Path $link)"
}

# 7) 復元処理（レジストリとユーザー削除）
# レジストリを元に戻す
if ($null -eq $origValue) {
    # 元々キー/値が無ければ削除
    Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    Write-Host "レジストリ値を削除して復元しました（元は無し）"
} else {
    Set-ItemProperty -Path $regPath -Name $regName -Value $origValue -Type DWord
    Write-Host "レジストリ値を元に戻しました: $regName = $origValue"
}

Write-Host "作業ディレクトリ ($tempDir) に結果ファイルが残っています。必要なら削除してください。"