#!/bin/bash
# ============================================================================
# Claude Code Environment - Save / Load Docker Image
# ============================================================================
# Usage:
#   Save:  ./save-image.sh save [output_file]
#   Load:  ./save-image.sh load [input_file]
#   Info:  ./save-image.sh info [image_file]
# ============================================================================

set -e

IMAGE_NAME="claude-code-env"
IMAGE_TAG="latest"
IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"
DEFAULT_FILE="${IMAGE_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  Claude Code Environment - Image Manager${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

print_usage() {
    print_header
    echo "Usage: $0 <command> [file]"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}save${NC} [file]    Save the Docker image to a compressed tar file"
    echo -e "  ${GREEN}load${NC} <file>    Load a Docker image from a tar file"
    echo -e "  ${GREEN}info${NC} [file]    Show info about the image or a saved file"
    echo ""
    echo "Examples:"
    echo "  $0 save                              # Save with auto-generated filename"
    echo "  $0 save claude-code-env_backup.tar.gz"
    echo "  $0 load claude-code-env_20260305.tar.gz"
    echo "  $0 info                              # Show current image info"
    echo "  $0 info claude-code-env_backup.tar.gz # Show file info"
    echo ""
}

# ---- SAVE ----
cmd_save() {
    local output_file="${1:-${DEFAULT_FILE}}"

    # Ensure .tar.gz extension
    if [[ "${output_file}" != *.tar.gz ]] && [[ "${output_file}" != *.tgz ]]; then
        output_file="${output_file}.tar.gz"
    fi

    print_header
    echo -e "${CYAN}Saving image:${NC} ${IMAGE_FULL}"
    echo -e "${CYAN}Output file:${NC}  ${output_file}"
    echo ""

    # Check image exists
    if ! docker image inspect "${IMAGE_FULL}" &>/dev/null; then
        echo -e "${RED}✗ Error: Image '${IMAGE_FULL}' not found.${NC}"
        echo "  Build it first with: docker build -t ${IMAGE_FULL} ."
        exit 1
    fi

    # Get image size
    local image_size
    image_size=$(docker image inspect "${IMAGE_FULL}" --format='{{.Size}}' 2>/dev/null)
    local image_size_mb=$((image_size / 1024 / 1024))
    echo -e "  Image size: ${YELLOW}${image_size_mb} MB${NC} (uncompressed)"
    echo -e "  Saving and compressing... (this may take a few minutes)"
    echo ""

    # Save with gzip compression
    local start_time
    start_time=$(date +%s)

    docker save "${IMAGE_FULL}" | gzip -9 > "${output_file}"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Get output file size
    local file_size
    file_size=$(stat -c%s "${output_file}" 2>/dev/null || stat -f%z "${output_file}" 2>/dev/null)
    local file_size_mb=$((file_size / 1024 / 1024))
    local ratio=$((file_size * 100 / image_size))

    echo -e "${GREEN}✓ Image saved successfully!${NC}"
    echo ""
    echo "  File:             ${output_file}"
    echo "  Compressed size:  ${file_size_mb} MB (${ratio}% of original)"
    echo "  Duration:         ${duration}s"
    echo ""
    echo -e "  ${YELLOW}To load on another machine:${NC}"
    echo "  1. Copy '${output_file}' to the target machine"
    echo "  2. Run:  ./save-image.sh load ${output_file}"
    echo "     or:   docker load < <(gunzip -c ${output_file})"
    echo ""
}

# ---- LOAD ----
cmd_load() {
    local input_file="$1"

    if [ -z "${input_file}" ]; then
        echo -e "${RED}✗ Error: No input file specified.${NC}"
        echo "  Usage: $0 load <file.tar.gz>"
        exit 1
    fi

    print_header
    echo -e "${CYAN}Loading image from:${NC} ${input_file}"
    echo ""

    # Check file exists
    if [ ! -f "${input_file}" ]; then
        echo -e "${RED}✗ Error: File '${input_file}' not found.${NC}"
        exit 1
    fi

    # Get file size
    local file_size
    file_size=$(stat -c%s "${input_file}" 2>/dev/null || stat -f%z "${input_file}" 2>/dev/null)
    local file_size_mb=$((file_size / 1024 / 1024))
    echo "  File size: ${file_size_mb} MB"
    echo "  Decompressing and loading... (this may take a few minutes)"
    echo ""

    local start_time
    start_time=$(date +%s)

    # Detect if gzipped or plain tar
    local loaded_image
    if file "${input_file}" | grep -q "gzip"; then
        loaded_image=$(gunzip -c "${input_file}" | docker load 2>&1)
    else
        loaded_image=$(docker load -i "${input_file}" 2>&1)
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo -e "${GREEN}✓ Image loaded successfully!${NC}"
    echo ""
    echo "  ${loaded_image}"
    echo "  Duration: ${duration}s"
    echo ""

    # Show the loaded image
    echo "  Loaded image:"
    docker images "${IMAGE_NAME}" --format "  {{.Repository}}:{{.Tag}}  {{.Size}}  ({{.ID}})"
    echo ""
    echo -e "  ${YELLOW}Ready to run:${NC}  ./run.sh start"
    echo ""
}

# ---- INFO ----
cmd_info() {
    local file="$1"

    print_header

    if [ -n "${file}" ] && [ -f "${file}" ]; then
        # Show file info
        local file_size
        file_size=$(stat -c%s "${file}" 2>/dev/null || stat -f%z "${file}" 2>/dev/null)
        local file_size_mb=$((file_size / 1024 / 1024))
        local file_date
        file_date=$(stat -c%y "${file}" 2>/dev/null | cut -d'.' -f1 || stat -f%Sm "${file}" 2>/dev/null)

        echo "Saved Image File:"
        echo "  File:     ${file}"
        echo "  Size:     ${file_size_mb} MB"
        echo "  Created:  ${file_date}"
        echo ""

        # Peek inside the tar to see image info
        echo "  Contents:"
        if file "${file}" | grep -q "gzip"; then
            gunzip -c "${file}" | docker load --quiet 2>/dev/null && \
                docker images "${IMAGE_NAME}" --format "    {{.Repository}}:{{.Tag}}  {{.Size}}  Created: {{.CreatedSince}}" || \
                echo "    (cannot peek - load the image first to inspect)"
        fi
    else
        # Show current image info
        if docker image inspect "${IMAGE_FULL}" &>/dev/null; then
            echo "Current Docker Image:"
            docker images "${IMAGE_NAME}" --format "  {{.Repository}}:{{.Tag}}  {{.Size}}  Created: {{.CreatedSince}}  ID: {{.ID}}"
            echo ""
            echo "  Layers:"
            docker history "${IMAGE_FULL}" --format "    {{.Size}}\t{{.CreatedBy}}" 2>/dev/null | head -15
        else
            echo -e "${YELLOW}Image '${IMAGE_FULL}' not found locally.${NC}"
            echo "  Build with: docker build -t ${IMAGE_FULL} ."
        fi
    fi
    echo ""
}

# ---- Main ----
case "${1:-}" in
    save)
        cmd_save "$2"
        ;;
    load)
        cmd_load "$2"
        ;;
    info)
        cmd_info "$2"
        ;;
    *)
        print_usage
        ;;
esac
