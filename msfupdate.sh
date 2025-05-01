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

spinner=( '|' '/' '-' '\\' )
spin(){ while true; do for c in "${spinner[@]}"; do echo -ne "\r$c"; sleep 0.2; done; done }
start_spinner(){ spin & SPIN_PID=$! }
stop_spinner(){ kill $SPIN_PID >/dev/null 2>&1; wait $SPIN_PID 2>/dev/null; echo -ne "\r" }

clear
center_banner

echo -n "Do you want to update Metasploit? [y/N] "
read -r answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Abort. No changes made."
    exit 0
fi

start_spinner

rm -rf ${PREFIX}/opt/metasploit-framework
mkdir -p ${PREFIX}/opt

git clone https://github.com/rapid7/metasploit-framework.git --depth=1 ${PREFIX}/opt/metasploit-framework || { stop_spinner; echo -e "\e[31mClone failed.\e[0m"; exit 1; }

cd ${PREFIX}/opt/metasploit-framework

gem install bundler

if grep -q "nokogiri (" Gemfile.lock; then
    ver=$(sed -n 's/.*nokogiri (\([0-9.]\+\)).*/\1/p' Gemfile.lock | head -1)
    gem install nokogiri -v "$ver" -- --with-cflags="-Wno-implicit-function-declaration -Wno-deprecated-declarations -Wno-incompatible-function-pointer-types" --use-system-libraries
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

stop_spinner
echo -e "\033[32mUpdate complete.\033[0m"
echo "Run 'msfconsole' to start or 'msfupdate' to apply future updates."
