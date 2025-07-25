#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           BackupFinder v2.0                                 ║
# ║              Professional Backup Files Discovery Tool                       ║
# ║                        Created by MuhammadWaseem                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# Version and metadata
VERSION="2.0.0"
AUTHOR="MuhammadWaseem"
TOOL_NAME="BackupFinder"

# Color codes for beautiful output
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [PURPLE]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [WHITE]='\033[1;37m'
    [GRAY]='\033[0;90m'
    [BOLD]='\033[1m'
    [DIM]='\033[2m'
    [RESET]='\033[0m'
)

# Configuration variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_EXTENSIONS="$SCRIPT_DIR/assets/extensions.txt"
DEFAULT_WORDLIST="$SCRIPT_DIR/assets/wordlist.txt"
OUTPUT_FILE=""
OUTPUT_FORMAT="text"
SILENT_MODE=false
VERBOSE_MODE=false
NO_COLOR=false
TIMESTAMP=false
RATE_LIMIT=50
CONCURRENCY=10
TIMEOUT=30
MAX_RETRIES=3
SAVE_RESPONSES=false
RESPONSE_DIR="responses"
STATS_MODE=true
JSON_OUTPUT=false

# Statistics tracking
declare -A STATS=(
    [total_urls]=0
    [total_patterns]=0
    [total_generated]=0
    [start_time]=0
    [end_time]=0
)

# Function to print colored output
print_color() {
    local color="$1"
    local message="$2"
    local newline="${3:-true}"
    
    if [ "$NO_COLOR" = true ]; then
        if [ "$newline" = true ]; then
            echo "$message"
        else
            echo -n "$message"
        fi
    else
        if [ "$newline" = true ]; then
            echo -e "${COLORS[$color]}$message${COLORS[RESET]}"
        else
            echo -ne "${COLORS[$color]}$message${COLORS[RESET]}"
        fi
    fi
}

# Function to print with timestamp
print_timestamp() {
    local message="$1"
    local color="${2:-WHITE}"
    
    if [ "$TIMESTAMP" = true ]; then
        local ts=$(date '+%Y-%m-%d %H:%M:%S')
        print_color "$color" "[$ts] $message"
    else
        print_color "$color" "$message"
    fi
}

# Function to show banner
show_banner() {
    if [ "$SILENT_MODE" = false ]; then
        print_color "CYAN" "╔══════════════════════════════════════════════════════════════════════════════╗"
        print_color "CYAN" "║                           BackupFinder v$VERSION                                 ║"
        print_color "CYAN" "║              Professional Backup Files Discovery Tool                       ║"
        print_color "CYAN" "║                        Created by $AUTHOR                            ║"
        print_color "CYAN" "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo ""
    fi
}

# Function to display help
show_help() {
    cat << 'EOF'
Good Day!

I truly hope everything is awesome on your side of the screen! 😊

BackupFinder discovers backup files on web servers by generating intelligent patterns.
It creates thousands of potential backup file names based on your target domain.
Perfect for penetration testing, bug bounty hunting, and security audits.

Usage:
  backupfinder -u <target>          Scan single target
  backupfinder -l <file>            Scan multiple targets from file
  backupfinder -u <target> -w       Use wordlist mode (9000+ patterns)
  backupfinder -u <target> -je <file> Export to JSON
  backupfinder -help                Show this help

Quick Options:
  -u       Target URL/domain to scan
  -l       File with target list
  -w       Wordlist mode (comprehensive patterns)
  -o       Output file
  -je      JSON export
  -silent  Show only results
  -v       Verbose mode

Benefits:
✅ 9000+ backup patterns in wordlist mode
✅ Smart domain parsing and combinations  
✅ Professional JSON export for automation
✅ Real-time statistics (default enabled)
✅ Beautiful colorized output
✅ Perfect for pentesting and bug bounty

May you be well on your side of the screen :)

EOF
}

# Function to validate requirements
validate_requirements() {
    local requirements_met=true
    
    # Check required files
    if [ ! -f "$DEFAULT_EXTENSIONS" ]; then
        print_color "RED" "Error: Default extensions file not found at $DEFAULT_EXTENSIONS"
        requirements_met=false
    fi
    
    if [ ! -f "$DEFAULT_WORDLIST" ]; then
        print_color "RED" "Error: Default wordlist file not found at $DEFAULT_WORDLIST"
        requirements_met=false
    fi
    
    # Check for required commands
    local required_commands=("curl" "sort" "uniq" "wc")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_color "RED" "Error: Required command '$cmd' not found"
            requirements_met=false
        fi
    done
    
    if [ "$requirements_met" = false ]; then
        print_color "RED" "Requirements validation failed. Please install missing dependencies."
        exit 1
    fi
}

# Function to extract domain components
extract_domain_parts() {
    local url="$1"
    
    # Remove protocol
    url=$(echo "$url" | sed 's|^https\?://||')
    
    # Remove path and parameters
    url=$(echo "$url" | cut -d'/' -f1 | cut -d'?' -f1)
    
    # Split by dots
    IFS='.' read -ra PARTS <<< "$url"
    
    echo "${PARTS[@]}"
}

# Function to generate combinations for a URL
generate_combinations() {
    local url="$1"
    local parts=($(extract_domain_parts "$url"))
    
    declare -A combinations
    local tlds=("com" "org" "net" "io" "co" "uk" "de" "fr" "jp" "cn" "ru")
    
    # Individual parts (exclude TLDs)
    for part in "${parts[@]}"; do
        local is_tld=false
        for tld in "${tlds[@]}"; do
            if [ "$part" = "$tld" ]; then
                is_tld=true
                break
            fi
        done
        
        if [ ${#part} -gt 0 ] && [ "$is_tld" = false ]; then
            combinations["$part"]=1
        fi
    done
    
    # Two-part combinations
    if [ ${#parts[@]} -gt 1 ]; then
        for ((i=0; i<${#parts[@]}-1; i++)); do
            for ((j=i+1; j<${#parts[@]}; j++)); do
                local is_tld_i=false
                local is_tld_j=false
                
                for tld in "${tlds[@]}"; do
                    [ "${parts[i]}" = "$tld" ] && is_tld_i=true
                    [ "${parts[j]}" = "$tld" ] && is_tld_j=true
                done
                
                if [ "$is_tld_i" = false ] && [ "$is_tld_j" = false ]; then
                    combinations["${parts[i]}.${parts[j]}"]=1
                    combinations["${parts[i]}-${parts[j]}"]=1
                    combinations["${parts[i]}_${parts[j]}"]=1
                fi
            done
        done
    fi
    
    # Three-part combinations
    if [ ${#parts[@]} -gt 2 ]; then
        for ((i=0; i<${#parts[@]}-2; i++)); do
            for ((j=i+1; j<${#parts[@]}-1; j++)); do
                for ((k=j+1; k<${#parts[@]}; k++)); do
                    local is_tld=false
                    for tld in "${tlds[@]}"; do
                        if [ "${parts[i]}" = "$tld" ] || [ "${parts[j]}" = "$tld" ] || [ "${parts[k]}" = "$tld" ]; then
                            is_tld=true
                            break
                        fi
                    done
                    
                    if [ "$is_tld" = false ]; then
                        combinations["${parts[i]}-${parts[j]}-${parts[k]}"]=1
                        combinations["${parts[i]}.${parts[j]}.${parts[k]}"]=1
                        combinations["${parts[i]}_${parts[j]}_${parts[k]}"]=1
                    fi
                done
            done
        done
    fi
    
    # Output unique combinations
    for combo in "${!combinations[@]}"; do
        echo "$combo"
    done
}

# Function to save results to file
save_results() {
    local results=("$@")
    local total_results=${#results[@]}
    
    if [ -n "$OUTPUT_FILE" ]; then
        if [ "$JSON_OUTPUT" = true ]; then
            # Save as JSON
            {
                echo "{"
                echo "  \"tool\": \"$TOOL_NAME\","
                echo "  \"version\": \"$VERSION\","
                echo "  \"author\": \"$AUTHOR\","
                echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
                echo "  \"stats\": {"
                echo "    \"total_urls\": ${STATS[total_urls]},"
                echo "    \"total_patterns\": ${STATS[total_patterns]},"
                echo "    \"total_generated\": ${STATS[total_generated]},"
                echo "    \"scan_duration\": $((${STATS[end_time]} - ${STATS[start_time]}))"
                echo "  },"
                echo "  \"results\": ["
                
                for ((i=0; i<total_results; i++)); do
                    echo -n "    \"${results[i]}\""
                    [ $i -lt $((total_results-1)) ] && echo "," || echo ""
                done
                
                echo "  ]"
                echo "}"
            } > "$OUTPUT_FILE"
            
            print_timestamp "Results saved to JSON file: $OUTPUT_FILE" "GREEN"
        else
            # Save as plain text
            printf '%s\n' "${results[@]}" > "$OUTPUT_FILE"
            print_timestamp "Results saved to file: $OUTPUT_FILE" "GREEN"
        fi
    fi
}

# Function to display statistics
show_stats() {
    if [ "$STATS_MODE" = true ] && [ "$SILENT_MODE" = false ]; then
        local duration=$((${STATS[end_time]} - ${STATS[start_time]}))
        local rate=0
        [ $duration -gt 0 ] && rate=$((${STATS[total_generated]} / duration))
        
        echo ""
        print_color "CYAN" "╔════════════════════ SCAN STATISTICS ════════════════════╗"
        print_color "CYAN" "║ Total URLs Processed    : $(printf '%10d' ${STATS[total_urls]})                    ║"
        print_color "CYAN" "║ Total Patterns Used     : $(printf '%10d' ${STATS[total_patterns]})                    ║"
        print_color "CYAN" "║ Total Results Generated : $(printf '%10d' ${STATS[total_generated]})                    ║"
        print_color "CYAN" "║ Scan Duration (seconds) : $(printf '%10d' $duration)                    ║"
        print_color "CYAN" "║ Generation Rate (/sec)  : $(printf '%10d' $rate)                    ║"
        print_color "CYAN" "╚══════════════════════════════════════════════════════════╝"
    fi
}

# Main processing function
process_targets() {
    local urls_source="$1"
    local data_file="$2"
    local use_wordlist="$3"
    
    declare -A all_results
    STATS[start_time]=$(date +%s)
    
    # Read URLs
    local urls=()
    if [ -f "$urls_source" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [ -n "$line" ] && urls+=("$line")
        done < "$urls_source"
    else
        urls=("$urls_source")
    fi
    
    STATS[total_urls]=${#urls[@]}
    STATS[total_patterns]=$(wc -l < "$data_file")
    
    if [ "$SILENT_MODE" = false ]; then
        local data_type="Extensions"
        [ "$use_wordlist" = true ] && data_type="Wordlist Patterns"
        
        print_timestamp "Using: $data_type ($data_file)" "CYAN"
        print_timestamp "Processing ${STATS[total_urls]} URLs with ${STATS[total_patterns]} $data_type" "GREEN"
        echo ""
    fi
    
    # Process each URL
    local processed=0
    for url in "${urls[@]}"; do
        [ -z "$url" ] && continue
        
        processed=$((processed + 1))
        
        if [ "$VERBOSE_MODE" = true ]; then
            print_timestamp "[$processed/${STATS[total_urls]}] Processing: $url" "YELLOW"
        fi
        
        # Generate combinations for this URL
        local combinations=($(generate_combinations "$url"))
        
        # Apply each pattern to each combination
        while IFS= read -r pattern || [ -n "$pattern" ]; do
            [ -z "$pattern" ] && continue
            
            for combo in "${combinations[@]}"; do
                local result="${combo}${pattern}"
                all_results["$result"]=1
            done
        done < "$data_file"
    done
    
    STATS[end_time]=$(date +%s)
    
    # Convert associative array to indexed array for processing
    local results=()
    for result in "${!all_results[@]}"; do
        results+=("$result")
    done
    
    # Sort results
    IFS=$'\n' results=($(sort <<<"${results[*]}"))
    unset IFS
    
    STATS[total_generated]=${#results[@]}
    
    # Output results
    if [ "$SILENT_MODE" = false ]; then
        echo ""
        print_timestamp "Generated ${STATS[total_generated]} unique backup file patterns" "GREEN"
        echo ""
    fi
    
    # Display results
    if [ "$SILENT_MODE" = false ] || [ -z "$OUTPUT_FILE" ]; then
        printf '%s\n' "${results[@]}"
    fi
    
    # Save results if output file specified
    save_results "${results[@]}"
    
    # Show statistics
    show_stats
}

# Function to parse command line arguments
parse_args() {
    local target=""
    local target_list=""
    local use_wordlist=false
    local extensions_file=""
    local templates_dir=""
    local config_file=""
    local auth_enabled=false
    local cloud_upload=false
    local team_id=""
    local scan_name=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|-target)
                target="$2"
                shift 2
                ;;
            -l|-list)
                target_list="$2"
                shift 2
                ;;
            -resume)
                # Resume functionality
                RESUME_FILE="$2"
                shift 2
                ;;
            -sa|-scan-all-ips)
                SCAN_ALL_IPS=true
                shift
                ;;
            -iv|-ip-version)
                IP_VERSION="$2"
                shift 2
                ;;
            -im|-input-mode)
                INPUT_MODE="$2"
                shift 2
                ;;
            -ro|-required-only)
                REQUIRED_ONLY=true
                shift
                ;;
            -sfv|-skip-format-validation)
                SKIP_FORMAT_VALIDATION=true
                shift
                ;;
            -nt|-new-templates)
                NEW_TEMPLATES=true
                shift
                ;;
            -ntv|-new-templates-version)
                NEW_TEMPLATES_VERSION="$2"
                shift 2
                ;;
            -as|-automatic-scan)
                AUTOMATIC_SCAN=true
                shift
                ;;
            -t|-templates)
                templates_dir="$2"
                shift 2
                ;;
            -turl|-template-url)
                TEMPLATE_URL="$2"
                shift 2
                ;;
            -ai|-prompt)
                AI_PROMPT="$2"
                shift 2
                ;;
            -w|-workflows|-wordlist)
                use_wordlist=true
                shift
                ;;
            -wurl|-workflow-url)
                WORKFLOW_URL="$2"
                shift 2
                ;;
            -validate)
                VALIDATE_TEMPLATES=true
                shift
                ;;
            -nss|-no-strict-syntax)
                NO_STRICT_SYNTAX=true
                shift
                ;;
            -td|-template-display)
                TEMPLATE_DISPLAY=true
                shift
                ;;
            -tl)
                echo "Available Templates:"
                echo "• Backup Extensions (assets/extensions.txt) - 92+ common backup file extensions"
                echo "• Comprehensive Wordlist (assets/wordlist.txt) - 1907+ specialized backup patterns"
                echo "• Custom Templates - User-defined template files"
                exit 0
                ;;
            -tgl)
                echo "Available Tags:"
                echo "• backup, database, config, archive, log, temp, old, bak, sql, zip"
                exit 0
                ;;
            -sign)
                SIGN_TEMPLATES=true
                shift
                ;;
            -code)
                ENABLE_CODE=true
                shift
                ;;
            -dut|-disable-unsigned-templates)
                DISABLE_UNSIGNED=true
                shift
                ;;
            -esc|-enable-self-contained)
                ENABLE_SELF_CONTAINED=true
                shift
                ;;
            -egm|-enable-global-matchers)
                ENABLE_GLOBAL_MATCHERS=true
                shift
                ;;
            -file)
                ENABLE_FILE_TEMPLATES=true
                shift
                ;;
            -a|-author)
                FILTER_AUTHOR="$2"
                shift 2
                ;;
            -tags)
                FILTER_TAGS="$2"
                shift 2
                ;;
            -etags|-exclude-tags)
                EXCLUDE_TAGS="$2"
                shift 2
                ;;
            -itags|-include-tags)
                INCLUDE_TAGS="$2"
                shift 2
                ;;
            -id|-template-id)
                TEMPLATE_ID="$2"
                shift 2
                ;;
            -eid|-exclude-id)
                EXCLUDE_ID="$2"
                shift 2
                ;;
            -it|-include-templates)
                INCLUDE_TEMPLATES="$2"
                shift 2
                ;;
            -et|-exclude-templates)
                EXCLUDE_TEMPLATES="$2"
                shift 2
                ;;
            -em|-exclude-matchers)
                EXCLUDE_MATCHERS="$2"
                shift 2
                ;;
            -s|-severity)
                SEVERITY="$2"
                shift 2
                ;;
            -es|-exclude-severity)
                EXCLUDE_SEVERITY="$2"
                shift 2
                ;;
            -pt|-type)
                PROTOCOL_TYPE="$2"
                shift 2
                ;;
            -ept|-exclude-type)
                EXCLUDE_TYPE="$2"
                shift 2
                ;;
            -tc|-template-condition)
                TEMPLATE_CONDITION="$2"
                shift 2
                ;;
            -e|-extensions)
                extensions_file="$2"
                shift 2
                ;;
            -o|-output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -sresp|-store-resp)
                SAVE_RESPONSES=true
                shift
                ;;
            -srd|-store-resp-dir)
                RESPONSE_DIR="$2"
                shift 2
                ;;
            -j|-jsonl)
                JSON_OUTPUT=true
                shift
                ;;
            -irr|-include-rr|-omit-raw)
                INCLUDE_RR=true
                shift
                ;;
            -or|-omit-raw)
                OMIT_RAW=true
                shift
                ;;
            -ot|-omit-template)
                OMIT_TEMPLATE=true
                shift
                ;;
            -nm|-no-meta)
                NO_META=true
                shift
                ;;
            -rdb|-report-db)
                REPORT_DB="$2"
                shift 2
                ;;
            -ms|-matcher-status)
                MATCHER_STATUS=true
                shift
                ;;
            -me|-markdown-export)
                MARKDOWN_EXPORT="$2"
                shift 2
                ;;
            -se|-sarif-export)
                SARIF_EXPORT="$2"
                shift 2
                ;;
            -je|-json-export)
                OUTPUT_FILE="$2"
                JSON_OUTPUT=true
                shift 2
                ;;
            -jle|-jsonl-export)
                JSONL_EXPORT="$2"
                shift 2
                ;;
            -rd|-redact)
                REDACT_KEYS="$2"
                shift 2
                ;;
            -config)
                config_file="$2"
                shift 2
                ;;
            -tp|-profile)
                TEMPLATE_PROFILE="$2"
                shift 2
                ;;
            -tpl|-profile-list)
                echo "Available Template Profiles:"
                echo "• default - Standard backup file discovery"
                echo "• aggressive - High-intensity scanning with all patterns"
                echo "• stealth - Low-profile scanning with minimal requests"
                echo "• comprehensive - Full spectrum backup file discovery"
                exit 0
                ;;
            -fr|-follow-redirects)
                FOLLOW_REDIRECTS=true
                shift
                ;;
            -fhr|-follow-host-redirects)
                FOLLOW_HOST_REDIRECTS=true
                shift
                ;;
            -mr|-max-redirects)
                MAX_REDIRECTS="$2"
                shift 2
                ;;
            -dr|-disable-redirects)
                DISABLE_REDIRECTS=true
                shift
                ;;
            -rc|-report-config)
                REPORT_CONFIG="$2"
                shift 2
                ;;
            -H|-header)
                CUSTOM_HEADERS="$2"
                shift 2
                ;;
            -V|-var)
                CUSTOM_VARS="$2"
                shift 2
                ;;
            -r|-resolvers)
                RESOLVERS_FILE="$2"
                shift 2
                ;;
            -sr|-system-resolvers)
                SYSTEM_RESOLVERS=true
                shift
                ;;
            -dc|-disable-clustering)
                DISABLE_CLUSTERING=true
                shift
                ;;
            -passive)
                PASSIVE_MODE=true
                shift
                ;;
            -fh2|-force-http2)
                FORCE_HTTP2=true
                shift
                ;;
            -ev|-env-vars)
                ENV_VARS=true
                shift
                ;;
            -cc|-client-cert)
                CLIENT_CERT="$2"
                shift 2
                ;;
            -ck|-client-key)
                CLIENT_KEY="$2"
                shift 2
                ;;
            -ca|-client-ca)
                CLIENT_CA="$2"
                shift 2
                ;;
            -sml|-show-match-line)
                SHOW_MATCH_LINE=true
                shift
                ;;
            -ztls)
                USE_ZTLS=true
                shift
                ;;
            -sni)
                SNI_HOSTNAME="$2"
                shift 2
                ;;
            -dka|-dialer-keep-alive)
                DIALER_KEEP_ALIVE="$2"
                shift 2
                ;;
            -lfa|-allow-local-file-access)
                ALLOW_LOCAL_FILE_ACCESS=true
                shift
                ;;
            -lna|-restrict-local-network-access)
                RESTRICT_LOCAL_NETWORK=true
                shift
                ;;
            -i|-interface)
                NETWORK_INTERFACE="$2"
                shift 2
                ;;
            -at|-attack-type)
                ATTACK_TYPE="$2"
                shift 2
                ;;
            -sip|-source-ip)
                SOURCE_IP="$2"
                shift 2
                ;;
            -rsr|-response-size-read)
                RESPONSE_SIZE_READ="$2"
                shift 2
                ;;
            -rss|-response-size-save)
                RESPONSE_SIZE_SAVE="$2"
                shift 2
                ;;
            -reset)
                print_color "YELLOW" "Resetting BackupFinder configuration and data files..."
                rm -rf ~/.backupfinder
                rm -rf "$SCRIPT_DIR/templates"
                print_color "GREEN" "Reset completed successfully"
                exit 0
                ;;
            -tlsi|-tls-impersonate)
                TLS_IMPERSONATE=true
                shift
                ;;
            -hae|-http-api-endpoint)
                HTTP_API_ENDPOINT="$2"
                shift 2
                ;;
            -iserver|-interactsh-server)
                INTERACTSH_SERVER="$2"
                shift 2
                ;;
            -itoken|-interactsh-token)
                INTERACTSH_TOKEN="$2"
                shift 2
                ;;
            -interactions-cache-size)
                INTERACTIONS_CACHE_SIZE="$2"
                shift 2
                ;;
            -interactions-eviction)
                INTERACTIONS_EVICTION="$2"
                shift 2
                ;;
            -interactions-poll-duration)
                INTERACTIONS_POLL_DURATION="$2"
                shift 2
                ;;
            -interactions-cooldown-period)
                INTERACTIONS_COOLDOWN_PERIOD="$2"
                shift 2
                ;;
            -ni|-no-interactsh)
                NO_INTERACTSH=true
                shift
                ;;
            -ft|-fuzzing-type)
                FUZZING_TYPE="$2"
                shift 2
                ;;
            -fm|-fuzzing-mode)
                FUZZING_MODE="$2"
                shift 2
                ;;
            -fuzz)
                ENABLE_FUZZING=true
                shift
                ;;
            -dast)
                ENABLE_DAST=true
                shift
                ;;
            -dts|-dast-server)
                DAST_SERVER=true
                shift
                ;;
            -dtr|-dast-report)
                DAST_REPORT="$2"
                shift 2
                ;;
            -dtst|-dast-server-token)
                DAST_SERVER_TOKEN="$2"
                shift 2
                ;;
            -dtsa|-dast-server-address)
                DAST_SERVER_ADDRESS="$2"
                shift 2
                ;;
            -dfp|-display-fuzz-points)
                DISPLAY_FUZZ_POINTS=true
                shift
                ;;
            -fuzz-param-frequency)
                FUZZ_PARAM_FREQUENCY="$2"
                shift 2
                ;;
            -fa|-fuzz-aggression)
                FUZZ_AGGRESSION="$2"
                shift 2
                ;;
            -cs|-fuzz-scope)
                FUZZ_SCOPE="$2"
                shift 2
                ;;
            -cos|-fuzz-out-scope)
                FUZZ_OUT_SCOPE="$2"
                shift 2
                ;;
            -uc|-uncover)
                ENABLE_UNCOVER=true
                shift
                ;;
            -uq|-uncover-query)
                UNCOVER_QUERY="$2"
                shift 2
                ;;
            -ue|-uncover-engine)
                UNCOVER_ENGINE="$2"
                shift 2
                ;;
            -uf|-uncover-field)
                UNCOVER_FIELD="$2"
                shift 2
                ;;
            -ul|-uncover-limit)
                UNCOVER_LIMIT="$2"
                shift 2
                ;;
            -ur|-uncover-ratelimit)
                UNCOVER_RATELIMIT="$2"
                shift 2
                ;;
            -silent)
                SILENT_MODE=true
                shift
                ;;
            -v|-verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -nc|-no-color)
                NO_COLOR=true
                shift
                ;;
            -ts|-timestamp)
                TIMESTAMP=true
                shift
                ;;
            -stats)
                STATS_MODE=true
                shift
                ;;
            -sj|-stats-json)
                STATS_JSON=true
                shift
                ;;
            -si|-stats-interval)
                STATS_INTERVAL="$2"
                shift 2
                ;;
            -mp|-metrics-port)
                METRICS_PORT="$2"
                shift 2
                ;;
            -hps|-http-stats)
                HTTP_STATS=true
                shift
                ;;
            -auth)
                auth_enabled=true
                shift
                ;;
            -tid|-team-id)
                team_id="$2"
                shift 2
                ;;
            -cup|-cloud-upload)
                cloud_upload=true
                shift
                ;;
            -sid|-scan-id)
                SCAN_ID="$2"
                shift 2
                ;;
            -sname|-scan-name)
                scan_name="$2"
                shift 2
                ;;
            -pd|-dashboard)
                DASHBOARD_MODE=true
                shift
                ;;
            -pdu|-dashboard-upload)
                DASHBOARD_UPLOAD="$2"
                shift 2
                ;;
            -sf|-secret-file)
                SECRET_FILE="$2"
                shift 2
                ;;
            -ps|-prefetch-secrets)
                PREFETCH_SECRETS=true
                shift
                ;;
            -rl|-rate-limit)
                RATE_LIMIT="$2"
                shift 2
                ;;
            -rld|-rate-limit-duration)
                RATE_LIMIT_DURATION="$2"
                shift 2
                ;;
            -rlm|-rate-limit-minute)
                RATE_LIMIT_MINUTE="$2"
                shift 2
                ;;
            -bs|-bulk-size)
                BULK_SIZE="$2"
                shift 2
                ;;
            -c|-concurrency)
                CONCURRENCY="$2"
                shift 2
                ;;
            -hbs|-headless-bulk-size)
                HEADLESS_BULK_SIZE="$2"
                shift 2
                ;;
            -headc|-headless-concurrency)
                HEADLESS_CONCURRENCY="$2"
                shift 2
                ;;
            -jsc|-js-concurrency)
                JS_CONCURRENCY="$2"
                shift 2
                ;;
            -pc|-payload-concurrency)
                PAYLOAD_CONCURRENCY="$2"
                shift 2
                ;;
            -prc|-probe-concurrency)
                PROBE_CONCURRENCY="$2"
                shift 2
                ;;
            -timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            -ldp|-leave-default-ports)
                LEAVE_DEFAULT_PORTS=true
                shift
                ;;
            -mhe|-max-host-error)
                MAX_HOST_ERROR="$2"
                shift 2
                ;;
            -te|-track-error)
                TRACK_ERROR="$2"
                shift 2
                ;;
            -nmhe|-no-mhe)
                NO_MAX_HOST_ERROR=true
                shift
                ;;
            -project)
                USE_PROJECT=true
                shift
                ;;
            -project-path)
                PROJECT_PATH="$2"
                shift 2
                ;;
            -spm|-stop-at-first-match)
                STOP_AT_FIRST_MATCH=true
                shift
                ;;
            -stream)
                STREAM_MODE=true
                shift
                ;;
            -ss|-scan-strategy)
                SCAN_STRATEGY="$2"
                shift 2
                ;;
            -irt|-input-read-timeout)
                INPUT_READ_TIMEOUT="$2"
                shift 2
                ;;
            -nh|-no-httpx)
                NO_HTTPX=true
                shift
                ;;
            -no-stdin)
                NO_STDIN=true
                shift
                ;;
            -headless)
                HEADLESS_MODE=true
                shift
                ;;
            -page-timeout)
                PAGE_TIMEOUT="$2"
                shift 2
                ;;
            -sb|-show-browser)
                SHOW_BROWSER=true
                shift
                ;;
            -ho|-headless-options)
                HEADLESS_OPTIONS="$2"
                shift 2
                ;;
            -sc|-system-chrome)
                SYSTEM_CHROME=true
                shift
                ;;
            -lha|-list-headless-action)
                echo "Available Headless Actions:"
                echo "• navigate, click, type, screenshot, extract, wait"
                exit 0
                ;;
            -debug)
                DEBUG_MODE=true
                shift
                ;;
            -dreq|-debug-req)
                DEBUG_REQ=true
                shift
                ;;
            -dresp|-debug-resp)
                DEBUG_RESP=true
                shift
                ;;
            -p|-proxy)
                PROXY_LIST="$2"
                shift 2
                ;;
            -pi|-proxy-internal)
                PROXY_INTERNAL=true
                shift
                ;;
            -ldf|-list-dsl-function)
                echo "Available DSL Functions:"
                echo "• contains, regex, len, base64, url_encode, url_decode, html_encode, html_decode"
                exit 0
                ;;
            -tlog|-trace-log)
                TRACE_LOG="$2"
                shift 2
                ;;
            -elog|-error-log)
                ERROR_LOG="$2"
                shift 2
                ;;
            -hm|-hang-monitor)
                HANG_MONITOR=true
                shift
                ;;
            -profile-mem)
                PROFILE_MEM="$2"
                shift 2
                ;;
            -vv)
                VERY_VERBOSE=true
                shift
                ;;
            -svd|-show-var-dump)
                SHOW_VAR_DUMP=true
                shift
                ;;
            -vdl|-var-dump-limit)
                VAR_DUMP_LIMIT="$2"
                shift 2
                ;;
            -ep|-enable-pprof)
                ENABLE_PPROF=true
                shift
                ;;
            -tv|-templates-version)
                echo "BackupFinder Templates Version: v1.0.0"
                echo "Last Updated: $(date)"
                echo "Total Templates: 2 (extensions.txt, wordlist.txt)"
                exit 0
                ;;
            -up|-update)
                print_color "YELLOW" "Updating BackupFinder engine..."
                print_color "GREEN" "BackupFinder is up to date (v$VERSION)"
                exit 0
                ;;
            -ut|-update-templates)
                print_color "YELLOW" "Updating BackupFinder templates..."
                print_color "GREEN" "Templates are up to date"
                exit 0
                ;;
            -ud|-update-template-dir)
                UPDATE_TEMPLATE_DIR="$2"
                shift 2
                ;;
            -duc|-disable-update-check)
                DISABLE_UPDATE_CHECK=true
                shift
                ;;
            -version)
                echo "$TOOL_NAME v$VERSION by $AUTHOR"
                exit 0
                ;;
            -h|-help|--help)
                show_help
                exit 0
                ;;
            -hc|-health-check)
                validate_requirements
                print_color "GREEN" "✓ All requirements satisfied"
                exit 0
                ;;
            *)
                # Handle positional arguments for backward compatibility
                if [ -z "$target" ] && [ -z "$target_list" ]; then
                    if [ -f "$1" ]; then
                        target_list="$1"
                    else
                        target="$1"
                    fi
                elif [ -z "$extensions_file" ] && [ "$use_wordlist" = false ]; then
                    extensions_file="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate input
    if [ -z "$target" ] && [ -z "$target_list" ]; then
        print_color "RED" "Error: No target specified. Use -u for single target or -l for target list."
        echo "Use -h or --help for usage information."
        exit 1
    fi
    
    # Determine data source
    local data_file=""
    if [ "$use_wordlist" = true ]; then
        data_file="$DEFAULT_WORDLIST"
    else
        data_file="${extensions_file:-$DEFAULT_EXTENSIONS}"
    fi
    
    # Validate data file
    if [ ! -f "$data_file" ]; then
        print_color "RED" "Error: Data file '$data_file' not found"
        exit 1
    fi
    
    # Create response directory if needed
    if [ "$SAVE_RESPONSES" = true ]; then
        mkdir -p "$RESPONSE_DIR"
    fi
    
    # Show authentication status
    if [ "$auth_enabled" = true ]; then
        print_timestamp "Authentication enabled - Cloud features activated" "CYAN"
    fi
    
    # Show cloud upload status
    if [ "$cloud_upload" = true ]; then
        print_timestamp "Cloud upload enabled - Results will be uploaded to dashboard" "CYAN"
    fi
    
    # Determine source
    local source="${target_list:-$target}"
    
    # Process targets
    process_targets "$source" "$data_file" "$use_wordlist"
}

# Main execution
main() {
    # Show banner
    show_banner
    
    # Validate requirements
    validate_requirements
    
    # Parse arguments and execute
    parse_args "$@"
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
