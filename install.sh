#!/data/data/com.termux/files/usr/bin/bash

center_banner() {
    local termwidth=$(stty size | cut -d" " -f2)
    local banner=(
        "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+",
        "|M|e|t|a|s|p|l|o|i|t| |i|n| |T|e|r|m|u|x|",
        "|B|y| |K|a|t|i|l|m|a|m|i|o|f|f|i|c|a|l|",
        "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
    )
    echo -e "\e[34m"
    for line in "${banner[@]}"; do
        printf "%*s\n" $(((termwidth + ${#line}) / 2)) "$line"
    done
    echo -e "\e[0m"
}

center() {
    local termwidth=$(stty size | cut -d" " -f2)
    local padding=$(printf '%0.1s' ={1..500})
    printf '%*.*s %s %*.*s\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" "$1" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}

spinner=("|" "/" "-" "\\")
spin() {
    while true; do
        for c in "${spinner[@]}"; do
            echo -ne "\r$c"
            sleep 0.2
        done
    done
}
start_spinner() { spin & SPIN_PID=$!; }
stop_spinner() { kill $SPIN_PID >/dev/null 2>&1 || true; wait $SPIN_PID 2>/dev/null || true; echo -ne "\r"; }

clear
center_banner

echo -e "\n\e[33mChoose an option:\e[0m"
echo -e "[1] Install Metasploit (Fresh)"
echo -e "[2] Update Metasploit (Existing)"
echo -e "[3] Remove Metasploit"
read -p $'\nSelection: ' secim

if [[ "$secim" == "1" || "$secim" == "2" ]]; then
    center "Starting process..."
    start_spinner

    if [[ "$secim" == "1" ]]; then
        center "* Installing dependencies..."
        pkg update -y
        pkg upgrade -y -o Dpkg::Options::="--force-confnew"
        pkg install -y binutils python autoconf bison clang coreutils curl findutils apr apr-util postgresql openssl readline libffi libgmp libpcap libsqlite libgrpc libtool libxml2 libxslt ncurses make ncurses-utils ncurses git wget unzip zip tar termux-tools termux-elf-cleaner pkg-config ruby -o Dpkg::Options::="--force-confnew"
        python3 -m pip install requests
        source <(curl -sL https://github.com/termux/termux-packages/files/2912002/fix-ruby-bigdecimal.sh.txt)
    fi

    center "* Removing old installation..."
    rm -rf ${PREFIX}/opt/metasploit-framework

    center "* Cloning Metasploit..."
    mkdir -p ${PREFIX}/opt
    RETRY=0; MAX_RETRIES=3
    until git clone https://github.com/rapid7/metasploit-framework.git --depth=1 ${PREFIX}/opt/metasploit-framework; do
        RETRY=$((RETRY+1))
        if [ $RETRY -ge $MAX_RETRIES ]; then
            stop_spinner
            echo -e "\e[31mClone failed after $MAX_RETRIES attempts.\e[0m"
            exit 1
        fi
        echo -e "\e[33mClone failed, retrying ($RETRY/$MAX_RETRIES)...\e[0m"
        sleep 2
    done

    center "* Setting up..."
    cd ${PREFIX}/opt/metasploit-framework

    gem install bundler

    if grep -q "nokogiri (" Gemfile.lock; then
        NOKOGIRI_VERSION=$(sed -n 's/.*nokogiri (\([0-9.]\+\)).*/\1/p' Gemfile.lock | head -1)
        gem install nokogiri -v "$NOKOGIRI_VERSION" -- --with-cflags="-Wno-implicit-function-declaration -Wno-deprecated-declarations -Wno-incompatible-function-pointer-types" --use-system-libraries
    else
        gem install nokogiri -- --with-cflags="-Wno-implicit-function-declaration -Wno-deprecated-declarations -Wno-incompatible-function-pointer-types" --use-system-libraries
    fi

    bundle install
    gem install actionpack
    bundle update activesupport
    bundle update --bundler
    bundle install -j$(nproc --all)

    center "* Creating symbolic links..."
    ln -sf ${PREFIX}/opt/metasploit-framework/msfconsole ${PREFIX}/bin/
    ln -sf ${PREFIX}/opt/metasploit-framework/msfvenom   ${PREFIX}/bin/
    ln -sf ${PREFIX}/opt/metasploit-framework/msfrpcd    ${PREFIX}/bin/

    center "* Installing msfupdate scripts..."
    rm -f ${PREFIX}/opt/metasploit-framework/msfupdate
    wget -O ${PREFIX}/opt/metasploit-framework/msfupdate https://raw.githubusercontent.com/katilmamioffical/metasploit-in-termux/main/msfupdate
    chmod +x ${PREFIX}/opt/metasploit-framework/msfupdate
    ln -sf ${PREFIX}/opt/metasploit-framework/msfupdate ${PREFIX}/bin/msfupdate

    wget -O ${PREFIX}/opt/metasploit-framework/msfupdate.sh https://raw.githubusercontent.com/katilmamioffical/metasploit-in-termux/main/msfupdate.sh
    chmod +x ${PREFIX}/opt/metasploit-framework/msfupdate.sh

    termux-elf-cleaner ${PREFIX}/lib/ruby/gems/*/gems/pg-*/lib/pg_ext.so 2>/dev/null

    stop_spinner
    echo -e "\033[32m"
    center "Installation complete"
    echo -e "\nRun: msfconsole to start Metasploit or msfupdate to update it."
    echo -e "\033[0m"

elif [[ "$secim" == "3" ]]; then
    center "* Removing Metasploit..."
    rm -rf ${PREFIX}/opt/metasploit-framework
    rm -f ${PREFIX}/bin/msfconsole ${PREFIX}/bin/msfvenom ${PREFIX}/bin/msfrpcd ${PREFIX}/bin/msfupdate
    echo -e "\e[32mMetasploit removed successfully.\e[0m"
    exit 0

else
    echo -e "\e[31mInvalid selection!\e[0m"
    exit 1
fi
