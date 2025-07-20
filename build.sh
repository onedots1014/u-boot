#!/bin/bash
set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 构建配置
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-

# 可配置参数（可通过环境变量覆盖）
UBOOT_DEFCONFIG="${UBOOT_DEFCONFIG:-stm32mp15_trusted_defconfig}"
DEVICE_TREE="${DEVICE_TREE:-stm32mp157c-onedots-512d-v1}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/output/uboot}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
BUILD_TYPE="${BUILD_TYPE:-release}"

# 构建选项
CLEAN_BUILD="${CLEAN_BUILD:-false}"
VERBOSE="${VERBOSE:-false}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

# Help function
show_help() {
    cat << EOF
U-Boot Build Script

Usage: $0 [options]

Options:
    -h, --help              Show help information
    -c, --clean            Clean before build
    -v, --verbose          Enable verbose output
    -j, --jobs N           Specify parallel build jobs (default: $(nproc))
    -o, --output DIR       Specify output directory (default: ../output/uboot)
    -d, --defconfig CFG    Specify defconfig (default: $UBOOT_DEFCONFIG)
    -t, --device-tree DT   Specify device tree name (default: $DEVICE_TREE)
    --debug                Enable debug build

Environment Variables:
    CROSS_COMPILE          Cross-compiler toolchain prefix (default: arm-linux-gnueabi-)
    ARCH                   Target architecture (default: arm)

Examples:
    $0                      # Default build
    $0 -c -j4              # Clean build with 4 parallel jobs
    $0 --debug --verbose   # Debug build with verbose output
EOF
}

# 参数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                CLEAN_BUILD=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -j|--jobs)
                BUILD_JOBS="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -d|--defconfig)
                UBOOT_DEFCONFIG="$2"
                shift 2
                ;;
            -t|--device-tree)
                DEVICE_TREE="$2"
                shift 2
                ;;
            --debug)
                BUILD_TYPE=debug
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 环境检查
check_environment() {
    log_step "[环境检查] 验证构建环境..."
    
    # 检查交叉编译工具链
    if ! command -v "${CROSS_COMPILE}gcc" &> /dev/null; then
        log_error "交叉编译工具链未找到: ${CROSS_COMPILE}gcc"
        log_info "请确保已安装 ARM 交叉编译工具链"
        exit 1
    fi
    
    # 检查 make
    if ! command -v make &> /dev/null; then
        log_error "make 命令未找到"
        exit 1
    fi
    
    # 显示工具链信息
    local gcc_version=$(${CROSS_COMPILE}gcc --version | head -n1)
    log_info "交叉编译工具链: $gcc_version"
    log_info "目标架构: $ARCH"
    log_info "并行任务数: $BUILD_JOBS"
    log_info "构建类型: $BUILD_TYPE"
}

# 清理构建
clean_build() {
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        log_step "[清理] 清理之前的构建产物..."
        make distclean || true
        rm -rf "$OUTPUT_DIR"
        log_success "构建目录已清理"
    fi
}

# 配置 U-Boot
configure_uboot() {
    log_step "[1/3] 配置 U-Boot: $UBOOT_DEFCONFIG"
    
    if [[ "$VERBOSE" == "true" ]]; then
        make $UBOOT_DEFCONFIG
    else
        make $UBOOT_DEFCONFIG > /dev/null 2>&1
    fi
    
    # 如果是调试构建，启用调试选项
    if [[ "$BUILD_TYPE" == "debug" ]]; then
        log_info "启用调试构建选项..."
        # 这里可以添加调试相关的配置修改
    fi
    
    log_success "配置完成: $UBOOT_DEFCONFIG"
}

# 编译 U-Boot
compile_uboot() {
    log_step "[2/3] 编译 U-Boot (设备树: $DEVICE_TREE)..."
    
    local start_time=$(date +%s)
    local make_cmd="make DEVICE_TREE=$DEVICE_TREE all -j$BUILD_JOBS"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "执行命令: $make_cmd"
        $make_cmd
    else
        $make_cmd > /dev/null 2>&1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_success "编译完成 (耗时: ${duration}秒)"
}

# 收集和拷贝产物
collect_artifacts() {
    log_step "[3/3] 收集构建产物到 $OUTPUT_DIR"
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
    
    # 定义需要拷贝的文件
    local binary_files=(
        "u-boot.bin"
        "u-boot-dtb.bin" 
        "u-boot-nodtb.bin"
        "u-boot.dtb"
        "u-boot.stm32"
    )
    
    local debug_files=(
        "u-boot.map"
        "u-boot.sym"
        "System.map"
    )
    
    # 拷贝二进制文件
    log_info "拷贝二进制文件..."
    local copied_binaries=0
    for file in "${binary_files[@]}"; do
        if [[ -f "$file" ]]; then
            cp -v "$file" "$OUTPUT_DIR/"
            ((copied_binaries++))
        else
            log_warning "文件不存在，跳过: $file"
        fi
    done
    
    # 拷贝调试文件
    if [[ "$BUILD_TYPE" == "debug" ]] || [[ "$VERBOSE" == "true" ]]; then
        log_info "拷贝调试文件..."
        local copied_debug=0
        for file in "${debug_files[@]}"; do
            if [[ -f "$file" ]]; then
                cp -v "$file" "$OUTPUT_DIR/" || true
                ((copied_debug++))
            fi
        done
        log_info "已拷贝 $copied_debug 个调试文件"
    fi
    
    log_success "已拷贝 $copied_binaries 个二进制文件"
}

# 显示构建结果
show_results() {
    log_success "🎉 U-Boot 构建完成！"
    
    echo
    log_info "📦 构建产物位于: $OUTPUT_DIR"
    
    # 显示文件大小信息
    if [[ -d "$OUTPUT_DIR" ]]; then
        echo
        log_info "📋 产物文件列表:"
        ls -lh "$OUTPUT_DIR" | while read line; do
            echo "    $line"
        done
        
        # 显示主要文件的大小
        local main_files=("u-boot.bin" "u-boot.stm32")
        echo
        log_info "🔍 主要文件大小:"
        for file in "${main_files[@]}"; do
            if [[ -f "$OUTPUT_DIR/$file" ]]; then
                local size=$(du -h "$OUTPUT_DIR/$file" | cut -f1)
                echo "    $file: $size"
            fi
        done
    fi
    
    echo
    log_info "💡 提示:"
    log_info "  - 使用 $0 --help 查看更多选项"
    log_info "  - 使用 $0 --clean 进行完全清理构建"
    log_info "  - 使用 $0 --verbose 查看详细构建过程"
}

# 错误处理
trap 'log_error "构建过程中发生错误，请检查上述输出"; exit 1' ERR

# 主函数
main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 切换到脚本目录
    cd "$SCRIPT_DIR"
    
    # Display build information
    echo
    log_info "🚀 Starting U-Boot build for STM32MP157"
    log_info "============================================"
    log_info "Config file: $UBOOT_DEFCONFIG"
    log_info "Device tree: $DEVICE_TREE" 
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Build jobs: $BUILD_JOBS"
    log_info "============================================"
    echo
    
    # 执行构建步骤
    check_environment
    clean_build
    configure_uboot
    compile_uboot
    collect_artifacts
    show_results
}

# 执行主函数
main "$@"
