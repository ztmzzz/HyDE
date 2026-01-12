# install.sh 执行流程与全仓文件作用说明

基准版本：`fefc7fad`  |  生成时间：`2026-01-07 00:36:56`

## 1. install.sh 总览
install.sh 是 HyDE 的主安装入口，负责 **安装依赖、恢复配置、主题导入、服务启用与重启提示**。默认无参等价于 `-i -r -s`。

### 1.1 参数与行为
| 参数 | 含义 | 影响 |
| --- | --- | --- |
| `-i` | 安装依赖包 | 执行 `install_pkg.sh` 安装软件 |
| `-d` | 安装默认包并自动确认 | 传入 `--noconfirm` 给 pacman |
| `-r` | 恢复配置 | 执行字体、配置、主题恢复流程 |
| `-s` | 启用服务 | 执行 `restore_svc.sh` |
| `-n` | 跳过 NVIDIA 相关动作 | 默认关闭 NVIDIA 相关动作 |
| `-N` | 启用 NVIDIA 相关动作 | 允许添加驱动与引导参数 |
| `-h` | 重新评估 shell | 设置 `flg_Shell=1` 供后续脚本使用 |
| `-m` | 跳过主题导入 | 不执行主题导入 |
| `-t` | 试运行 | 仅输出不执行系统写入 |

### 1.2 主流程图
```mermaid
flowchart TD
    A[启动 install.sh] --> B{解析参数}
    B -->|无参数| C[默认 -i -r -s]
    B --> D[设置 flags/日志]
    C --> D
    D --> E{Install && Restore?}
    E -->|是| F[install_pre.sh: 引导器/Pacman/Chaotic AUR]
    E -->|否| G
    F --> G{安装依赖? (-i)}
    G -->|是| H[准备 install_pkg.lst + 用户包 + NVIDIA 驱动]
    H --> I[选择 AUR helper 与 Shell]
    I --> J[install_pkg.sh 安装 Arch/AUR 包]
    G -->|否| K
    J --> K{恢复配置? (-r)}
    K -->|是| L[restore_fnt.sh 解压字体/主题]
    L --> M[restore_cfg.sh 备份并恢复配置]
    M --> N[restore_thm.sh 导入主题]
    N --> O[生成缓存/切换主题/更新 Waybar]
    K -->|否| P
    O --> P{Install && Restore?}
    P -->|是| Q[install_pst.sh SDDM/文件管理器/Flatpak/Shell]
    P -->|否| R
    Q --> R{Restore? (-r)}
    R -->|是| S[执行最新迁移脚本]
    R -->|否| T
    S --> T{启用服务? (-s)}
    T -->|是| U[restore_svc.sh 启用服务]
    T -->|否| V
    U --> V[提示重启]
```

### 1.3 关键子脚本调用链
| 阶段 | 脚本 | 作用 |
| --- | --- | --- |
| 预安装 | `Scripts/install_pre.sh` | 配置引导器、pacman、可选 Chaotic AUR |
| 安装包 | `Scripts/install_pkg.sh` | 解析清单并安装 Arch/AUR 包 |
| AUR helper | `Scripts/install_aur.sh` | 使用 pacman 安装所选 AUR helper（paru/paru-bin 需 Chaotic AUR） |
| 恢复字体 | `Scripts/restore_fnt.sh` | 解压字体/主题资源并 `fc-cache` |
| 恢复配置 | `Scripts/restore_cfg.sh` | 备份并同步 `Configs/` 到用户目录 |
| 导入主题 | `Scripts/restore_thm.sh` | 读取 `themepatcher.lst` 批量导入主题 |
| 后置配置 | `Scripts/install_pst.sh` | SDDM 主题、默认文件管理器、Flatpak、Shell |
| 迁移 | `Scripts/migrations/*.sh` | 迁移提示/兼容处理 |
| 服务 | `Scripts/restore_svc.sh` | systemd enable/enable --now |

## 2. install.sh 具体执行流程（详细）
1) **初始化与参数解析**：读取 `global_fn.sh`，设置 `flg_Install/flg_Restore/flg_Service/flg_DryRun/...`，无参时默认执行安装+恢复+服务。
2) **预安装阶段（install_pre.sh）**：若同时执行安装与恢复则进入：
   - GRUB：备份 `/etc/default/grub` 和 `/boot/grub/grub.cfg`；检测 NVIDIA 时可写入 `nvidia_drm.modeset=1`；可选安装 GRUB 主题（`Grub_*.tar.gz`）；执行 `grub-mkconfig`。
   - systemd-boot：检测 NVIDIA 并修改 `/boot/loader/entries/*.conf` 的 `options` 行。
   - pacman：备份 `/etc/pacman.conf`，开启 Color/ILoveCandy/VerbosePkgLists/ParallelDownloads，启用 multilib，执行 `pacman -Syyu` 和 `pacman -Fy`。
   - Chaotic AUR：可选安装（执行 `chaotic_aur.sh --install`，写入 pacman 源并导入 keyring）。
3) **安装阶段**：
   - 生成 `install_pkg.lst`：由 `pkg_core.lst` + 自定义包列表 +（可选）NVIDIA 驱动/内核头文件构成。
   - 选择 AUR helper（yay/paru 或其 -bin 版本）与默认 shell（zsh/fish）；AUR helper 使用 pacman 安装，`paru/paru-bin` 需要 Chaotic AUR。
   - 执行 `install_pkg.sh`：区分 Arch repo 与 AUR 包；已安装则跳过；`-t` 仅输出。
4) **恢复阶段**：
   - `restore_fnt.sh` 解压 `Source/arcs/*.tar.gz` 到字体/主题/图标目录，并 `fc-cache -f`；若检测到 NixOS（`/run/current-system`），跳过写入 `/usr*` 目录。
   - `restore_cfg.sh` 依据 `restore_cfg.psv` 创建 `~/.config/cfg_backups/<时间戳>` 并覆盖/同步配置；执行 `hyde-shell pyinit`；缓存版本信息。
   - `restore_thm.sh` 根据 `themepatcher.lst` 导入主题（可异步），并提醒缓存壁纸。
   - 若在 Hyprland 会话中，先 `hyprctl keyword misc:disable_autoreload 1`；随后运行 `swwwallcache.sh`、`theme.switch.sh`、`waybar.py --update`。
5) **后置配置**（install_pst.sh，需 install+restore 同时开启）：
   - SDDM：解压 SDDM 主题包并写入 `/etc/sddm.conf.d/`，可设置用户头像。
   - 默认文件管理器：设置 Nautilus 为目录默认处理器。
   - Shell：调用 `restore_shl.sh` 安装 oh-my-zsh/插件并设置默认 shell（插件来源见 `restore_zsh.lst`）。
   - Flatpak：按 `custom_flat.lst` 可选安装并设置主题/图标覆盖。
6) **迁移脚本**：若存在 `Scripts/migrations`，执行最新版本脚本。
7) **服务启用**：执行 `restore_svc.sh`，按 `restore_svc.lst` 启用 NetworkManager、bluetooth、sddm。
8) **重启提示**：若检测到配置缺失或完成安装，询问是否 `systemctl reboot`。

### 2.1 安装清单解析逻辑
- `install_pkg.sh` 会将 `install_pkg.lst` 中 `pkg|deps` 的包视为**条件包**：仅当 `deps` 中所有依赖已安装时才加入队列。
- 同包已安装会被跳过；Arch repo 包通过 `pacman -Si` 判断，AUR 包通过 `pm.sh` 判断。
- 若存在 `Scripts/pkg_black.lst`（当前仓库未包含），会先过滤黑名单。

### 2.2 restore_cfg.psv 控制标记
| 标记 | 行为 |
| --- | --- |
| `P` | Populate/Preserve：仅在目标不存在时复制，尽量保留用户已有配置 |
| `S` | Sync：覆盖目标文件，并同步为仓库版本 |
| `O` | Overwrite：移动旧配置到备份后强制覆盖 |
| `B` | Backup：仅备份目标到 `cfg_backups` |
| `T` | Trash：将目标移动到备份目录（清理旧文件） |
| `I` | Ignore：跳过该条目 |

### 2.3 日志/缓存/备份路径
| 类型 | 路径 |
| --- | --- |
| 安装日志 | `~/.cache/hyde/logs/<HYDE_LOG>/` |
| 配置备份 | `~/.config/cfg_backups/<时间戳>` |
| 主题缓存 | `~/.cache/hyde/themepatcher/` |
| 版本缓存 | `~/.local/state/hyde/version` |
| 变更记录缓存 | `~/.local/state/hyde/CHANGELOG.md` |

## 3. 系统层面操作与影响（表）
| 操作点 | 具体改动 | 触发条件 |
| --- | --- | --- |
| 引导器 GRUB | 备份并修改 `/etc/default/grub`、`/boot/grub/grub.cfg`，可写入 `nvidia_drm.modeset=1`；安装 GRUB 主题到 `/usr/share/grub/themes` | `install_pre.sh`，检测到 GRUB 且启用 NVIDIA |
| 引导器 systemd-boot | 备份并修改 `/boot/loader/entries/*.conf` | `install_pre.sh`，检测到 systemd-boot 且启用 NVIDIA |
| pacman 配置 | 备份 `/etc/pacman.conf`，开启 Color/ILoveCandy/VerbosePkgLists/ParallelDownloads，启用 multilib，执行 `pacman -Syyu`、`pacman -Fy` | `install_pre.sh` |
| Chaotic AUR | 导入 keyring/mirrorlist，写入 pacman 源 | `install_pre.sh` 中用户确认 |
| AUR helper | `pacman -S <helper>`（例如 `paru`/`paru-bin`/`yay-bin`）；`paru/paru-bin` 依赖 Chaotic AUR | 安装阶段且系统无 yay/paru |
| 软件包安装 | `pacman -S` 与 AUR helper 安装清单内包 | 安装阶段 |
| 字体/主题解压 | 解压到 `~/.local/share/{fonts,themes,icons}` 与 `/usr/local/share/*`，执行 `fc-cache -f` | 恢复阶段 |
| 配置恢复 | 备份到 `~/.config/cfg_backups/<时间戳>`，覆盖/同步到 `~/.config`、`~/.local/share`、`~/.local/lib` | 恢复阶段 |
| 主题导入 | 克隆主题仓库到 `~/.cache/hyde/themepatcher/*` 并导入 | 恢复阶段且未 `-m` |
| SDDM 配置 | 解压主题到 `/usr/share/sddm/themes`，写入 `/etc/sddm.conf.d/` | 后置阶段 |
| Shell 变更 | 安装 oh-my-zsh/插件并 `chsh` 切换默认 shell | 后置阶段 |
| Flatpak | 安装 flatpak、添加 flathub、安装应用并设置主题覆盖 | 后置阶段用户确认 |
| systemd 服务 | `systemctl enable`/`enable --now` | 服务阶段 |
| 重启 | `systemctl reboot` | 用户确认 |

## 4. 安装的软件清单与用途
### 4.1 核心包（pkg_core.lst）
| 分类 | 包名 | 条件依赖 | 作用 |
| --- | --- | --- | --- |
| System | `uwsm` | - | A standalone Wayland session manager |
| System | `pipewire` | - | audio/video server |
| System | `pipewire-alsa` | - | pipewire alsa client |
| System | `pipewire-audio` | - | pipewire audio client |
| System | `pipewire-jack` | - | pipewire jack client |
| System | `pipewire-pulse` | - | pipewire pulseaudio client |
| System | `gst-plugin-pipewire` | - | pipewire gstreamer client |
| System | `wireplumber` | - | pipewire session manager |
| System | `pavucontrol` | - | pulseaudio volume control |
| System | `pamixer` | - | pulseaudio cli mixer |
| System | `networkmanager` | - | network manager |
| System | `network-manager-applet` | - | network manager system tray utility |
| System | `bluez` | - | bluetooth protocol stack |
| System | `bluez-utils` | - | bluetooth utility cli |
| System | `blueman` | - | bluetooth manager gui |
| System | `brightnessctl` | - | screen brightness control |
| System | `playerctl` | - | media controls |
| System | `udiskie` | - | manage removable media |
| Display Manager | `sddm` | - | display manager for KDE plasma |
| Display Manager | `qt5-quickcontrols` | - | for sddm theme ui elements |
| Display Manager | `qt5-quickcontrols2` | - | for sddm theme ui elements |
| Display Manager | `qt5-graphicaleffects` | - | for sddm theme effects |
| Window Manager | `hyprland` | - | wlroots-based wayland compositor |
| Window Manager | `dunst` | - | notification daemon |
| Window Manager | `rofi` | - | application launcher |
| Window Manager | `waybar` | - | system bar |
| Window Manager | `swww` | - | wallpaper |
| Window Manager | `hyprlock` | - | lock screen |
| Window Manager | `wlogout` | - | logout menu |
| Window Manager | `grim` | - | screenshot tool |
| Window Manager | `hyprpicker` | - | color picker |
| Window Manager | `slurp` | - | region select for screenshot/screenshare |
| Window Manager | `satty` | - | Modern Screenshot Annotation |
| Window Manager | `cliphist` | - | clipboard manager |
| Window Manager | `wl-clip-persist` | - | Keep Wayland clipboard even after programs close (avoids crashes) |
| Window Manager | `hyprsunset` | - | blue light filter |
| Dependencies | `polkit-gnome` | - | authentication agent |
| Dependencies | `xdg-desktop-portal-hyprland` | - | xdg desktop portal for hyprland |
| Dependencies | `xdg-desktop-portal-gtk` | - | file picker and dbus  integration |
| Dependencies | `xdg-user-dirs` | - | Manage user directories like ~/Desktop and ~/Music |
| Dependencies | `pacman-contrib` | - | for system update check |
| Dependencies | `parallel` | - | for parallel processing |
| Dependencies | `jq` | - | for json processing |
| Dependencies | `imagemagick` | - | for image processing |
| Dependencies | `libnotify` | - | for notifications |
| Dependencies | `noto-fonts-emoji` | - | emoji font |
| Dependencies | `noto-fonts-cjk` | - | CJK font family |
| Theming | `nwg-look` | - | gtk configuration tool |
| Theming | `qt5ct` | - | qt5 configuration tool |
| Theming | `qt6ct` | - | qt6 configuration tool |
| Theming | `kvantum` | - | svg based qt6 theme engine |
| Theming | `kvantum-qt5` | - | svg based qt5 theme engine |
| Theming | `qt5-wayland` | - | wayland support in qt5 |
| Theming | `qt6-wayland` | - | wayland support in qt6 |
| Applications | `firefox` | - | browser |
| Applications | `kitty` | - | terminal |
| Applications | `nautilus` | - | gnome file manager |
| Applications | `file-roller` | - | gnome archive manager |
| Applications | `unzip` | - | extracting zip files |
| Applications | `vim` | - | terminal text editor |
| Applications | `code` | - | ide text editor |
| Applications | `nwg-displays` | - | monitor management utility |
| Applications | `fzf` | - | Command-line fuzzy finder |
| Shell | `starship` | zsh | customizable shell prompt written in Rust |
| Shell | `starship` | fish | customizable shell prompt |
| Shell | `fastfetch` | - | system information fetch tool |
| HyDE | `hypridle` | - | idle daemon |

### 4.2 可选包（pkg_extra.lst）
| 分类 | 包名 | 条件依赖 | 作用 |
| --- | --- | --- | --- |
| System | `wttrbar` | - | for weather |
| System | `python-requests` | wttrbar | script dependency |
| System | `ddcui` | - | GUI to control brightness for external monitors |
| Misc | `xdg-desktop-portal-gtk` | - | xdg desktop portal using gtk |
| Misc | `wf-recorder` | - | Screen recorder for wlroots-based compositors such as sway |
| Gaming | `steam` | - | gaming platform |
| Gaming | `gamemode` | - | daemon and library for game optimizations |
| Gaming | `mangohud` | - | system performance overlay |
| Music | `cava` | - | audio visualizer |
| Music | `spotify` | - | proprietary music streaming service |
| Music | `spicetify-cli` | - | cli to customize spotify client |
| zsh | `bat` | zsh | enhanced version of cat |
| zsh | `eza` | zsh | file lister for zsh |
| zsh | `duf` | zsh | prettier version of df for zsh |
| fish | `bat` | fish | enhanced version of cat |
| fish | `eza` | fish | file lister |
| fish | `duf` | fish | prettier version of df |
| OSD | `swayosd-git` | - | A GTK based on screen display for keyboard shortcuts like caps-lock and volume |

### 4.3 Flatpak 清单（custom_flat.lst）
| 分类 | Flatpak ID | 作用 |
| --- | --- | --- |
| System | `com.github.tchx84.Flatseal` | Flatseal |
| System | `io.github.flattool.Warehouse` | Warehouse |
| System | `org.gnome.Boxes` | Boxes |
| System | `io.missioncenter.MissionCenter` | MissionCenter |
| System | `io.gitlab.adhami3310.Impression` | Impression |
| Social | `io.github.spacingbat3.webcord` | Webcord |
| Image/Graphics | `org.inkscape.Inkscape` | Inkscape |
| Image/Graphics | `org.kde.krita` | Krita |
| Image/Graphics | `org.gimp.GIMP` | Gimp |
| Image/Graphics | `org.blender.Blender` | Blender |
| Image/Graphics | `io.gitlab.theevilskeleton.Upscaler` | ImageUpscaler |
| Photography | `org.gnome.eog` | ImageViewer |
| Audio/Video | `com.obsproject.Studio` | Obs |
| Audio/Video | `com.github.rafostar.Clapper` | Clapper |
| Audio/Video | `com.github.unrud.VideoDownloader` | VideoDownloader |

### 4.4 字体/主题归档解压清单（restore_fnt.lst）
| 归档名 | 目标路径 |
| --- | --- |
| `Font_CascadiaCove` | `$HOME/.local/share/fonts` |
| `Font_MaterialDesign` | `$HOME/.local/share/fonts` |
| `Font_JetBrainsMono` | `$HOME/.local/share/fonts` |
| `Font_MapleNerd` | `$HOME/.local/share/fonts` |
| `Font_MononokiNerd` | `$HOME/.local/share/fonts` |
| `Font_NotoSansCJK` | `$HOME/.local/share/fonts` |
| `Font_NotoSansCJK` | `/usr/local/share/fonts` |
| `Cursor_BibataIce` | `/usr/local/share/icons` |
| `Cursor_BibataIce` | `$HOME/.local/share/icons` |
| `Gtk_Wallbash` | `$HOME/.local/share/themes` |
| `Icon_Wallbash` | `$HOME/.local/share/icons` |

### 4.5 主题导入清单（themepatcher.lst）
| 主题名 | 仓库地址 |
| --- | --- |
| Catppuccin Mocha | https://github.com/HyDE-Project/hyde-themes/tree/Catppuccin-Mocha |
| Catppuccin Latte | https://github.com/HyDE-Project/hyde-themes/tree/Catppuccin-Latte |
| Rosé Pine | https://github.com/HyDE-Project/hyde-themes/tree/Rose-Pine |
| Tokyo Night | https://github.com/HyDE-Project/hyde-themes/tree/Tokyo-Night |
| Material Sakura | https://github.com/HyDE-Project/hyde-themes/tree/Material-Sakura |
| Graphite Mono | https://github.com/HyDE-Project/hyde-themes/tree/Graphite-Mono |
| Decay Green | https://github.com/HyDE-Project/hyde-themes/tree/Decay-Green |
| Edge Runner | https://github.com/HyDE-Project/hyde-themes/tree/Edge-Runner |
| Frosted Glass | https://github.com/HyDE-Project/hyde-themes/tree/Frosted-Glass |
| Gruvbox Retro | https://github.com/HyDE-Project/hyde-themes/tree/Gruvbox-Retro |
| Synth Wave | https://github.com/HyDE-Project/hyde-themes/tree/Synth-Wave |
| Nordic Blue | https://github.com/HyDE-Project/hyde-themes/tree/Nordic-Blue |

### 4.6 systemd 服务清单（restore_svc.lst）
| 服务 | 上下文 | 命令 |
| --- | --- | --- |
| `NetworkManager` | `root` | `enable --now` |
| `bluetooth` | `root` | `enable --now` |
| `sddm` | `root` | `enable` |

## 5. 迁移脚本（Scripts/migrations）
| 脚本 | 作用 |
| --- | --- |
| `Scripts/migrations/v25.8.2.sh` | 检测 uwsm，提示安装并可重载 shaders |
| `Scripts/migrations/v25.9.1.sh` | 提示 rofi 包更替（rofi-wayland -> rofi） |

## 6. 全仓文件清单与作用
说明：以下为仓库内 **全部文件** 的用途汇总（按路径排序，类型通过路径规则归类）。

| 文件路径 | 作用 |
| --- | --- |
| `.all-contributorsrc` | 项目文件 |
| `.directory` | 项目文件 |
| `.github/FUNDING.yml` | 项目文件 |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | 项目文件 |
| `.github/ISSUE_TEMPLATE/custom.yml` | 项目文件 |
| `.github/ISSUE_TEMPLATE/documentation_update.yml` | 项目文件 |
| `.github/ISSUE_TEMPLATE/feature_request.yml` | 项目文件 |
| `.github/PULL_REQUEST_TEMPLATE.md` | 项目文件 |
| `.github/scripts/promote_to_master.sh` | 项目文件 |
| `.github/scripts/promote_to_rc.sh` | 项目文件 |
| `.github/scripts/remind-release.py` | 项目文件 |
| `.github/workflows/ci.yml` | 项目文件 |
| `.github/workflows/lock.yml` | 项目文件 |
| `.github/workflows/refresh-release.yml` | 项目文件 |
| `.github/workflows/warn-master-pr.yml` | 项目文件 |
| `.gitignore` | 项目文件 |
| `AGENTS.md` | 仓库协作/贡献指南（由工具生成） |
| `CHANGELOG.md` | 变更记录（用户可见） |
| `COMMIT_MESSAGE_GUIDELINES.md` | 提交信息规范与示例 |
| `Configs/.config/baloofilerc` | HyDE 配置资源 |
| `Configs/.config/Code - OSS/User/settings.json` | VS Code/VSCodium 配置 |
| `Configs/.config/code-flags.conf` | HyDE 配置资源 |
| `Configs/.config/Code/User/settings.json` | VS Code/VSCodium 配置 |
| `Configs/.config/codium-flags.conf` | HyDE 配置资源 |
| `Configs/.config/dolphinrc` | HyDE 配置资源 |
| `Configs/.config/dunst/dunst.conf` | Dunst 通知配置 |
| `Configs/.config/dunst/dunstrc` | Dunst 通知配置 |
| `Configs/.config/electron-flags.conf` | HyDE 配置资源 |
| `Configs/.config/fastfetch/config.jsonc` | Fastfetch 配置/Logo |
| `Configs/.config/fastfetch/logo/agk_clan.icon` | Fastfetch 配置/Logo |
| `Configs/.config/fastfetch/logo/aisaka.icon` | Fastfetch 配置/Logo |
| `Configs/.config/fastfetch/logo/geass.icon` | Fastfetch 配置/Logo |
| `Configs/.config/fastfetch/logo/hyprland.icon` | Fastfetch 配置/Logo |
| `Configs/.config/fastfetch/logo/loli.icon` | Fastfetch 配置/Logo |
| `Configs/.config/fastfetch/logo/pochita.icon` | Fastfetch 配置/Logo |
| `Configs/.config/fastfetch/logo/ryuzaki.icon` | Fastfetch 配置/Logo |
| `Configs/.config/fish/completions/hyde-shell.fish` | Fish shell 配置/函数 |
| `Configs/.config/fish/conf.d/hyde.fish` | Fish shell 配置/函数 |
| `Configs/.config/fish/config.fish` | Fish shell 配置/函数 |
| `Configs/.config/fish/functions/bind_M_n_history.fish` | Fish shell 配置/函数 |
| `Configs/.config/fish/functions/fzf/ffcd.fish` | Fish shell 配置/函数 |
| `Configs/.config/fish/functions/fzf/ffch.fish` | Fish shell 配置/函数 |
| `Configs/.config/fish/functions/fzf/ffe.fish` | Fish shell 配置/函数 |
| `Configs/.config/fish/functions/fzf/ffec.fish` | Fish shell 配置/函数 |
| `Configs/.config/fish/user.fish` | Fish shell 配置/函数 |
| `Configs/.config/gtk-3.0/settings.ini` | HyDE 配置资源 |
| `Configs/.config/hyde/config.toml` | HyDE 配置资源 |
| `Configs/.config/hyde/wallbash/always/cava.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/always/chrome.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/always/discord.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/always/spotify.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/always/vim.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/README.md` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/scripts/cava.sh` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/scripts/chrome.sh` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/scripts/code.sh` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/scripts/discord.sh` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/scripts/spotify.sh` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hyde/wallbash/theme/code.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.config/hypr/animations.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/animations/classic.conf` | Hyprland 动画预设: classic |
| `Configs/.config/hypr/animations/diablo-1.conf` | Hyprland 动画预设: diablo-1 |
| `Configs/.config/hypr/animations/diablo-2.conf` | Hyprland 动画预设: diablo-2 |
| `Configs/.config/hypr/animations/disable.conf` | Hyprland 动画预设: disable |
| `Configs/.config/hypr/animations/dynamic.conf` | Hyprland 动画预设: dynamic |
| `Configs/.config/hypr/animations/end4.conf` | Hyprland 动画预设: end4 |
| `Configs/.config/hypr/animations/fast.conf` | Hyprland 动画预设: fast |
| `Configs/.config/hypr/animations/high.conf` | Hyprland 动画预设: high |
| `Configs/.config/hypr/animations/ja.conf` | Hyprland 动画预设: ja |
| `Configs/.config/hypr/animations/LimeFrenzy.conf` | Hyprland 动画预设: LimeFrenzy |
| `Configs/.config/hypr/animations/me-1.conf` | Hyprland 动画预设: me-1 |
| `Configs/.config/hypr/animations/me-2.conf` | Hyprland 动画预设: me-2 |
| `Configs/.config/hypr/animations/minimal-1.conf` | Hyprland 动画预设: minimal-1 |
| `Configs/.config/hypr/animations/minimal-2.conf` | Hyprland 动画预设: minimal-2 |
| `Configs/.config/hypr/animations/moving.conf` | Hyprland 动画预设: moving |
| `Configs/.config/hypr/animations/optimized.conf` | Hyprland 动画预设: optimized |
| `Configs/.config/hypr/animations/standard.conf` | Hyprland 动画预设: standard |
| `Configs/.config/hypr/animations/theme.conf` | Hyprland 动画预设: theme |
| `Configs/.config/hypr/animations/vertical.conf` | Hyprland 动画预设: vertical |
| `Configs/.config/hypr/hypridle.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/hyprland.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/hyprlock.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/hyprlock/Anurati.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/hyprlock/Arfan on Clouds.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/hyprlock/greetd-wallbash.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/hyprlock/greetd.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/hyprlock/HyDE.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/hyprlock/IBM Plex.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/hyprlock/IMB Xtented.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/hyprlock/SF Pro.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/hyprlock/theme.conf` | Hyprlock 主题/配置 |
| `Configs/.config/hypr/keybindings.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/monitors.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/nvidia.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/pyprland.toml` | Hyprland 配置文件 |
| `Configs/.config/hypr/shaders.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/shaders/.compiled.cache.glsl` | Hyprland 配置文件 |
| `Configs/.config/hypr/shaders/.gitignore` | Hyprland 配置文件 |
| `Configs/.config/hypr/shaders/blue-light-filter.frag` | Hyprland 着色器: blue-light-filter |
| `Configs/.config/hypr/shaders/color-vision.frag` | Hyprland 着色器: color-vision |
| `Configs/.config/hypr/shaders/custom.frag` | Hyprland 着色器: custom |
| `Configs/.config/hypr/shaders/disable.frag` | Hyprland 着色器: disable |
| `Configs/.config/hypr/shaders/grayscale.frag` | Hyprland 着色器: grayscale |
| `Configs/.config/hypr/shaders/invert-colors.frag` | Hyprland 着色器: invert-colors |
| `Configs/.config/hypr/shaders/oled-saver.frag` | Hyprland 着色器: oled-saver |
| `Configs/.config/hypr/shaders/paper.frag` | Hyprland 着色器: paper |
| `Configs/.config/hypr/shaders/vibrance.frag` | Hyprland 着色器: vibrance |
| `Configs/.config/hypr/shaders/wallbash.frag` | Hyprland 着色器: wallbash |
| `Configs/.config/hypr/shaders/wallbash.inc` | Hyprland 配置文件 |
| `Configs/.config/hypr/themes/colors.conf` | Hyprland 主题配置 |
| `Configs/.config/hypr/themes/theme.conf` | Hyprland 主题配置 |
| `Configs/.config/hypr/themes/wallbash.conf` | Hyprland 主题配置 |
| `Configs/.config/hypr/userprefs.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/windowrules.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/workflows.conf` | Hyprland 配置文件 |
| `Configs/.config/hypr/workflows/.gitignore` | Hyprland 配置文件 |
| `Configs/.config/hypr/workflows/default.conf` | Hyprland 工作流预设: default |
| `Configs/.config/hypr/workflows/editing.conf` | Hyprland 工作流预设: editing |
| `Configs/.config/hypr/workflows/gaming.conf` | Hyprland 工作流预设: gaming |
| `Configs/.config/hypr/workflows/powersaver.conf` | Hyprland 工作流预设: powersaver |
| `Configs/.config/hypr/workflows/snappy.conf` | Hyprland 工作流预设: snappy |
| `Configs/.config/kdeglobals` | HyDE 配置资源 |
| `Configs/.config/kitty/hyde.conf` | Kitty 终端配置 |
| `Configs/.config/kitty/kitty.conf` | Kitty 终端配置 |
| `Configs/.config/kitty/theme.conf` | Kitty 终端配置 |
| `Configs/.config/Kvantum/kvantum.kvconfig` | Kvantum 主题配置 |
| `Configs/.config/Kvantum/wallbash/wallbash.kvconfig` | Kvantum 主题配置 |
| `Configs/.config/Kvantum/wallbash/wallbash.svg` | Kvantum 主题配置 |
| `Configs/.config/libinput-gestures.conf` | libinput-gestures 配置 |
| `Configs/.config/lsd/colors.yaml` | lsd 终端列表工具配置 |
| `Configs/.config/lsd/config.yaml` | lsd 终端列表工具配置 |
| `Configs/.config/lsd/icons.yaml` | lsd 终端列表工具配置 |
| `Configs/.config/MangoHud/MangoHud.conf` | HyDE 配置资源 |
| `Configs/.config/menus/applications.menu` | HyDE 配置资源 |
| `Configs/.config/nwg-look/config` | HyDE 配置资源 |
| `Configs/.config/qt5ct/colors/wallbash.conf` | Qt 主题配置 |
| `Configs/.config/qt5ct/qt5ct.conf` | Qt 主题配置 |
| `Configs/.config/qt6ct/colors/wallbash.conf` | Qt 主题配置 |
| `Configs/.config/qt6ct/qt6ct.conf` | Qt 主题配置 |
| `Configs/.config/rofi/theme.rasi` | Rofi 配置 |
| `Configs/.config/satty/config.toml` | HyDE 配置资源 |
| `Configs/.config/spotify-flags.conf` | HyDE 配置资源 |
| `Configs/.config/starship/powerline.toml` | HyDE 配置资源 |
| `Configs/.config/starship/starship.toml` | HyDE 配置资源 |
| `Configs/.config/swaylock/config` | Swaylock 配置 |
| `Configs/.config/swaync/config.json` | SwayNC 通知中心配置 |
| `Configs/.config/swaync/style.css` | SwayNC 通知中心配置 |
| `Configs/.config/swaync/user-style.css` | SwayNC 通知中心配置 |
| `Configs/.config/systemd/user/hyde-config.service` | systemd 用户服务 |
| `Configs/.config/systemd/user/hyde-ipc.service` | systemd 用户服务 |
| `Configs/.config/uwsm/env` | UWSM 环境变量与启动配置 |
| `Configs/.config/uwsm/env-hyprland` | UWSM 环境变量与启动配置 |
| `Configs/.config/uwsm/env-hyprland.d/00-hyde.sh` | UWSM 环境变量与启动配置 |
| `Configs/.config/uwsm/env.d/00-hyde.sh` | UWSM 环境变量与启动配置 |
| `Configs/.config/uwsm/env.d/01-gpu.sh` | UWSM 环境变量与启动配置 |
| `Configs/.config/vim/colors/wallbash.vim` | Vim 配置/配色 |
| `Configs/.config/vim/hyde.vim` | Vim 配置/配色 |
| `Configs/.config/vim/vimrc` | Vim 配置/配色 |
| `Configs/.config/VSCodium/User/settings.json` | VS Code/VSCodium 配置 |
| `Configs/.config/waybar/config.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/includes/border-radius.css` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/includes/global.css` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/includes/includes.json` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/includes/README.txt` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/layouts/README.txt` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/menus/README.txt` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/backlight.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/battery.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/bluetooth.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/cava.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/cliphist.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/clock##alt.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/clock.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/cpu.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/cpuinfo.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/display.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/footer.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/github_hyde.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/github_hyprdots.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/gpuinfo.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/header.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/hyprsunset.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/idle_inhibitor.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/keybindhint.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/language.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/memory.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/mpris.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/network.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/notifications.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/power.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/privacy.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/pulseaudio#microphone.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/pulseaudio.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/README.txt` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/sensorsinfo.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/spotify.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/style.css` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/taskbar##custom.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/taskbar##windows.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/taskbar.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/theme.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/tray.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/updates.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/wallchange.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/wbar.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/weather.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/window.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/workspaces##kanji.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/workspaces##roman.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/modules/workspaces.jsonc` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/style.css` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/styles/README.txt` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/theme.css` | Waybar 配置/样式/模块 |
| `Configs/.config/waybar/user-style.css` | Waybar 配置/样式/模块 |
| `Configs/.config/wlogout/icons/hibernate_black.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/hibernate_white.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/lock_black.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/lock_white.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/logout_black.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/logout_white.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/reboot_black.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/reboot_white.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/shutdown_black.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/shutdown_white.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/suspend_black.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/icons/suspend_white.png` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/layout_1` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/layout_2` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/style_1.css` | Wlogout 配置与图标 |
| `Configs/.config/wlogout/style_2.css` | Wlogout 配置与图标 |
| `Configs/.config/xdg-terminals.list` | HyDE 配置资源 |
| `Configs/.config/xsettingsd/xsettingsd.conf` | HyDE 配置资源 |
| `Configs/.config/zsh/.p10k.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/.zshenv` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/.zshrc` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/completions/fzf.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/completions/hyde-shell.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/completions/hydectl.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/conf.d/00-hyde.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/conf.d/binds.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/conf.d/hyde/env.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/conf.d/hyde/prompt.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/conf.d/hyde/terminal.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/functions/bat.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/functions/bind_M_n_history.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/functions/duf.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/functions/error-handlers.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/functions/eza.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/functions/fzf.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/functions/kb_help.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/plugin.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/prompt.zsh` | Zsh 配置/插件脚本 |
| `Configs/.config/zsh/user.zsh` | Zsh 配置/插件脚本 |
| `Configs/.gtkrc-2.0` | HyDE 配置资源 |
| `Configs/.local/bin/hyde-ipc` | HyDE 命令行入口脚本 |
| `Configs/.local/bin/hyde-shell` | HyDE 命令行入口脚本 |
| `Configs/.local/bin/hydectl` | HyDE 命令行入口脚本 |
| `Configs/.local/bin/hyq` | HyDE 命令行入口脚本 |
| `Configs/.local/lib/hyde/.editorconfig` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/amdgpu.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/animations.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/app2unit.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/battery.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/batterynotify.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/bookmarks.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/brightnesscontrol.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/calculator.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/cava.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/cliphist.image.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/cliphist.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/color.set.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/color/dconf.sh` | 主题颜色适配脚本 |
| `Configs/.local/lib/hyde/color/hypr.sh` | 主题颜色适配脚本 |
| `Configs/.local/lib/hyde/configuration.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/cpuinfo.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/dontkillsteam.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/emoji-picker.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/fastfetch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/font.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/fzf_preview.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/fzf_wrapper.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/gamelauncher.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/gamelauncher/catalog.py` | 游戏启动器适配 |
| `Configs/.local/lib/hyde/gamelauncher/lutris.py` | 游戏启动器适配 |
| `Configs/.local/lib/hyde/gamelauncher/steam.py` | 游戏启动器适配 |
| `Configs/.local/lib/hyde/gamemode.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/globalcontrol.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/glyph-picker.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/gpuinfo.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/grimblast` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/hyde-config` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/hyde-launch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/hypr.unbind.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/hyprlock.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/hyprsunset.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/hyq` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/idle-inhibitor.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/keybinds/hint-hyprland.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/keybinds_hint.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/keyboardswitch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/lockscreen.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/logoutlaunch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/mediaplayer.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/notifications.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/open.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/parse.config.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/parse.json.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/pm.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/pm.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/pm/apt.py` | 包管理适配器 |
| `Configs/.local/lib/hyde/pm/dnf.py` | 包管理适配器 |
| `Configs/.local/lib/hyde/pm/flatpak.py` | 包管理适配器 |
| `Configs/.local/lib/hyde/pm/pacman.py` | 包管理适配器 |
| `Configs/.local/lib/hyde/pm/paru.py` | 包管理适配器 |
| `Configs/.local/lib/hyde/pm/yay.py` | 包管理适配器 |
| `Configs/.local/lib/hyde/polkitkdeauth.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/pygui/color.shuffle.py` | HyDE GUI 辅助脚本 |
| `Configs/.local/lib/hyde/pyproject.toml` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/pyutils/compositor.py` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/pyutils/configuration.py` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/pyutils/logger.py` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/pyutils/pip_env.py` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/pyutils/requirements.txt` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/pyutils/wrapper/fzf.py` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/pyutils/wrapper/libnotify.py` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/pyutils/wrapper/rofi.py` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/pyutils/xdg_base_dirs.py` | HyDE Python 工具库 |
| `Configs/.local/lib/hyde/quickapps.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/README.txt` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/resetxdgportal.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/restore.config.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/rofi.bookmarks.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/rofi.websearch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/rofilaunch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/rofiselect.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/screenrecord.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/screenshot.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/screenshot/grimblast` | 截图工具封装 |
| `Configs/.local/lib/hyde/sensorsinfo.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/shaders.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/shutils/argparse.sh` | Shell 工具函数 |
| `Configs/.local/lib/hyde/shutils/ocr.sh` | Shell 工具函数 |
| `Configs/.local/lib/hyde/shutils/qr.sh` | Shell 工具函数 |
| `Configs/.local/lib/hyde/swwwallbash.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/swwwallcache.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/swwwallkon.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/swwwallpaper.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/swwwallselect.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/sysmonlaunch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/system.monitor.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/system.update.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/systemupdate.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/testrunner.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/theme.import.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/theme.patch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/theme.select.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/theme.switch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/themeselect.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/themeswitch.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/volumecontrol.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wallbash.print.colors.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wallbash.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wallbashtoggle.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wallpaper.hyprpaper.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wallpaper.mpvpaper.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wallpaper.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wallpaper.swww.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wallpaper/core.sh` | 壁纸子系统脚本 |
| `Configs/.local/lib/hyde/wallpaper/help.sh` | 壁纸子系统脚本 |
| `Configs/.local/lib/hyde/wallpaper/select.sh` | 壁纸子系统脚本 |
| `Configs/.local/lib/hyde/waybar.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wbarconfgen.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/wbarstylegen.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/weather.py` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/windowpin.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/workflows.sh` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/lib/hyde/xdg-terminal-exec` | HyDE 工具脚本/运行时组件 |
| `Configs/.local/share/dolphin/view_properties/global/.directory` | HyDE 配置资源 |
| `Configs/.local/share/fastfetch/presets/hyde/config.jsonc` | HyDE 配置资源 |
| `Configs/.local/share/fastfetch/presets/hyde/lierb.jsonc` | HyDE 配置资源 |
| `Configs/.local/share/fastfetch/presets/hyde/xero.jsonc` | HyDE 配置资源 |
| `Configs/.local/share/hyde/config-registry.toml` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/dunst.conf` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/emoji.db` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/env-theme` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/glyph.db` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/hyde.conf` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/hyprland.conf` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/hyprlock.conf` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/keybindings.conf` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/migration/hypr/0.52_windowrules.conf` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/rofi/assets/launchpad.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/notification.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/steamdeck_holographic.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_1.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_10.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_11.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_12.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_2.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_3.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_4.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_5.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_6.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_7.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_8.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/style_9.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/theme_style_1.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/theme_style_2.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/assets/wallbash_mode.png` | Rofi 主题预览资源 |
| `Configs/.local/share/hyde/rofi/themes/clipboard.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/gamelauncher_1.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/gamelauncher_2.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/gamelauncher_3.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/gamelauncher_4.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/gamelauncher_5.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/launchpad.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/notification.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/quickapps.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/selector.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/steam_deck.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_1.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_10.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_11.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_12.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_2.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_3.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_4.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_5.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_6.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_7.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_8.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/style_9.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/rofi/themes/wallbash.rasi` | Rofi 主题文件 |
| `Configs/.local/share/hyde/schema/config.md` | HyDE 配置 schema/生成器 |
| `Configs/.local/share/hyde/schema/config.toml` | HyDE 配置 schema/生成器 |
| `Configs/.local/share/hyde/schema/config.toml.json` | HyDE 配置 schema/生成器 |
| `Configs/.local/share/hyde/schema/gen-config.py` | HyDE 配置 schema/生成器 |
| `Configs/.local/share/hyde/schema/gen-json.py` | HyDE 配置 schema/生成器 |
| `Configs/.local/share/hyde/schema/gen-table.py` | HyDE 配置 schema/生成器 |
| `Configs/.local/share/hyde/schema/schema.toml` | HyDE 配置 schema/生成器 |
| `Configs/.local/share/hyde/templates/hypr/keybindings.conf` | HyDE 模板文件 |
| `Configs/.local/share/hyde/templates/hypr/windowrules.conf` | HyDE 模板文件 |
| `Configs/.local/share/hyde/theme-env` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/wallbash/scripts/swaync.sh` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/wallbash/theme/swaync.dcol` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hyde/websearch.lst` | HyDE 运行时资源/默认配置 |
| `Configs/.local/share/hypr/defaults.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/hypr/dynamic.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/hypr/env.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/hypr/finale.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/hypr/hyprland.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/hypr/migration.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/hypr/startup.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/hypr/variables.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/hypr/windowrules.conf` | Hyprland 默认/迁移配置 |
| `Configs/.local/share/icons/default/index.theme` | HyDE 配置资源 |
| `Configs/.local/share/kio/servicemenus/hydewallpaper.desktop` | HyDE 配置资源 |
| `Configs/.local/share/kxmlgui5/dolphin/dolphinui.rc` | HyDE 配置资源 |
| `Configs/.local/share/wallbash/always/00-icons/hyprdots.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/muted-mic.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/muted-speaker.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/unmuted-mic.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/unmuted-speaker.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-0.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-10.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-100.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-15.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-20.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-25.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-30.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-35.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-40.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-45.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-5.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-50.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-55.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-60.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-65.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-70.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-75.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-80.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-85.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-90.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-icons/vol-95.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-palette/palette_v2.t2` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/00-palette/palette_v3.t2` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/dunst.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/gtk-css.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/hyprcolors.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/hyprlock_background.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/hyprshaders.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/pywal-colors.Xcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/qtct.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/rasi.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/scss.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/always/shell-colors.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/scripts/dunst.sh` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/scripts/kitty.sh` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/scripts/qtct.sh` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/animations.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/gtk/gtk2.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/gtk/gtk2.hidpi.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/gtk/gtk3.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/gtk/gtk4.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/hypr.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/hyprlock.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/kitty.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/kvantum/kvantum.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/kvantum/kvconfig.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/rofi.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/wallbash/theme/waybar.dcol` | Wallbash 主题生成/模板资源 |
| `Configs/.local/share/waybar/includes/border-radius.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/includes/global.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/01.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/02.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/03.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/04.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/05.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/06.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/07.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/08.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/09.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/10.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/11.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/12.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/13.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/14.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/15.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/16.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/hyprdots/17.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/khing.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/layouts/macos.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/clipboard.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/dunst.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/gpuinfo.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/hyde-menu.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/hyprsunset.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/mediaplayer.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/power.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/pulseaudio.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/spotify.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/menus/swaync.xml` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/backlight.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/battery.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/bluetooth.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/cava.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/clock.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/cpu.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-cava.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-clipboard.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-cliphist.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-cpuinfo.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-display.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-dunst.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-gamemode.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-github_hyde.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-gpuinfo#amd.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-gpuinfo#intel.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-gpuinfo#nvidia.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-gpuinfo.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-hyde-menu.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-hyprsunset.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-keybindhint.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-mediaplayer.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-power.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-powermenu.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-sensorsinfo.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-spotify.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-swaync.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-theme.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-updates.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-wallchange.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-wbar.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-weather.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/custom-workflows.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/gamemode.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/group-eyecare.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/group-hide-tray.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/group-mediaplayer.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/group-volumecontrol.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/hyprland-language.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/hyprland-window.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/hyprland-workspaces#kanji.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/hyprland-workspaces#roman.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/hyprland-workspaces.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/idle_inhibitor.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/image#profile.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/image#wallpaper.json` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/image#wallpaper.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/memory.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/mpd.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/mpris.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/network#bandwidth.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/network.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/power-profiles-daemon.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/privacy.json` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/privacy.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/pulseaudio#microphone.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/pulseaudio.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/temperature.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/tray.json` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/tray.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/wlr-taskbar#windows.json` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/wlr-taskbar#windows.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/wlr-taskbar.json` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/modules/wlr-taskbar.jsonc` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/backgrounds/transparent.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/color/main-bg.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/color/main-fg.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/color/wb-act-bg.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/color/wb-act-fg.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/color/wb-hvr-bg.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/color/wb-hvr-fg.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/dotted-bottom.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/dotted-top.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/dotted.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/none.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/solid-bottom.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/solid-top.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/borders/solid.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/defaults.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/leaf-inverse.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/leaf.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/pill-down.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/pill-in.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/pill-left.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/pill-out.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/pill-right.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/pill-up.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/groups/pill.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/hyprdots.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/includes/border-radius.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/share/waybar/styles/macos.css` | Waybar 共享模块/布局/样式资源 |
| `Configs/.local/state/dolphinstaterc` | HyDE 配置资源 |
| `Configs/.local/state/hyde/hyprland.conf` | HyDE 配置资源 |
| `Configs/.zshenv` | HyDE 配置资源 |
| `CONTRIBUTING.md` | 贡献指南 |
| `CONTRIBUTORS.md` | 贡献者名单 |
| `CREDITS.md` | 致谢/鸣谢 |
| `flake.lock` | Nix Flake 锁定文件 |
| `flake.nix` | Nix Flake 配置 |
| `Hyprdots-to-HyDE.md` | 从 Hyprdots 迁移到 HyDE 的说明 |
| `INSTALL_SH_GUIDE.md` | 项目文档 |
| `KEYBINDINGS.md` | 快捷键总览 |
| `LICENSE` | 许可证 |
| `README.md` | 项目总览与安装说明 |
| `RELEASE_POLICY.md` | 发布/分支策略 |
| `Scripts/chaotic_aur.sh` | Chaotic AUR 的安装/卸载/回滚 |
| `Scripts/extra/custom_flat.lst` | Flatpak 安装清单 |
| `Scripts/extra/drivext_mnt.sh` | 附加功能脚本/清单 |
| `Scripts/extra/install_fpk.sh` | 附加功能脚本/清单 |
| `Scripts/extra/install_mod.sh` | 附加功能脚本/清单 |
| `Scripts/extra/restore_app.sh` | 附加功能脚本/清单 |
| `Scripts/extra/restore_lnk.sh` | 附加功能脚本/清单 |
| `Scripts/global_fn.sh` | 全局函数与变量（安装脚本共用） |
| `Scripts/hydevm/default.nix` | HydeVM Nix 配置 |
| `Scripts/hydevm/hydevm.sh` | HydeVM 启动脚本 |
| `Scripts/hydevm/README.md` | HydeVM 使用说明 |
| `Scripts/install.sh` | 主安装入口，负责安装/恢复/服务启用与重启提示 |
| `Scripts/install_aur.sh` | 安装 AUR helper（通过 pacman，paru 需 Chaotic AUR） |
| `Scripts/install_pkg.sh` | 按清单安装 Arch/AUR 包 |
| `Scripts/install_pre.sh` | 安装前系统准备（引导器、pacman、Chaotic AUR） |
| `Scripts/install_pst.sh` | 安装后配置（SDDM/默认文件管理器/flatpak/ shell） |
| `Scripts/migrations/v25.8.2.sh` | 迁移脚本（按版本执行） |
| `Scripts/migrations/v25.9.1.sh` | 迁移脚本（按版本执行） |
| `Scripts/nvidia-db/gen_table.py` | NVIDIA 驱动映射表生成脚本 |
| `Scripts/nvidia-db/nvidia-340xx-dkms` | NVIDIA 驱动映射/匹配表 |
| `Scripts/nvidia-db/nvidia-390xx-dkms` | NVIDIA 驱动映射/匹配表 |
| `Scripts/nvidia-db/nvidia-470xx-dkms` | NVIDIA 驱动映射/匹配表 |
| `Scripts/nvidia-db/nvidia-580xx-dkms` | NVIDIA 驱动映射/匹配表 |
| `Scripts/nvidia-db/nvidia-open-dkms` | NVIDIA 驱动映射/匹配表 |
| `Scripts/pkg_core.lst` | 核心软件包清单 |
| `Scripts/pkg_extra.lst` | 可选软件包清单 |
| `Scripts/restore_cfg.lst` | 旧版 dotfiles 恢复清单（legacy） |
| `Scripts/restore_cfg.psv` | dotfiles 恢复清单（PSV 格式） |
| `Scripts/restore_cfg.sh` | 恢复配置文件并执行 HyDE 初始化 |
| `Scripts/restore_fnt.lst` | 字体/主题归档解压清单 |
| `Scripts/restore_fnt.sh` | 解压字体/主题资源并刷新字体缓存 |
| `Scripts/restore_shl.sh` | Shell 配置与插件安装 |
| `Scripts/restore_svc.lst` | systemd 服务清单 |
| `Scripts/restore_svc.sh` | 启用/启动系统服务 |
| `Scripts/restore_thm.sh` | 批量导入主题 |
| `Scripts/restore_zsh.lst` | Zsh 插件清单 |
| `Scripts/themepatcher.lst` | 主题仓库导入清单 |
| `Scripts/themepatcher.sh` | 主题打补丁与资源解包工具 |
| `Scripts/uninstall.sh` | 卸载脚本（移除 HyDE） |
| `Scripts/version.sh` | 保存/输出版本信息 |
| `Source/arcs/Code_Wallbash.vsix` | VS Code 扩展包 |
| `Source/arcs/Cursor_BibataIce.tar.gz` | 光标主题归档包 |
| `Source/arcs/Firefox_Extensions.tar.gz` | Firefox 配置/扩展归档 |
| `Source/arcs/Firefox_UserConfig.tar.gz` | Firefox 配置/扩展归档 |
| `Source/arcs/Font_CascadiaCove.tar.gz` | 字体归档包 |
| `Source/arcs/Font_JetBrainsMono.tar.gz` | 字体归档包 |
| `Source/arcs/Font_MapleNerd.tar.gz` | 字体归档包 |
| `Source/arcs/Font_MaterialDesign.tar.gz` | 字体归档包 |
| `Source/arcs/Font_MononokiNerd.tar.gz` | 字体归档包 |
| `Source/arcs/Font_NotoSansCJK.tar.gz` | 字体归档包 |
| `Source/arcs/Grub_Pochita.tar.gz` | GRUB 主题归档包 |
| `Source/arcs/Grub_Retroboot.tar.gz` | GRUB 主题归档包 |
| `Source/arcs/Gtk_Wallbash.tar.gz` | GTK 主题归档包 |
| `Source/arcs/Icon_Wallbash.tar.gz` | 图标主题归档包 |
| `Source/arcs/Sddm_Candy.tar.gz` | SDDM 主题归档包 |
| `Source/arcs/Sddm_Corners.tar.gz` | SDDM 主题归档包 |
| `Source/arcs/Spotify_Sleek.tar.gz` | Spotify 主题归档包 |
| `Source/arcs/Steam_Metro.tar.gz` | 主题/资源归档包 |
| `Source/assets/arch.png` | README/展示用图片资源 |
| `Source/assets/archlinux.png` | README/展示用图片资源 |
| `Source/assets/cachyos.png` | README/展示用图片资源 |
| `Source/assets/endeavouros.png` | README/展示用图片资源 |
| `Source/assets/game_launch_1.png` | README/展示用图片资源 |
| `Source/assets/game_launch_2.png` | README/展示用图片资源 |
| `Source/assets/game_launch_3.png` | README/展示用图片资源 |
| `Source/assets/game_launch_4.png` | README/展示用图片资源 |
| `Source/assets/game_launch_5.png` | README/展示用图片资源 |
| `Source/assets/garuda.png` | README/展示用图片资源 |
| `Source/assets/hyde_banner.png` | README/展示用图片资源 |
| `Source/assets/hyprdots_arch.png` | README/展示用图片资源 |
| `Source/assets/hyprdots_banner.png` | README/展示用图片资源 |
| `Source/assets/hyprdots_logo.png` | README/展示用图片资源 |
| `Source/assets/keybinds/KEYBINDINGS.ar.md` | README/展示用图片资源 |
| `Source/assets/keybinds/KEYBINDINGS.de.md` | README/展示用图片资源 |
| `Source/assets/keybinds/KEYBINDINGS.es.md` | README/展示用图片资源 |
| `Source/assets/keybinds/KEYBINDINGS.fr.md` | README/展示用图片资源 |
| `Source/assets/keybinds/KEYBINDINGS.nl.md` | README/展示用图片资源 |
| `Source/assets/keybinds/KEYBINDINGS.zh.md` | README/展示用图片资源 |
| `Source/assets/nixos.png` | README/展示用图片资源 |
| `Source/assets/notif_action_sel.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_1.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_10.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_11.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_12.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_2.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_3.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_4.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_5.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_6.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_7.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_8.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_9.png` | README/展示用图片资源 |
| `Source/assets/rofi_style_sel.png` | README/展示用图片资源 |
| `Source/assets/showcase_1.png` | README/展示用图片资源 |
| `Source/assets/showcase_2.png` | README/展示用图片资源 |
| `Source/assets/showcase_3.png` | README/展示用图片资源 |
| `Source/assets/showcase_4.png` | README/展示用图片资源 |
| `Source/assets/theme_cedge_1.png` | README/展示用图片资源 |
| `Source/assets/theme_cedge_2.png` | README/展示用图片资源 |
| `Source/assets/theme_decay_1.png` | README/展示用图片资源 |
| `Source/assets/theme_decay_2.png` | README/展示用图片资源 |
| `Source/assets/theme_frosted_1.png` | README/展示用图片资源 |
| `Source/assets/theme_frosted_2.png` | README/展示用图片资源 |
| `Source/assets/theme_graph_1.png` | README/展示用图片资源 |
| `Source/assets/theme_graph_2.png` | README/展示用图片资源 |
| `Source/assets/theme_gruvbox_1.png` | README/展示用图片资源 |
| `Source/assets/theme_gruvbox_2.png` | README/展示用图片资源 |
| `Source/assets/theme_latte_1.png` | README/展示用图片资源 |
| `Source/assets/theme_latte_2.png` | README/展示用图片资源 |
| `Source/assets/theme_maura_1.png` | README/展示用图片资源 |
| `Source/assets/theme_maura_2.png` | README/展示用图片资源 |
| `Source/assets/theme_mocha_1.png` | README/展示用图片资源 |
| `Source/assets/theme_mocha_2.png` | README/展示用图片资源 |
| `Source/assets/theme_rosine_1.png` | README/展示用图片资源 |
| `Source/assets/theme_rosine_2.png` | README/展示用图片资源 |
| `Source/assets/theme_select_1.png` | README/展示用图片资源 |
| `Source/assets/theme_select_2.png` | README/展示用图片资源 |
| `Source/assets/theme_tokyo_1.png` | README/展示用图片资源 |
| `Source/assets/theme_tokyo_2.png` | README/展示用图片资源 |
| `Source/assets/walls_select.png` | README/展示用图片资源 |
| `Source/assets/wb_mode_sel.png` | README/展示用图片资源 |
| `Source/assets/wlog_style_1.png` | README/展示用图片资源 |
| `Source/assets/wlog_style_2.png` | README/展示用图片资源 |
| `Source/assets/yt_playlist.png` | README/展示用图片资源 |
| `Source/docs/Hyprdots-to-HyDE.de.md` | 多语言文档 |
| `Source/docs/Hyprdots-to-HyDE.es.md` | 多语言文档 |
| `Source/docs/Hyprdots-to-HyDE.zh.md` | 多语言文档 |
| `Source/docs/README.ar.md` | 多语言文档 |
| `Source/docs/README.de.md` | 多语言文档 |
| `Source/docs/README.es.md` | 多语言文档 |
| `Source/docs/README.fr.md` | 多语言文档 |
| `Source/docs/README.nl.md` | 多语言文档 |
| `Source/docs/README.pt-br.md` | 多语言文档 |
| `Source/docs/README.tr.md` | 多语言文档 |
| `Source/docs/README.zh.md` | 多语言文档 |
| `Source/misc/nightTab_backdrop.jpg` | 杂项资源文件 |
| `Source/misc/nightTab_config.json` | 杂项资源文件 |
| `Source/misc/tittu.face.icon` | 杂项资源文件 |
| `TEAM_ROLES.md` | 团队角色说明 |
| `TESTING.md` | 测试指南 |
