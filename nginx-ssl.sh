#!/bin/bash

# Check if the script is run as root
if [ "$(whoami)" != "root" ]; then
    echo "Please run this script as root!"
    exit 1
fi

# Function to install Nginx and configure HTTPS
install_nginx_https() {
    # Get domain and email from the user
    read -p "Enter your domain name (e.g., your-domain.com): " DOMAIN
    read -p "Enter your email address (for SSL certificate renewal notices): " EMAIL

    # Update the package lists
    echo "Updating system packages..."
    apt update

    # Install Nginx and Certbot
    echo "Installing Nginx and Certbot..."
    apt install -y nginx certbot python3-certbot-nginx

    # Create Nginx configuration for the domain (HTTP only for now)
    NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
    echo "Creating Nginx configuration for domain $DOMAIN (HTTP only)..."

    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:7001;  # Proxy to your Docker service
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Enable the Nginx configuration
    echo "Enabling Nginx configuration..."
    ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

    # Test Nginx configuration and reload Nginx
    echo "Testing and reloading Nginx..."
    nginx -t && systemctl reload nginx

    # Obtain the SSL certificate from Let's Encrypt
    echo "Obtaining SSL certificate for $DOMAIN..."
    certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

    # Test Nginx configuration again and reload to apply HTTPS settings
    echo "Reloading Nginx with HTTPS..."
    nginx -t && systemctl reload nginx

    echo "Setup complete! Your Docker service is now accessible at https://$DOMAIN"
}

# Function to uninstall Nginx, Certbot, and remove configuration
uninstall_nginx_https() {
    # Get domain from the user
    read -p "Enter the domain name you want to uninstall (e.g., your-domain.com): " DOMAIN

    # Remove the SSL certificates
    echo "Removing SSL certificates..."
    certbot delete --cert-name $DOMAIN

    # Remove the Nginx configuration
    echo "Removing Nginx configuration for domain $DOMAIN..."
    rm -f /etc/nginx/sites-available/$DOMAIN
    rm -f /etc/nginx/sites-enabled/$DOMAIN

    # Uninstall Nginx and Certbot
    echo "Uninstalling Nginx and Certbot..."
    apt purge -y nginx certbot python3-certbot-nginx

    # Remove residual files
    echo "Removing residual files..."
    apt autoremove -y
    rm -rf /etc/letsencrypt
    rm -rf /var/www/html

    echo "Nginx, Certbot, and related configurations have been uninstalled."
}

# Main menu
while true; do
    echo "Choose an option:"
    echo "1. Install Nginx and configure HTTPS"
    echo "2. Uninstall Nginx, Certbot, and remove configurations"
    echo "3. Exit"
    read -p "Enter your choice (1/2/3): " choice

    case $choice in
        1)
            install_nginx_https
            ;;
        2)
            uninstall_nginx_https
            ;;
        3)
            echo "Exiting script."
            exit 0
            ;;
        *)
            echo "Invalid choice, please try again."
            ;;
    esac
done