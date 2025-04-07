#!/bin/bash

# Function to check if we're in China using IP geolocation
check_if_in_china() {
    echo "Detecting location using IP geolocation..."
    
    # Use ip-api.com which provides a free geolocation API
    # This returns country code, no registration required
    COUNTRY_CODE=$(curl -s http://ip-api.com/line/?fields=countryCode)
    
    if [ "$COUNTRY_CODE" == "CN" ]; then
        echo "Location detected: China (Country Code: $COUNTRY_CODE)"
        return 0
    else
        echo "Location detected: Outside China (Country Code: $COUNTRY_CODE)"
        return 1
    fi
}

# Alternative function using ipinfo.io if preferred
check_if_in_china_alt() {
    echo "Detecting location using IP geolocation (alternative method)..."
    
    # Use ipinfo.io which provides country information
    COUNTRY_CODE=$(curl -s https://ipinfo.io/country)
    
    if [ "$COUNTRY_CODE" == "CN" ]; then
        echo "Location detected: China (Country Code: $COUNTRY_CODE)"
        return 0
    else
        echo "Location detected: Outside China (Country Code: $COUNTRY_CODE)"
        return 1
    fi
}

# Function to check for basic IPv6 support in the system
check_ipv6_system_support() {
    if [ -f /proc/net/if_inet6 ] && [ "$(cat /proc/net/if_inet6 | wc -l)" -ne 0 ]; then
        echo "IPv6 support detected in system"
        return 0
    else
        echo "No IPv6 support detected in system"
        return 1
    fi
}

# Function to check if IPv6 connectivity is working
check_ipv6_connectivity() {
    echo "Testing IPv6 connectivity..."
    
    # First check if ping6 or ping with -6 option is available
    if command -v ping6 &> /dev/null; then
        PING_CMD="ping6"
    elif ping -6 -c 1 ::1 &> /dev/null; then
        PING_CMD="ping -6"
    else
        echo "IPv6 ping tools not available"
        return 1
    fi
    
    # List of IPv6 addresses to test (Google, Cloudflare, and OpenDNS)
    IPV6_ADDRESSES=(
        "2001:4860:4860::8888"  # Google DNS
        "2606:4700:4700::1111"  # Cloudflare DNS
        "2620:119:35::35"       # OpenDNS
    )
    
    # Try each address until one succeeds
    for addr in "${IPV6_ADDRESSES[@]}"; do
        echo "Testing connectivity to $addr..."
        $PING_CMD -c 2 -W 3 $addr &> /dev/null
        if [ $? -eq 0 ]; then
            echo "IPv6 connectivity confirmed with $addr"
            return 0
        fi
    done
    
    echo "Could not establish IPv6 connectivity to any test servers"
    return 1
}

# Comprehensive function to check IPv6 support and connectivity
check_ipv6() {
    # First check system support
    if check_ipv6_system_support; then
        echo "Basic IPv6 system support verified"
        
        # Then check connectivity
        if check_ipv6_connectivity; then
            echo "IPv6 connectivity confirmed - full IPv6 support available"
            return 0
        else
            echo "System has IPv6 support but no external IPv6 connectivity"
            # We still return 0 because Docker can use IPv6 internally even without external connectivity
            # Change to return 1 if you want to require external connectivity
            return 0
        fi
    else
        echo "No IPv6 support detected in the system"
        return 1
    fi
}

# Function to install Docker for China
install_docker_china() {
    echo "Installing Docker with Aliyun mirror..."
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    
    echo "Creating Docker daemon configuration for China..."
    cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    },
    "experimental": true,
    "data-root": "/root/docker_data",
    "registry-mirrors": ["https://hub.sakiko.de", "https://docker.1ms.run"]
}
EOF
}

# Function to install Docker for international use
install_docker_international() {
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | bash -s docker

    has_ipv6=$(check_ipv6; echo $?)
    
    if [ $has_ipv6 -eq 0 ]; then
        echo "Creating Docker daemon configuration with IPv6 support..."
        cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    },
    "ipv6": true,
    "fixed-cidr-v6": "fd00:dead:beef:c0::/80",
    "experimental": true,
    "ip6tables": true,
    "data-root": "/root/docker_data"
}
EOF
    else
        echo "Creating Docker daemon configuration without IPv6 support..."
        cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    },
    "experimental": true,
    "data-root": "/root/docker_data"
}
EOF
    fi
}

# Main execution
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo "Docker is already installed. Removing existing installation..."
    systemctl stop docker || true
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    rm -rf /var/lib/docker/ || true
    echo "Existing Docker installation removed."
fi

# Create docker data directory if it doesn't exist
mkdir -p /root/docker_data

# Check if curl is installed, install if not
if ! command -v curl &> /dev/null; then
    echo "curl not found, installing..."
    apt-get update && apt-get install -y curl
fi

# Check if iputils-ping is installed, install if not (needed for IPv6 connectivity test)
if ! command -v ping &> /dev/null; then
    echo "ping not found, installing iputils-ping..."
    apt-get update && apt-get install -y iputils-ping
fi

# Install Docker based on location
if check_if_in_china; then
    install_docker_china
else
    # If first method fails, try alternative method
    if [ $? -ne 0 ]; then
        if check_if_in_china_alt; then
            install_docker_china
        else
            install_docker_international
        fi
    else
        install_docker_international
    fi
fi

# Start Docker service
echo "Starting Docker service..."
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker
systemctl enable docker

# Verify installation
echo "Verifying Docker installation..."
docker --version
if [ $? -eq 0 ]; then
    echo "Docker was installed successfully!"
else
    echo "Docker installation failed."
    exit 1
fi

echo "Docker daemon configuration:"
cat /etc/docker/daemon.json
