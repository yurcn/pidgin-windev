#!/bin/bash

##
##    Pidgin Windows Development Setup 2015.4.15
##    Copyright 2012-2015 Renato Silva
##    GPLv2 licensed
##
## This script sets up a Windows build environment for Pidgin in one single
## shot, without the long manual steps described in the official wiki. These
## steps are automatically executed, except for GnuPG installation. After
## running this tool and finishing the manual steps you can configure system
## path with --path and then be able to start building.
##
## Usage:
##     @script.name [options] DEVELOPMENT_ROOT
##
##     -p, --path          Print system path configuration for evaluation after
##                         the build environment has been created. This will
##                         allow you to start compilation.
##
##     -w, --which-pidgin  Show the minimum Pidgin version this script creates
##                         an environment for. Newer versions will also compile
##                         if not requiring any environment changes.
##
##         --version=WHAT  Specify a version other than --which-pidgin.
##
##     -n, --no-source     Do not retrieve the source code for Pidgin itself.
##                         Use this if you already have the source code.
##
##     -c, --no-color      Disable colored output.
##

source easyoptions || exit
pidgin_version="2.10.11.next"

# Output formatting
step() { printf "${green}$1${normal}\n"; }
info() { printf "$1${2:+ ${purple}$2${normal}}\n"; }
warn() { printf "${1:+${yellow}Warning:${normal} $1}\n"; }
oops() { printf "${red}Error:${normal} $1.\nSee --help for usage and options.\n"; exit 1; }
if [[ -t 1 && -z "$no_color" ]]; then
    normal="\e[0m"
    if [[ "$MSYSCON" = mintty* && "$TERM" = *256color* ]]; then
        red="\e[38;05;9m"
        green="\e[38;05;76m"
        blue="\e[38;05;74m"
        yellow="\e[0;33m"
        purple="\e[38;05;165m"
    else
        red="\e[1;31m"
        green="\e[1;32m"
        blue="\e[1;34m"
        yellow="\e[1;33m"
        purple="\e[1;35m"
    fi
fi

# Pidgin version
if [[ -n "$which_pidgin" ]]; then
    echo "$pidgin_version"
    exit
fi

# Under development
if [[ -z "$no_source" && "$pidgin_version" = *.next ]]; then
    echo "This script is under development for the next version of Pidgin following"
    echo "${pidgin_version%.next} and currently can only create a build environment for some specific"
    echo "development revision from the source code repository. You need to either"
    echo "specify --no-source or use a previous version of this script."
    exit 1
fi

# Some validation
devroot="${arguments[0]}"
[[ -n "$version" && -n "$no_source" ]] && oops "a version can only be specified when downloading the source code"
[[ -f "$devroot" ]] && oops "the existing development root is not a directory: \"$devroot\""
[[ -z "$devroot" ]] && oops "a development root must be specified"

# Development root
if [[ ! -e "$devroot" ]]; then
    step "Creating new development root"
    info "Location:" "$devroot"
    info; mkdir -p "$devroot"
fi
cd "$devroot"
devroot=$(readlink -m "$(pwd)")
[[ $? != 0 ]] && oops "failed to get absolute path for $devroot"
cd - > /dev/null

# Configuration
cache="$devroot/downloads"
win32="$devroot/win32-dev"
nsis="nsis-2.46"
mingw="mingw-gcc-4.7.2"
gtkspell="gtkspell-2.0.16"
gcc_core44="gcc-core-4.4.0-mingw32-dll"
pidgin_inst_deps="pidgin-inst-deps-20130214"
intltool="intltool_0.40.4-1_win32"
perl_version="5.20.1.1"
perl="strawberry-perl-$perl_version-32bit"
perl_dir="strawberry-perl-${perl_version%.*}"
pidgin_base_url="https://developer.pidgin.im/static/win32"
gnome_base_url="http://ftp.gnome.org/pub/gnome/binaries"
mingw_base_url="http://sourceforge.net/projects/mingw/files/MinGW/Base"
mingw_gcc44_url="$mingw_base_url/gcc/Version4/Previous%20Release%20gcc-4.4.0"
mingw_pthreads_url="$mingw_base_url/pthreads-w32/pthreads-w32-2.9.0-pre-20110507-2"

# Functions

available() {
    which "$1" >/dev/null 2>&1 && return 0
    warn "could not find ${1} in system path"
    return 1
}

download() {
    filename="${2%/download}"
    filename="${filename##*/}"
    info "Fetching" "$filename"
    file="$1/$filename"
    mkdir -p "$1"
    [[ -f "$file" && ! -s "$file" ]] && rm "$file"
    [[ ! -e "$file" ]] && { wget --no-check-certificate --quiet --output-document "$file" "$2" || oops "failed downloading from ${2}"; }
}

extract() {
    format="$1"
    directory="$2"
    compressed="$3"
    file="$4"
    compressed_name="${compressed##*/}"
    info "Extracting" "${file:+${file##*/} from }${compressed_name}"
    mkdir -p "$directory"
    case "$format" in
        bsdtar)  bsdtar -xzf          "$compressed"  --directory "$directory" ;;
        lzma)    tar --lzma -xf       "$compressed"  --directory "$directory" ;;
        bzip2)   tar -xjf             "$compressed"  --directory "$directory" ;;
        gzip)    tar -xzf             "$compressed"  --directory "$directory" ;;
        zip)     unzip -qo${file:+j}  "$compressed"     $file -d "$directory" ;;
    esac || exit
}

mingw_get() {
    package="$1"
    info 'Checking' "$package"
    mingw-get install "$package" --verbose=0 >/dev/null 2>&1 || oops "failed installing ${package}"
}

# Path configuration
if [[ -n "$path" ]]; then
    printf "export PATH='"
    printf "${win32}/${mingw}/bin:"
    printf "${win32}/${perl_dir}/perl/bin:"
    printf "${win32}/${nsis}:"
    printf "${PATH}'"
    exit
fi

# Install what is possible with package manager
step "Installing the necessary packages"
if available mingw-get; then
    mingw_get 'mingw32-bzip2'
    mingw_get 'mingw32-libiconv'
    mingw_get 'msys-bsdtar'
    mingw_get 'msys-coreutils'
    mingw_get 'msys-libopenssl'
    mingw_get 'msys-make'
    mingw_get 'msys-patch'
    mingw_get 'msys-unzip'
    mingw_get 'msys-wget'
    mingw_get 'msys-zip'
fi
echo

# Download GCC
step "Downloading specific MinGW GCC"
download "${cache}/${mingw}" "${mingw_base_url}/binutils/binutils-2.23.1/binutils-2.23.1-1-mingw32-bin.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/gcc-core-4.7.2-1-mingw32-bin.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/libgcc-4.7.2-1-mingw32-dll-1.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/libgomp-4.7.2-1-mingw32-dll-1.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/libquadmath-4.7.2-1-mingw32-dll-0.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gcc/Version4/gcc-4.7.2-1/libssp-4.7.2-1-mingw32-dll-0.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gettext/gettext-0.18.1.1-2/libintl-0.18.1.1-2-mingw32-dll-8.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gmp/gmp-5.0.1-1/gmp-5.0.1-1-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/gmp/gmp-5.0.1-1/libgmp-5.0.1-1-mingw32-dll-10.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/libiconv/libiconv-1.14-2/libiconv-1.14-2-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/libiconv/libiconv-1.14-2/libiconv-1.14-2-mingw32-dll-2.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mingwrt/mingwrt-3.20/mingwrt-3.20-2-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mingwrt/mingwrt-3.20/mingwrt-3.20-2-mingw32-dll.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mpc/mpc-0.8.1-1/libmpc-0.8.1-1-mingw32-dll-2.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mpc/mpc-0.8.1-1/mpc-0.8.1-1-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mpfr/mpfr-2.4.1-1/libmpfr-2.4.1-1-mingw32-dll-1.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/mpfr/mpfr-2.4.1-1/mpfr-2.4.1-1-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_base_url}/w32api/w32api-3.17/w32api-3.17-2-mingw32-dev.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_pthreads_url}/libpthreadgc-2.9.0-mingw32-pre-20110507-2-dll-2.tar.lzma/download"
download "${cache}/${mingw}" "${mingw_pthreads_url}/pthreads-w32-2.9.0-mingw32-pre-20110507-2-dev.tar.lzma/download"
echo

# Download Pidgin
if [[ -z "$no_source" ]]; then
    step "Downloading Pidgin source code"
    download "$cache" "http://prdownloads.sourceforge.net/pidgin/pidgin-${pidgin_version}.tar.bz2"
    source_directory="${devroot}/pidgin-${pidgin_version}"
    echo
fi

# Download dependencies
step "Downloading build dependencies"
download "${cache}" "${gnome_base_url}/win32/dependencies/gettext-runtime-0.17-1.zip"
download "${cache}" "${gnome_base_url}/win32/dependencies/gettext-tools-0.17.zip"
download "${cache}" "${gnome_base_url}/win32/gtk+/2.14/gtk+-bundle_2.14.7-20090119_win32.zip"
download "${cache}" "${gnome_base_url}/win32/intltool/0.40/${intltool}.zip"
download "${cache}" "${mingw_gcc44_url}/${gcc_core44}.tar.gz/download"
download "${cache}" "${pidgin_base_url}/${gtkspell}.tar.bz2"
download "${cache}" "${pidgin_base_url}/cyrus-sasl-2.1.26_daa1.tar.gz"
download "${cache}" "${pidgin_base_url}/enchant_1.6.0_win32.zip"
download "${cache}" "${pidgin_base_url}/libxml2-2.9.2_daa1.tar.gz"
download "${cache}" "${pidgin_base_url}/meanwhile-1.0.2_daa3-win32.zip"
download "${cache}" "${pidgin_base_url}/nss-3.17.3-nspr-4.10.7.tar.gz"
download "${cache}" "${pidgin_base_url}/perl-${perl_version}.tar.gz"
download "${cache}" "${pidgin_base_url}/silc-toolkit-1.1.12.tar.gz"
download "${cache}" "${pidgin_base_url}/${pidgin_inst_deps}.tar.gz"
download "${cache}" "http://strawberryperl.com/download/${perl_version}/${perl}.zip"
download "${cache}" "http://nsis.sourceforge.net/mediawiki/images/1/1c/Nsisunz.zip"
download "${cache}" "http://sourceforge.net/projects/nsis/files/NSIS%202/2.46/${nsis}.zip/download"
echo

# Extract GCC
step "Extracting MinGW GCC"
for tarball in "${cache}/${mingw}/"*".tar.lzma"; do
    extract lzma "${win32}/${mingw}" "$tarball"
done
echo

# Extract Pidgin
if [[ -z "$no_source" ]]; then
    step "Extracting Pidgin source code"
    extract bzip2 "$devroot" "${cache}/pidgin-${pidgin_version}.tar.bz2" && info 'Extracted to' "$source_directory"
    echo 'MONO_SIGNCODE = echo ***Bypassing signcode***' >  "${source_directory}/local.mak"
    echo 'GPG_SIGN = echo ***Bypassing gpg***'           >> "${source_directory}/local.mak"
    echo
fi

# Extract dependencies
step "Extracting build dependencies"
extract gzip   "${win32}"                 "${cache}/${pidgin_inst_deps}.tar.gz"
extract gzip   "${win32}"                 "${cache}/libxml2-2.9.2_daa1.tar.gz"
extract bsdtar "${win32}"                 "${cache}/cyrus-sasl-2.1.26_daa1.tar.gz"
extract bsdtar "${win32}"                 "${cache}/nss-3.17.3-nspr-4.10.7.tar.gz"
extract bsdtar "${win32}"                 "${cache}/perl-${perl_version}.tar.gz"
extract bsdtar "${win32}"                 "${cache}/silc-toolkit-1.1.12.tar.gz"
extract bzip2  "${win32}"                 "${cache}/${gtkspell}.tar.bz2"
extract zip    "${win32}"                 "${cache}/meanwhile-1.0.2_daa3-win32.zip"
extract zip    "${win32}"                 "${cache}/enchant_1.6.0_win32.zip"
extract zip    "${win32}"                 "${cache}/${nsis}.zip"
extract zip    "${win32}/${nsis}/Plugins" "${cache}/Nsisunz.zip" nsisunz/Release/nsisunz.dll
extract zip    "${win32}/${perl_dir}"     "${cache}/${perl}.zip"
extract zip    "${win32}/gettext-0.17"    "${cache}/gettext-runtime-0.17-1.zip"
extract zip    "${win32}/gettext-0.17"    "${cache}/gettext-tools-0.17.zip"
extract zip    "${win32}/gtk_2_0-2.14"    "${cache}/gtk+-bundle_2.14.7-20090119_win32.zip"
extract zip    "${win32}/${intltool}"     "${cache}/${intltool}.zip"
extract gzip   "${win32}/${gcc_core44}"   "${cache}/${gcc_core44}.tar.gz"
echo

# Check for GnuPG
step "Checking for GnuPG"
available gpg && info 'GnuPG found at' $(which gpg)
echo
