# LiteLoaderQQNT Installer

[LiteLoaderQQNT](https://www.github.com/LiteLoaderQQNT/LiteLoaderQQNT) 的第三方安装器

# 使用方法

下载 Releases 中的 `LiteLoaderQQNTInstaller-Local_vxxx.zip` 压缩包，解压后运行 `LiteLoaderQQNTInstaller.ps1`。会使用 `src\` 文件夹中的内容自动替换。
或者单独下载 `/LiteLoaderQQNTInstaller/NetworkDownload/LiteLoaderQQNTInstaller.ps1`。脚本会自动从 Releases 中下载 `LiteLoaderQQNTInstaller-Network-src.zip` 并自动处理。

# 安装过程
## QQNT 的安装路径
- [x] 通过注册表获取 QQNT 的安装路径，自动替换 `QQ.exe` 以绕过检测。自动编辑 `package.json` 以设置 LiteLoaderQQNT。
- [ ] 允许手动输入 QQNT 安装路径
## LiteLoaderQQNT 的保存路径
- [ ] 自动设置为 `Join-Path ([Environment]::GetFolder('MyDocuments')) 'LiteLoaderQQNT'`
- [ ] 手动输入 LiteLoaderQQNT 的报错路径