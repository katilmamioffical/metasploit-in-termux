#!/data/data/com.termux/files/usr/bin/bash

center_banner() {
    local termwidth=$(stty size | cut -d" " -f2)
    local banner=(
        "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+",
        "|M|e|t|a|s|p|l|o|i|t| |i|n| |T|e|r|m|u|x|",
        "|B|y| |K|a|t|i|l|m|a|m|i|o|f|f|i|c|i|a|l|",
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

echo -ne "\nDo you want to update Metasploit? (y/n): "
read -r choice
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    echo -e "\e[33mUpdate canceled.\e[0m"
    exit 0
fi

center "Updating Metasploit..."
start_spinner
rm -rf ${PREFIX}/opt/metasploit-framework
mkdir -p ${PREFIX}/opt

RETRY=0
MAX_RETRIES=3
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

rm -f ${PREFIX}/opt/metasploit-framework/msfupdate
wget -O ${PREFIX}/opt/metasploit-framework/msfupdate https://raw.githubusercontent.com/katilmamioffical/metasploit-in-termux/main/msfupdate
chmod +x ${PREFIX}/opt/metasploit-framework/msfupdate
ln -sf ${PREFIX}/opt/metasploit-framework/msfupdate ${PREFIX}/bin/msfupdate
wget -O ${PREFIX}/opt/metasploit-framework/msfupdate.sh https://raw.githubusercontent.com/katilmamioffical/metasploit-in-termux/main/msfupdate.sh
chmod +x ${PREFIX}/opt/metasploit-framework/msfupdate.sh

termux-elf-cleaner ${PREFIX}/lib/ruby/gems/*/gems/pg-*/lib/pg_ext.so 2>/dev/null


ln -sf ${PREFIX}/opt/metasploit-framework/msfconsole ${PREFIX}/bin/
ln -sf ${PREFIX}/opt/metasploit-framework/msfvenom   ${PREFIX}/bin/
ln -sf ${PREFIX}/opt/metasploit-framework/msfrpcd    ${PREFIX}/bin/

stop_spinner
echo -e "\033[32m"
center "Update complete"
echo -e "\nRun: msfconsole to start, or msfupdate to update again."
echo -e "\033[0m"

