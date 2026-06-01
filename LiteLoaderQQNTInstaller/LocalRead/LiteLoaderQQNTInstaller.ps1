# 导入文件夹选择器依赖库
Add-Type -AssemblyName System.Windows.Forms
# 创建文件夹选择器函数，用于选择 QQNT 安装路径和 LiteLoaderQQNT 安装路径
function Select-FolderDialog {
	param (
		[string]$Description = "请选择文件夹",
		[bool]$ShowNewFolderButton = $true
	)
	$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
	$folderBrowser.Description = "$Description"
	$folderBrowser.ShowNewFolderButton = $ShowNewFolderButton
	if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		return $folderBrowser.SelectedPath
	} else {
		return $null
	}
}

# 获取 QQNT 安装路径
$QQNTInstallPath = $(if ((Get-Item HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT).Property -like "Install"){ (Get-Item HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT).GetValue("Install") })
if (-not $QQNTInstallPath -or $QQNTInstallPath -eq "") {
	Write-Host -ForegroundColor Red "未找到 QQNT 安装路径，可能未安装 QQNT，或者注册表信息异常。"
	Write-Host -ForegroundColor Yellow "按下任意键选择 QQNT 安装路径，或者按下 Ctrl-C 退出安装"
	while ($null -ne $QQNTInstallPath) {
		timeout.exe /t -1
		$QQNTInstallPath = Select-FolderDialog -Description "请选择 QQNT 安装路径"
	}
}

# 获取 QQNT 可执行文件路径
$QQNT = Get-ChildItem $QQNTInstallPath | Where-Object { $_.Name -like "QQ.exe" }
# 验证 QQNT 可执行文件是否存在
if (-not $QQNT -or $QQNT.Count -eq 0 -or $null -eq $QQNT -or $null -eq $QQNT.FullName -or $QQNT.FullName -eq "") {
	Write-Host -ForegroundColor Red "未找到 QQ.exe，安装路径可能不正确"
	exit
}
# 获取 QQNT 可执行文件的数字签名信息
$QQNTSinged = $QQNT | Get-AuthenticodeSignature
# 获取 QQNT 进程
$QQNTProcess = Get-Process | Where-Object { $_.Path -like "$($QQNT.FullName)" }
# 获取 QQNT 当前版本
$QQNTCurrentVersion = (Get-Content -Path $QQNTInstallPath\versions\config.json | ConvertFrom-Json).curVersion
# 获取 QQNT 可执行文件是否有备份文件
$HasQQNTExeBackup = (Test-Path -Path (Join-Path $QQNTInstallPath "QQ.exe.bak"))
$HasQQNTPackageJsonBackup = (Test-Path -Path (Join-Path $QQNTInstallPath "versions" "$QQNTCurrentVersion" "resources\app\package.json"))

$QQNTAppFolderPath = (Join-Path $QQNTInstallPath "versions" "$QQNTCurrentVersion" "resources\app")
$QQNTPackageJsonPath = (Join-Path $QQNTAppFolderPath "package.json")
$QQNTPackageJsonBackupPath = (Join-Path $QQNTAppFolderPath "package.json.bak")

# QQNT 是否正在运行
if ($QQNTProcess) {
	Write-Host -ForegroundColor Red "检测到 QQ.exe 进程正在运行，尝试关闭"
	timeout /t -1
	$QQNTProcess | Stop-Process -Force
}

# 检测 QQ.exe 是否被当前脚本修改过
if ((Get-FileHash -Path $QQNT.FullName -Algorithm SHA256).Hash -like (Get-FileHash -Path (Join-Path $PSScriptRoot "src" "QQ.exe") -Algorithm SHA256).Hash) {
	Write-Host -ForegroundColor Yellow "QQ.exe 已经过修改，请选择操作："
	Write-Host -ForegroundColor Blue "c(ontinue) 继续安装`nq(uit) 取消安装"
	if ($HasQQNTExeBackup -and $HasQQNTPackageJsonBackup) {
		Write-Host -ForegroundColor Blue "r(estore) 恢复原始文件"
	} else {
		Write-Host -ForegroundColor DarkGray "r(estore) 恢复原始文件 [x] 不可用"
	}
	while ($null -eq $key) {
		$key = [Console]::ReadKey().keyChar
		switch ($key) {
			"c" {
				break
			}
			"q" {
				Write-Host -ForegroundColor Red "取消安装"
				exit
			}
			"r" {
				if ($HasQQNTExeBackup) {
					Write-Host -ForegroundColor Green "正在恢复原始文件..."
					Remove-Item $QQNT -Force
					Move-Item -Path (Join-Path $QQNTInstallPath "QQ.exe.bak") -Destination ($QQNT.FullName) -Force
					Remove-Item $QQNTPackageJsonPath -Force
					Move-Item -Path $QQNTPackageJsonBackupPath -Destination $QQNTPackageJsonPath -Force
					exit 0
				} else {
					Write-Host -ForegroundColor Red "`r未找到备份文件，无法恢复"
				}
			}
			default {
				$key = $null
			}
		}
	}
} elseif (($QQNTSinged.Status -ne "Valid" -or $QQNTSinged.SignerCertificate.Thumbprint -ne "E1B5824EE85186B91E65DB3E75867F59E35CF4AB" -or $QQNTSinged.SignerCertificate.Subject -ne 'CN=Tencent Technology (Shenzhen) Company Limited, O=Tencent Technology (Shenzhen) Company Limited, L=Shenzhen, S=Guangdong Province, C=CN, SERIALNUMBER=9144030071526726XG, OID.2.5.4.15=Private Organization, OID.1.3.6.1.4.1.311.60.2.1.1=Shenzhen, OID.1.3.6.1.4.1.311.60.2.1.2=Guangdong Province, OID.1.3.6.1.4.1.311.60.2.1.3=CN') -and { Write-Host -ForegroundColor Yellow "QQ.exe 签名异常，可能已经经过第三方修改。确实要继续吗？"; [Console]::ReadKey().keyChar -ne "y" }) {
	# 验证 QQ.exe 的数字签名是否是官方的
	exit;
}

if ($null -eq $key) { $key = "c" }

# 检测 QQNT 当前版本是否是测试兼容的
if (($QQNTCurrentVersion -notin @("9.9.30-48517")) -and (& { Write-Host -ForegroundColor Yellow "当前版本 $QQNTCurrentVersion 未进行兼容性测试。确认继续？"; [Console]::ReadKey().keyChar -ne "y" }) ){
	exit
}

Write-Host "备份 QQ.exe"
Copy-Item $QQNT ($QQNT.FullName + ".bak") -Force

# Write-Host "备份 dbghelp.dll"
# $QQNTDbghelpDLLPath = (Join-Path $QQNTInstallPath "dbghelp.dll")
# $QQNTDbghelpDLLBackupPath = (Join-Path $QQNTInstallPath "dbghelp.dll.bak")
# Copy-Item -Path $QQNTDbghelpDLLPath -Destination $QQNTDbghelpDLLBackupPath -Force

Write-Host "备份 package.json"
Copy-Item -Path $QQNTPackageJsonPath -Destination $QQNTPackageJsonBackupPath -Force

# 选择 LiteLoaderQQNT 安装路径
$LiteLoaderQQNTDefaultInstallPath = Join-Path ([environment]::GetFolderPath("MyDocuments")) "LiteLoaderQQNT"
Write-Host "请选择 LiteLoaderQQNT 的安装路径"
Write-Host "1. 默认安装到用户文档目录: $LiteLoaderQQNTDefaultInstallPath"
Write-Host "2. 手动选择安装路径"
Write-Host "q. 退出安装"
while ($null -eq $LiteLoaderQQNTInstallFolderTypeKey) {
	$LiteLoaderQQNTInstallFolderTypeKey = [console]::ReadKey().keyChar
	switch ($LiteLoaderQQNTInstallFolderTypeKey) {
		"1" {
			$LiteLoaderQQNTInstallPath = $LiteLoaderQQNTDefaultInstallPath
		}
		"2" {
			$LiteLoaderQQNTInstallPath = Select-FolderDialog -Description "请选择 LiteLoaderQQNT 安装路径" -ShowNewFolderButton $true
			if ($null -eq $LiteLoaderQQNTInstallPath) {
				$LiteLoaderQQNTInstallFolderTypeKey = $null
				Write-Host -NoNewline "`r `r"
				break
			} elseif (-not (Test-Path -Path $LiteLoaderQQNTInstallPath)) {
				New-Item -Path $LiteLoaderQQNTInstallPath -ItemType Directory -Force | Out-Null
			}
			if ( -not ((Get-Item $LiteLoaderQQNTInstallPath).Name -Like "*LiteLoader*")) {
				$operationKey = $null
				Write-Host -ForegroundColor Yellow "`n建议将 LiteLoaderQQNT 安装在一个专门的文件夹内，以免误删重要文件。"
				Write-Host -ForegroundColor Blue "1. 使用当前路径继续安装"
				Write-Host -ForegroundColor Blue "2. 自动创建 LiteLoaderQQNT 文件夹并安装在其中"
				Write-Host -ForegroundColor Blue "3. 重新选择安装路径"
				while ($null -eq $operationKey) {
					$operationKey = [Console]::ReadKey().keyChar
					switch ($operationKey) {
						"1" {
							# 继续安装
						}
						"2" {
							$LiteLoaderQQNTInstallPath = Join-Path $LiteLoaderQQNTInstallPath "LiteLoaderQQNT"
							New-Item -Path $LiteLoaderQQNTInstallPath -ItemType Directory -Force | Out-Null
						}
						"3" {
							$LiteLoaderQQNTInstallFolderTypeKey = $null
							$LiteLoaderQQNTInstallPath = $null
							Write-Host "`n请选择 LiteLoaderQQNT 的安装路径"
							Write-Host "1. 默认安装到用户文档目录: $LiteLoaderQQNTDefaultInstallPath"
							Write-Host "2. 手动选择安装路径"
							Write-Host "q. 退出安装"
						}
						default {
							$operationKey = $null
							Write-Host -NoNewline "`r `r"
						}
					}
				}
				Write-Host "" # 换行
			}
		}
		"q" {
			Write-Host -ForegroundColor Red "`n取消安装"
			exit
		}
		default {
			$LiteLoaderQQNTInstallFolderTypeKey = $null
			Write-Host -NoNewline "`r `r"
		}
	}
}
Write-Host "" # 换行

# 解压 LiteLoaderQQNT 主程序到安装目录
Expand-Archive -Path (Join-Path $PSScriptRoot "src" "LiteLoaderQQNT.zip") -DestinationPath $LiteLoaderQQNTInstallPath -Force

Write-Host "替换 QQ.exe 以绕过 package.json 验证"
Copy-Item -Path (Join-Path $PSScriptRoot "src" "QQ.exe") -Destination $QQNTInstallPath -Force

Write-Host "添加钩子绕过 package.json 验证"
Copy-Item -Path (Join-Path $PSScriptRoot "src" "dbghelp_x64.dll") -Destination (Join-Path $QQNTInstallPath "dbghelp.dll") -Force

Write-Host "修改 package.json 以改变入口文件"
$QQNTPackageJson = ConvertFrom-Json -InputObject (Get-Content -Path $QQNTPackageJsonPath -Raw)
$QQNTPackageJson.main = "./app_launcher/LiteLoaderQQNT.js"
$QQNTPackageJson | ConvertTo-Json | Set-Content -Path $QQNTPackageJsonPath -Encoding UTF8

# 创建 LiteLoaderQQNT 启动器（替代 QQNT 入口）
Write-Host "创建 LiteLoaderQQNT 入口"
$LiteLoaderQQNTLauncherPath = (Join-Path $QQNTAppFolderPath "app_launcher\LiteLoaderQQNT.js")
New-Item -Path $LiteLoaderQQNTLauncherPath -ItemType File -Force -Value @"
require(String.raw``$(Join-Path $LiteLoaderQQNTInstallPath (((Get-Content -Path (Join-Path $LiteLoaderQQNTInstallPath "package.json") -Raw | ConvertFrom-Json).main) -Replace "\\", "/"))``);
"@