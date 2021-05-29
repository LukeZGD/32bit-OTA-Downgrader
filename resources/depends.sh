#!/bin/bash

SetToolPaths() {
    if [[ $OSTYPE == "linux"* ]]; then
        . /etc/os-release 2>/dev/null
        platform="linux"
    
        futurerestore1="sudo LD_PRELOAD=./resources/lib/libcurl.so.3 LD_LIBRARY_PATH=resources/lib ./resources/tools/futurerestore1_linux"
        futurerestore2="sudo LD_LIBRARY_PATH=resources/lib ./resources/tools/futurerestore2_linux"
        idevicerestore="sudo LD_LIBRARY_PATH=resources/lib ./resources/tools/idevicerestore_linux"
        ipsw="env LD_LIBRARY_PATH=./lib ./tools/ipsw_linux"
        partialzip="./resources/tools/partialzip_linux"
        python="$(which python2)"
        tsschecker="./resources/tools/tsschecker_linux"
        ipwndfu="sudo $python ipwndfu"
        rmsigchks="sudo $python rmsigchks.py"
        SimpleHTTPServer="sudo $python -m SimpleHTTPServer 80"

    elif [[ $OSTYPE == "darwin"* ]]; then
        macver=${1:-$(sw_vers -productVersion)}
        platform="macos"
    
        futurerestore1="./resources/tools/futurerestore1_macos"
        futurerestore2="./resources/tools/futurerestore2_macos"
        idevicerestore="./resources/tools/idevicerestore_macos"
        ipsw="./tools/ipsw_macos"
        ipwnder32="./resources/tools/ipwnder32_macos"
        partialzip="./resources/tools/partialzip_macos"
        python="/usr/bin/python"
        tsschecker="./resources/tools/tsschecker_macos"
        ipwndfu="$python ipwndfu"
        rmsigchks="$python rmsigchks.py"
        SimpleHTTPServer="$python -m SimpleHTTPServer 80"
    fi
    bspatch="$(which bspatch)"
    git="$(which git)"
    ideviceenterrecovery="./resources/libimobiledevice_$platform/ideviceenterrecovery"
    ideviceinfo="./resources/libimobiledevice_$platform/ideviceinfo"
    iproxy="./resources/libimobiledevice_$platform/iproxy"
    irecoverychk="./resources/libimobiledevice_$platform/irecovery"
    irecovery="$irecoverychk"
    [[ $platform == "linux" ]] && irecovery="sudo $irecovery"
    SSH="-F ./resources/ssh_config"
    SCP="$(which scp) $SSH"
    SSH="$(which ssh) $SSH"
    
    Log "Running on platform: $platform $macver"
}

SaveExternal() {
    ExternalURL="https://github.com/LukeZGD/$1.git"
    External=$1
    [[ $1 == "iOS-OTA-Downgrader-Keys" ]] && External="firmware"
    cd resources
    if [[ ! -d $External ]] || [[ ! -d $External/.git ]]; then
        Log "Downloading $External..."
        rm -rf $External
        $git clone $ExternalURL $External
    fi
    if [[ ! -e $External/README.md ]] || [[ ! -d $External/.git ]]; then
        rm -rf $External
        Error "Downloading/updating $1 failed. Please run the script again"
    fi
    cd ..
}

SaveFile() {
    curl -L $1 -o $2
    if [[ $(shasum $2 | awk '{print $1}') != $3 ]]; then
        Error "Verifying failed. Please run the script again" "./restore.sh Install"
    fi
}

SavePkg() {
    if [[ ! -d ../saved/lib ]]; then
        Log "Downloading packages..."
        SaveFile https://github.com/LukeZGD/iOS-OTA-Downgrader-Keys/releases/download/tools/depends2_linux.zip depends_linux.zip 38cf1db21c9aba88f0de95a1a7959ac2ac53c464
        mkdir -p ../saved/lib
        unzip depends_linux.zip -d ../saved/lib
    fi
    cp ../saved/lib/* .
}


InstallDepends() {
    local iproxy
    local libimobiledevice
    
    mkdir resources/lib tmp 2>/dev/null
    cd resources
    rm -rf firmware ipwndfu lib/*
    cd ../tmp
    
    Log "Installing dependencies..."
    if [[ $ID == "arch" || $ID_LIKE == "arch" ]]; then
        sudo pacman -Syu --noconfirm --needed base-devel bsdiff curl libcurl-compat libpng12 libimobiledevice libzip openssh openssl-1.0 python2 unzip usbutils
        ln -sf /usr/lib/libcurl.so.3 ../resources/lib/libcurl.so.3
        ln -sf /usr/lib/libzip.so.5 ../resources/lib/libzip.so.4
    
    elif [[ $UBUNTU_CODENAME == "focal" || $UBUNTU_CODENAME == "groovy" ||
            $UBUNTU_CODENAME == "hirsute" || $PRETTY_NAME == "Debian GNU/Linux bullseye/sid" ]]; then
        [[ ! -z $UBUNTU_CODENAME ]] && sudo add-apt-repository -y universe
        sudo apt update
        sudo apt install -y bsdiff curl git libimobiledevice6 openssh-client python2 usbmuxd usbutils
        SavePkg
        cp libcrypto.so.1.0.0 libcurl.so.3 libpng12.so.0 libssl.so.1.0.0 ../resources/lib
        if [[ $PRETTY_NAME == "Debian GNU/Linux bullseye/sid" || $UBUNTU_CODENAME == "hirsute" ]]; then
            sudo apt install -y libzip4
        else
            cp libzip.so.4 ../resources/lib
        fi
    
    elif [[ $ID == "fedora" ]] && (( $VERSION_ID >= 33 )); then
        sudo dnf install -y bsdiff git libimobiledevice libpng12 libzip perl-Digest-SHA python2
        SavePkg
        cp libcrypto.so.1.0.0 libssl.so.1.0.0 ../resources/lib
        ln -sf /usr/lib64/libzip.so.5 ../resources/lib/libzip.so.4
        ln -sf /usr/lib64/libbz2.so.1.* ../resources/lib/libbz2.so.1.0
    
    elif [[ $ID == "opensuse-tumbleweed" ]]; then
        sudo zypper -n in git imobiledevice-tools libusbmuxd-tools libimobiledevice libpng12-0 libopenssl1_0_0 python-base
        ln -sf /usr/lib64/libzip.so.5 ../resources/lib/libzip.so.4
    
    elif [[ $platform == "macos" ]]; then
        xcode-select --install
        libimobiledevice=("https://github.com/libimobiledevice-win32/imobiledevice-net/releases/download/v1.3.17/libimobiledevice.1.2.1-r1122-osx-x64.zip" "d4202fbc4612bb3ef48f60f82799f517b210ac02")
    
    else
        Error "Distro not detected/supported by the install script." "See the repo README for supported OS versions/distros"
    fi
    
    if [[ $platform == "linux" ]]; then
        libimobiledevice=("https://github.com/LukeZGD/iOS-OTA-Downgrader-Keys/releases/download/tools/libimobiledevice_linux.zip" "4344b3ca95d7433d5a49dcacc840d47770ba34c4")
    fi
    
    if [[ ! -d ../resources/libimobiledevice_$platform ]]; then
        SaveFile ${libimobiledevice[0]} libimobiledevice.zip ${libimobiledevice[1]}
        mkdir ../resources/libimobiledevice_$platform
        unzip libimobiledevice.zip -d ../resources/libimobiledevice_$platform
        chmod +x ../resources/libimobiledevice_$platform/*
    fi
    
    cd ..
    Log "Install script done! Please run the script again to proceed"
    exit
}
