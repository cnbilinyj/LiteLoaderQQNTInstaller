$QQNTInstallPath = $(if ((Get-Item HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT).Property -like "Install"){ (Get-Item HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT).GetValue("Install") })
$QQNT = Get-ChildItem $QQNTInstallPath | Where-Object { $_.Name -eq "QQ.exe" }
$QQNTSinged = $QQNT | Get-AuthenticodeSignature
$QQNTProcess = Get-Process | Where-Object { $_.Path -eq $QQNT.Path }
$QQNTCurrentVersion = (Get-Content -Path $QQNTInstallPath\versions\config.json | ConvertFrom-Json).curVersion

if (($QQNTSinged.Status -ne "Valid" -or $QQNTSinged.SignerCertificate.Thumbprint -ne "E1B5824EE85186B91E65DB3E75867F59E35CF4AB" -or $QQNTSinged.SignerCertificate.Subject -ne 'CN=Tencent Technology (Shenzhen) Company Limited, O=Tencent Technology (Shenzhen) Company Limited, L=Shenzhen, S=Guangdong Province, C=CN, SERIALNUMBER=9144030071526726XG, OID.2.5.4.15=Private Organization, OID.1.3.6.1.4.1.311.60.2.1.1=Shenzhen, OID.1.3.6.1.4.1.311.60.2.1.2=Guangdong Province, OID.1.3.6.1.4.1.311.60.2.1.3=CN') -and { Write-Host -ForegroundColor Yellow "QQ.exe 签名异常，可能已经经过修改。确实要继续吗？"; [Console]::ReadKey().keyChar -ne "y" }) {
	exit;
}