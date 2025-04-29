# doctch
项目主要目的：一个轻量级、跨平台的 Docker 镜像加速拉取脚本，由 Shuyingyang 编写。
项目灵感来源：[Cp0204](https://github.com/Cp0204)
---
## ✨ 特性

- ✅ 一键设置 Docker 镜像加速器
- ✅ 自动测速多个国内镜像源，选出最快(有其他更换的镜像源请添加到issue中，看到会加入镜像列表）
- ✅ 支持 HTTP/HTTPS 代理配置（需要手动修改脚本）
- ✅ 兼容所有主流 Linux 发行版
---

## 🚀 使用方法
### 📦 1. 安装依赖

确保已安装：jq

在 Debian/Ubuntu 安装：sudo apt install jq

在centos安装：sudo yum install jq

### 🧪2.下载并运行脚本
chmod +x doctch.sh
sudo ./doctch.sh start

## 🛡️ 安全性说明

- 脚本不会上传任何数据
- 可自由修改/审查脚本内容

## 🧑‍💻 
欢迎在 GitHub 提 issue 或 PR 优化建议。
