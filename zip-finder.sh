#!/bin/bash

# Define colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Banner
clear
echo -e "${MAGENTA}${BOLD}
    ███╗   ██╗ ██████╗  ██████╗ ██████╗     ██╗    ██╗ █████╗ ███████╗██╗
    ████╗  ██║██╔═══██╗██╔════╝ ██╔══██╗    ██║    ██║██╔══██╗██╔════╝██║
    ██╔██╗ ██║██║   ██║██║  ███╗██████╔╝    ██║ █╗ ██║███████║███████╗██║
    ██║╚██╗██║██║   ██║██║   ██║██╔═══╝     ██║███╗██║██╔══██║╚════██║██║
    ██║ ╚████║╚██████╔╝╚██████╔╝██║         ╚███╔███╔╝██║  ██║███████║███████╗
    ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝          ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝
${RESET}"
echo -e "${CYAN}${BOLD} 🚀 Noob-Wasi${RESET}"
echo -e "${GREEN}${BOLD} 👑 Created by Muhammad Waseem${RESET}"
echo

# Python Virtual Environment Setup
echo -e "${YELLOW}${BOLD}🔄 Setting up Python virtual environment...${RESET}"
python3 -m venv myenv
source myenv/bin/activate
pip install --quiet uro jq
echo -e "${GREEN}${BOLD}✅ Python environment ready!${RESET}\n"

# Prompt for the domain name
read -p "$(echo -e ${BLUE}${BOLD}"🌍 Enter the domain (e.g., example.com): "${RESET})" domain

# Fetch backup-related files
echo -e "\n${YELLOW}${BOLD}🔍 Searching for backup files on the Wayback Machine...${RESET}"
result=$(curl -s "https://web.archive.org/cdx/search/cdx?url=*.$domain/*&collapse=urlkey&output=text&fl=original" | \
grep -E '\.(zip|bak|tar|tar\.gz|tgz|7z|rar|sql|db|backup|old|gz|bz2)$')

if [[ -n "$result" ]]; then
    echo -e "${GREEN}${BOLD}🎯 Backup files found:${RESET}\n"
    
    while IFS= read -r url; do
        archive_data=$(curl -s "https://web.archive.org/cdx/search/cdx?url=$url&output=json")
        timestamp=$(echo "$archive_data" | jq -r '.[1][1]' 2>/dev/null)
        
        if [[ "$timestamp" != "null" && -n "$timestamp" ]]; then
            snapshot_link="https://web.archive.org/web/$timestamp/$url"
            echo -e "${CYAN}📁 $url ${GREEN}✅ (Snapshot Available) 🔗 $snapshot_link ${RESET}"
        else
            echo -e "${CYAN}📁 $url ${RED}❌ (No Snapshot)${RESET}"
        fi
    done <<< "$result"

else
    echo -e "${RED}${BOLD}❌ No backup files found.${RESET}"
fi

echo -e "\n${MAGENTA}${BOLD}🎉 Done!${RESET}"
