# Joe 安装脚本优化计划

## 环境信息
- **系统**: Linux Mint 22.3 (Zena) 基于 Ubuntu 24.04 (noble)
- **包管理器**: apt (Debian 系)
- **硬件**: Intel Core Ultra 5 225U, 938GB 磁盘 (12% 使用)
- **已安装**: zsh 5.9, git 2.43.0, curl 8.5.0, python3.12

## 当前状态分析

### ✅ 良好的部分
1. **跨发行版支持完善**: lib_distro.sh 已覆盖 apt/pacman/dnf/zypper，并正确处理 Ubuntu 24.04 的 t64 包重命名
2. **模块化设计**: 各脚本职责清晰，TUI 模块可复用
3. **幂等性设计**: 重复运行安全，已有配置会跳过
4. **语法检查全通过**: shellcheck 无警告
5. **Linux Mint 兼容**: 已正确识别为 debian 家族，ubuntu 基线 24.04

### ⚠️ 待验证/优化的问题

#### 1. **错误处理和回退机制不完整**
- **问题**: 网络请求缺少超时和重试机制
- **影响**: 下载大文件（Ghostty AppImage ~140MB）时可能卡住
- **优先级**: 高

#### 2. **依赖检查不全面**
- **问题**: install_mcp_servers.sh 依赖 python3/npx，但未在脚本开头统一检查
- **影响**: 运行到一半才失败，用户体验差
- **优先级**: 中

#### 3. **Mint 特有问题未专门处理**
- **问题**: Mint 可能有自己的源策略（mintsources），某些 PPA 可能不兼容
- **影响**: Ghostty/Zed 等第三方源可能安装失败
- **优先级**: 中

#### 4. **日志记录不统一**
- **问题**: install.sh 用英文+log()，其他脚本用中文+info()/ok()/warn()/die()
- **影响**: 日志难以统一分析
- **优先级**: 低

#### 5. **doctor.sh 检测不完整**
- **问题**: 没检测系统必备依赖（curl/git/python3/Node版本）
- **影响**: 无法提前发现环境问题
- **优先级**: 中

#### 6. **TUI 在某些终端模拟器下可能显示异常**
- **问题**: ANSI 转义序列兼容性未全面测试
- **影响**: Konsole/Alacritty 等终端可能光标错位
- **优先级**: 低

## 优化方案

### 第一阶段：关键修复（高优先级）

#### 1.1 增强网络请求的鲁棒性
**文件**: `lib_github.sh`, `install_devtools.sh`

```bash
# 添加带超时和重试的下载函数
download_with_retry() {
    local url="$1" output="$2" max_attempts=3 timeout=300
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        info "下载 $url (尝试 $attempt/$max_attempts)..."
        if curl -fsSL --connect-timeout 30 --max-time "$timeout" \
               -o "$output" "$url"; then
            ok "下载成功"
            return 0
        fi
        warn "下载失败，等待 5 秒后重试..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    die "下载失败: $url"
}
```

#### 1.2 统一前置依赖检查
**新增**: `check_prerequisites()` 函数在所有安装脚本中

```bash
check_prerequisites() {
    local missing=()
    
    command -v git >/dev/null 2>&1 || missing+=(git)
    command -v curl >/dev/null 2>&1 || missing+=(curl)
    
    # 特定脚本的额外检查
    if [ "${SCRIPT_NAME:-}" = "install_mcp_servers" ]; then
        command -v python3 >/dev/null 2>&1 || missing+=(python3)
        command -v node >/dev/null 2>&1 || missing+=(nodejs)
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        warn "缺少必要依赖: ${missing[*]}"
        info "运行以下命令安装: sudo apt install ${missing[*]}"
        return 1
    fi
    return 0
}
```

#### 1.3 完善 Mint 特有兼容性处理
**文件**: `lib_distro.sh`

```bash
# Mint 可能禁用了某些 Ubuntu PPA，需要检测并提示
check_mint_ppa_support() {
    if [ "$(distro_id)" = "linuxmint" ]; then
        if ! grep -q "noble" /etc/apt/sources.list.d/* 2>/dev/null; then
            warn "Linux Mint 可能未启用 Ubuntu noble 源"
            warn "某些 PPA 可能无法使用，建议手动验证"
        fi
    fi
}
```

### 第二阶段：功能增强（中优先级）

#### 2.1 增强 doctor.sh 检测能力
**文件**: `doctor.sh`

新增检测项：
- 系统版本兼容性（是否在支持列表内）
- 网络连接状态（检测 GitHub/npm registry 可达性）
- 磁盘空间（至少需要 10GB 用于开发工具）
- 必备系统包版本（git >= 2.20, curl >= 7.50, python >= 3.8）

#### 2.2 添加安装进度指示
**文件**: 所有安装脚本

```bash
show_progress() {
    local current="$1" total="$2" task="$3"
    printf '\r[%d/%d] %s...' "$current" "$total" "$task"
}
```

#### 2.3 统一日志格式
**策略**: 
- 用户交互消息保持中文（info/ok/warn/die）
- install.log 用英文+时间戳（便于自动化分析）
- 添加 `--lang=en` 选项支持英文输出

### 第三阶段：用户体验优化（低优先级）

#### 3.1 添加卸载脚本
**新增**: `uninstall.sh`
- 清理安装的所有组件
- 恢复备份的配置文件
- 可选择性卸载（TUI 勾选）

#### 3.2 配置迁移工具
**新增**: `migrate-config.sh`
- 从旧机器导出配置
- 在新机器导入配置
- 支持选择性同步

#### 3.3 性能优化
- 并行下载多个独立组件
- 缓存已下载的安装包
- 支持离线安装模式（预下载所有依赖）

## 具体修改清单

### 必须修改的文件（阶段一）

1. **lib_github.sh** - 添加 `download_with_retry()` 函数
2. **lib_distro.sh** - 添加 `check_mint_ppa_support()` 函数
3. **install.sh** - 开头添加 `check_prerequisites()` 调用
4. **install_devtools.sh** - 开头添加 `check_prerequisites()` 调用
5. **install_mcp_servers.sh** - 开头添加 `check_prerequisites()` 调用
6. **doctor.sh** - 新增系统兼容性、网络、磁盘、版本检测

### 建议修改的文件（阶段二）

7. **bootstrap.sh** - 添加整体进度显示
8. **所有 install_*.sh** - 统一日志输出方式
9. **README.md / README.en.md** - 更新 Mint 特定说明

### 可选新增文件（阶段三）

10. **uninstall.sh** - 组件卸载工具
11. **migrate-config.sh** - 配置迁移工具
12. **offline-prepare.sh** - 离线安装包准备

## 测试计划

### 在 Linux Mint 22.3 上验证

#### 基础功能测试
```bash
# 1. 语法检查
bash -n *.sh

# 2. 模拟运行
./install.sh --dry-run
./install_devtools.sh --list
./doctor.sh --quiet

# 3. 实际安装（选择性）
./install_devtools.sh --python  # 最小依赖
./doctor.sh                     # 验证安装结果
```

#### 边界条件测试
```bash
# 1. 网络故障模拟
export https_proxy=http://127.0.0.1:9999  # 无效代理
./install_devtools.sh --node              # 应优雅失败并提示

# 2. 权限问题
unset SUDO_ASKPASS
./install.sh --no-fonts --no-config       # 不需要 sudo 的部分应成功

# 3. 重复安装
./install.sh                               # 第一次
./install.sh                               # 第二次，应跳过已有组件

# 4. 中断恢复
./install_devtools.sh --ai                 # Ctrl+C 中断
./doctor.sh                                # 检查状态
./install_devtools.sh --ai                 # 继续完成
```

## 风险评估

### 低风险修改
- 添加新函数（不改动现有逻辑）
- 增强错误提示
- 添加检测功能

### 中风险修改
- 修改下载逻辑（可能影响已有流程）
- 调整包名映射（可能在某些发行版上失败）

### 高风险修改
- 修改核心安装流程
- 改变幂等性逻辑

**策略**: 先实现低风险修改，验证通过后再进行中/高风险修改

## 验证标准

每项修改必须满足：

1. ✅ bash -n 语法检查通过
2. ✅ shellcheck 无新增警告
3. ✅ --dry-run 模式正常运行
4. ✅ 实际安装至少一个组件成功
5. ✅ 重复运行幂等（不报错，不重复安装）
6. ✅ doctor.sh 能正确识别安装状态
7. ✅ 中英文 README 已更新（如有 API 变化）

## 实施顺序

**立即执行**:
1. 运行 doctor.sh 收集当前环境完整信息
2. 备份当前配置文件（~/.zshrc, ~/.claude.json 等）

**第一批修改（今天完成）**:
1. lib_github.sh 增加下载重试
2. 所有 install 脚本添加前置检查
3. doctor.sh 增加系统兼容性检测

**第二批修改（按需）**:
4. Mint 特有处理
5. 日志格式统一
6. 进度显示

**第三批增强（可选）**:
7. 卸载脚本
8. 配置迁移
9. 性能优化

## 成功指标

优化完成后，应达到：

- ✅ 在 Linux Mint 22.3 上全部脚本零错误运行
- ✅ 网络故障能优雅降级并提示用户
- ✅ doctor.sh 能发现 90% 以上的环境问题
- ✅ 所有安装操作都有明确的成功/失败反馈
- ✅ 文档中有 Mint 特定的已知问题说明
