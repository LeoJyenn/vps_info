# 系统信息监控脚本 (System Information Monitoring Tool)

一个简洁、美观的Linux系统信息监控脚本，适用于多种Linux发行版。采用彩色输出，界面一目了然，无需安装。

## 功能特点

- ✨ 显示系统基本信息（主机名，运营商等）
- ✨ 显示系统和内核版本
- ✨ 显示CPU信息（架构，型号，核心数，使用率）
- ✨ 显示内存使用情况（物理内存，虚拟内存）
- ✨ 显示硬盘使用情况
- ✨ 显示网络流量统计
- ✨ 显示网络拥塞算法
- ✨ 显示公网IP地址（IPv4和IPv6）
- ✨ 显示基于IP的地理位置
- ✨ 显示系统时间和运行时长
- ✨ 彩色输出，界面简洁美观

## 在线运行（无需下载）

只需要一条命令即可在线运行本脚本，无需下载，无需安装：

```bash
curl -s https://raw.githubusercontent.com/LeoJyenn/vps-info/main/system_info.sh | bash
```

或者使用wget:

```bash
wget -qO- https://raw.githubusercontent.com/LeoJyenn/vps-info/main/system_info.sh | bash
```

这两个命令都会直接从网络获取脚本内容并通过bash执行，完全即用即走，不会在本地保存文件。

## 依赖项

脚本运行需要以下常见工具（大多数Linux发行版默认已安装）：
- bc (用于计算)
- curl (用于获取IP和地理位置信息)
- free (用于内存信息)
- df (用于硬盘信息)
- grep, awk (用于文本处理)

## 兼容性

已在以下系统上测试通过：
- Ubuntu/Debian系列
- CentOS/RHEL系列
- Alpine Linux
- Arch Linux

## 许可证

MIT License 