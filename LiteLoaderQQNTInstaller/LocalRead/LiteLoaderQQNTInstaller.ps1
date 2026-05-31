# 获取 QQNT 安装路径
$QQNTInstallPath = $(if ((Get-Item HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT).Property -like "Install"){ (Get-Item HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT).GetValue("Install") })
# 获取 QQNT 可执行文件路径
$QQNT = Get-ChildItem $QQNTInstallPath | Where-Object { $_.Name -like "QQ.exe" }
# 验证 QQNT 可执行文件是否存在
if (-not $QQNT -or $QQNT.Count -eq 0 -or $QQNT -eq $null -or $QQNT.FullName -eq $null -or $QQNT.FullName -eq "") {
	Write-Host -ForegroundColor Red "未找到 QQ.exe，安装路径可能不正确"
	exit
}
# 获取 QQNT 可执行文件的数字签名信息
$QQNTSinged = $QQNT | Get-AuthenticodeSignature
# 获取 QQNT 进程
$QQNTProcess = Get-Process | Where-Object { $_.Path -like "$($QQNT.Path)" }
# 获取 QQNT 当前版本
$QQNTCurrentVersion = (Get-Content -Path $QQNTInstallPath\versions\config.json | ConvertFrom-Json).curVersion

# 检测 QQ.exe 是否被当前脚本修改过
if ((Get-FileHash -Path $QQNT.FullName -Algorithm SHA256).Hash -like (Get-FileHash -Path (Join-Path $PSScriptRoot "src" "QQ.exe") -Algorithm SHA256).Hash) {
	Write-Host -ForegroundColor Yellow "QQ.exe 已经过修改，请选择操作：`nc(ontinue) 继续安装`nq(uit) 取消安装`nr(estore) 恢复原始文件"
	while ($key -ne $null) {
		$key = [Console]::ReadKey().keyChar
		if ($key -in "c", "q", "r") {
			break;
		} else {
			$key = $null
		}
	}
} else if (($QQNTSinged.Status -ne "Valid" -or $QQNTSinged.SignerCertificate.Thumbprint -ne "E1B5824EE85186B91E65DB3E75867F59E35CF4AB" -or $QQNTSinged.SignerCertificate.Subject -ne 'CN=Tencent Technology (Shenzhen) Company Limited, O=Tencent Technology (Shenzhen) Company Limited, L=Shenzhen, S=Guangdong Province, C=CN, SERIALNUMBER=9144030071526726XG, OID.2.5.4.15=Private Organization, OID.1.3.6.1.4.1.311.60.2.1.1=Shenzhen, OID.1.3.6.1.4.1.311.60.2.1.2=Guangdong Province, OID.1.3.6.1.4.1.311.60.2.1.3=CN') -and { Write-Host -ForegroundColor Yellow "QQ.exe 签名异常，可能已经经过第三方修改。确实要继续吗？"; [Console]::ReadKey().keyChar -ne "y" }) {
	# 验证 QQ.exe 的数字签名是否是官方的
	exit;
}

# 检测 QQNT 当前版本是否是测试兼容的
if ($QQNTCurrentVersion -ne "9.9.30-48517" -and & { Write-Host -ForegroundColor Yellow "当前版本 $QQNTCurrentVersion 未进行兼容性测试。确认继续？"; [Console]::ReadKey().keyChar -ne "y" } ){
	exit
}

# QQNT 是否正在运行
if ($QQNTProcess) {
	Write-Host -ForegroundColor Red "检测到 QQ.exe 进程正在运行，尝试关闭"
	$QQNTProcess | Select-Object *
	timeout /t -1
	$QQNTProcess | Stop-Process -Force
}

