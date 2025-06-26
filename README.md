
Peanut
======

Peanut is a collection of bash scripts designed to automate the setup, configuration, deployment, maintenance, and cleanup of a LAMP stack (Linux, Apache, MySQL, PHP) on an AWS EC2 instance running Ubuntu 22.04 (Jammy Jellyfish). These scripts streamline the provisioning, deployment, management, and decommissioning of a secure, optimized web hosting environment, including Apache virtual hosts, Adminer for database management, and support for deploying public and private GitHub repositories.

Update
------

Added an all in one script which takes care of most of the settings needed to set this up as a sinlge script. 

new features as well, for ssl etc.

Features
--------

*   **Complete LAMP Setup**: Configures Apache virtual hosts (HTTP and HTTPS), creates domain-specific users and directories, and installs Adminer for MySQL database management.
*   **Web Application Deployment**: Deploys public and private GitHub repository contents to specified directories for hosting web applications.
*   **System Maintenance**: Ensures system security with automated package and kernel updates, including cleanup of unnecessary packages and logs.
*   **Domain Management**: Sets up and removes domain-specific configurations, users, groups, and files for provisioning and decommissioning domains.
*   **AWS Integration**: Tailored for AWS EC2 instances, ensuring compatibility with cloud-based hosting.
*   **Secure Database Access**: Configures Adminer with HTTP Basic Authentication for secure MySQL database administration.
*   **Notifications**: Supports email and Slack notifications for critical events like system reboots.
*   **Customizable**: Modular scripts with configurable settings for paths, users, passwords, GitHub tokens, domains, notifications, and log retention.
*   **Logging**: Maintains detailed logs of operations with automatic cleanup to manage disk space.

Scripts
-------

### `setup-jammy-domains.sh`

**Purpose**: Configures domain-specific users, groups, directories, and Apache virtual hosts (HTTP and HTTPS) for hosting multiple domains in a LAMP environment.

**Features**:

*   Creates a group and user for each domain (e.g., `snoopy` for `snoopy.example.com`).
*   Sets up a `public_html` directory in the user’s home directory (e.g., `/home/snoopy/public_html`) with appropriate permissions (`755`).
*   Generates a random password for each user and saves it to `/root/<subdomain>-password.txt`.
*   Configures Apache virtual hosts for HTTP (port 80) and HTTPS (port 443) with self-signed SSL certificates.
*   Enables the Apache `ssl` module and activates virtual hosts.
*   Requires root privileges (`sudo`).

**Usage**:

    sudo ./setup-jammy-domains.sh

**Configuration**:

*   Edit the `domains` array to specify domains (default: `snoopy.example.com`, `woodstock.example.com`).

**Dependencies**:

*   `apache2` (for virtual host configuration)
*   `openssl` (for password generation)

### `update-jammy.sh`

**Purpose**: Automates system updates and maintenance for an Ubuntu 22.04 server, ensuring a secure and up-to-date LAMP environment.

**Features**:

*   Updates package lists, upgrades installed packages, and performs distribution upgrades.
*   Removes unnecessary packages and cleans the package cache.
*   Checks for kernel updates and schedules a system reboot if a new kernel is detected.
*   Sends optional email and Slack notifications when a reboot is required.
*   Logs all actions to timestamped files in `/var/log/update-ubuntu/`.
*   Deletes logs older than 30 days (configurable).
*   Requires root privileges (`sudo`).

**Usage**:

    sudo ./update-jammy.sh

**Configuration**:

*   Edit `SEND_EMAIL` and `SEND_SLACK` to enable/disable notifications.
*   Configure `EMAIL_TO`, `EMAIL_SUBJECT`, `EMAIL_BODY`, and `SLACK_WEBHOOK_URL`.
*   Adjust `RETENTION_DAYS` for log retention.

**Dependencies**:

*   `mail` (for email notifications)
*   `curl` (for Slack notifications)

### `install-adminer.sh`

**Purpose**: Installs and configures Adminer, a lightweight database management tool, with HTTP Basic Authentication for secure MySQL database administration.

**Features**:

*   Downloads the latest MySQL-compatible Adminer version from GitHub.
*   Installs Adminer to a specified path (default: `/home/snoopy/public_html/adminer/index.php`).
*   Sets up `.htaccess` and `.htpasswd` for HTTP Basic Authentication with configurable username and password.
*   Configures file ownership (default: `snoopy:snoopy`) and permissions (`640`).
*   Verifies Apache configuration for `.htaccess` support and warns if adjustments are needed.
*   Requires root privileges (`sudo`) for file operations.

**Usage**:

    sudo ./install-adminer.sh

**Configuration**:

*   Edit `CHOWN_USER`, `CHOWN_GROUP`, `INSTALL_PATH` for installation settings.
*   Set `HTPASSWD_USER` and `HTPASSWD_PASSWORD` for authentication credentials.

**Dependencies**:

*   `curl` (for downloading Adminer)
*   `htpasswd` (from `apache2-utils` for authentication setup)

### `deploy-public-repo.sh`

**Purpose**: Deploys the contents of a public GitHub repository to a specified directory, ideal for hosting web application files in a LAMP environment.

**Features**:

*   Clones a public GitHub repository to a temporary directory.
*   Moves repository contents to a target directory (default: `/home/foobar`), overwriting existing files.
*   Sets ownership of deployed files to a specified user and group (default: `foobar:foobar`).
*   Removes the temporary cloned directory after deployment.
*   Requires root privileges (`sudo`).
*   **Warning**: Do not run in the root home directory to avoid overwriting critical files.

**Usage**:

    sudo ./deploy-public-repo.sh

**Configuration**:

*   Edit `REPO_URL` (GitHub repository URL), `TARGET_DIR` (destination directory), and `USER_GROUP` (user and group for ownership).

**Dependencies**:

*   `git` (for cloning the repository)
*   `rsync` (for moving files)

### `deploy-private-repo.sh`

**Purpose**: Deploys the contents of a private GitHub repository to a specified directory, ideal for hosting private web application files in a LAMP environment.

**Features**:

*   Clones a private GitHub repository using a Personal Access Token (PAT) for authentication.
*   Moves repository contents to a target directory (default: `/home/snoopy`), overwriting existing files.
*   Sets ownership of deployed files to a specified user and group (default: `snoopy:snoopy`).
*   Removes the temporary cloned directory after deployment.
*   Requires root privileges (`sudo`).
*   **Warning**: Do not run in the root home directory to avoid overwriting critical files.

**Usage**:

    sudo ./deploy-private-repo.sh

**Configuration**:

*   Edit `GITHUB_USER` (GitHub username), `TOKEN` (GitHub PAT), `REPO_NAME` (repository name), `TARGET_DIR` (destination directory), and `USER_GROUP` (user and group for ownership).

**Dependencies**:

*   `git` (for cloning the repository)
*   `rsync` (for moving files)

### `remove-jammy-domains.sh`

**Purpose**: Automates the cleanup of domain-specific configurations, users, groups, and files for decommissioning domains in a LAMP environment.

**Features**:

*   Removes Apache virtual host configurations for specified domains (e.g., `/etc/apache2/sites-available/snoopy.example.com.conf`).
*   Deletes password files (e.g., `/root/snoopy-password.txt`).
*   Removes user accounts and their home directories (e.g., `snoopy`).
*   Deletes associated groups (e.g., `snoopy`).
*   Reloads Apache2 to apply changes if installed.
*   Skips Apache-related cleanup if Apache2 is not installed.
*   Requires root privileges (`sudo`).

**Usage**:

    sudo ./remove-jammy-domains.sh

**Configuration**:

*   Edit the `domains` array to specify domains for cleanup (default: `snoopy.example.com`, `woodstock.example.com`).

**Dependencies**:

*   `apache2ctl` (for Apache-related cleanup, optional)

Installation
------------

1.  Clone the repository:
    
        git clone https://github.com/tocsindata/peanut.git
    
2.  Navigate to the repository:
    
        cd peanut

3. Edit with Nano or vi and change defaults to desired output

        nano ./script.sh
    
4.  Make scripts executable:
    
        chmod +x *.sh
    
5.  Run the desired script with root privileges, e.g.:
    
        sudo ./setup-jammy-domains.sh
        sudo ./update-jammy.sh
        sudo ./install-adminer.sh
        sudo ./deploy-public-repo.sh
        sudo ./deploy-private-repo.sh
        sudo ./remove-jammy-domains.sh
    

Prerequisites
-------------

*   **AWS EC2 Instance**: Running Ubuntu 22.04 (Jammy Jellyfish).
*   **Root Access**: All scripts require root or sudo privileges.
*   **Apache**: Must be installed for `setup-jammy-domains.sh`, `install-adminer.sh`, and `remove-jammy-domains.sh`. Install with:
    
        sudo apt update && sudo apt install apache2
    
*   **MySQL and PHP**: Assumed to be pre-installed for a complete LAMP stack. Install with:
    
        sudo apt install mysql-server php libapache2-mod-php php-mysql
    
*   **Dependencies**:
    *   `git` and `rsync` (for `deploy-public-repo.sh` and `deploy-private-repo.sh`).
    *   `openssl` (for `setup-jammy-domains.sh`).
    *   `curl` and `apache2-utils` (for `install-adminer.sh`).
    *   `mail` and `curl` (optional, for notifications in `update-jammy.sh`).
    *   `apache2ctl` (optional, for `remove-jammy-domains.sh`).

Security Considerations
-----------------------

*   **Change Default Credentials**: Update the default password (`abc123`) in `install-adminer.sh` for production environments.
*   **Secure GitHub Tokens**: Replace the placeholder token in `deploy-private-repo.sh` with a valid PAT and store it securely (e.g., in environment variables or AWS Secrets Manager).
*   **Secure Password Storage**: Passwords generated by `setup-jammy-domains.sh` are stored in `/root/<subdomain>-password.txt`. Move these to a secure location or use a secrets manager.
*   **SSL Certificates**: `setup-jammy-domains.sh` uses self-signed certificates (`ssl-cert-snakeoil`). Replace with valid certificates (e.g., Let’s Encrypt) for production.
*   **Avoid Root Home Directory**: Do not run `deploy-public-repo.sh` or `deploy-private-repo.sh` in the root home directory to avoid overwriting critical files.
*   **Restrict File Permissions**: Ensure deployed files and directories (e.g., `public_html`) have appropriate permissions for web access.
*   **Apache Configuration**: Verify `AllowOverride All` is set in Apache for `.htaccess` to work with Adminer.

Usage Workflow
--------------

1.  **Setup Domains**: Run `setup-jammy-domains.sh` to create users, groups, directories, and Apache virtual hosts.
2.  **Deploy Applications**: Use `deploy-public-repo.sh` or `deploy-private-repo.sh` to deploy web application files to `public_html`.
3.  **Install Adminer**: Run `install-adminer.sh` to add Adminer for database management.
4.  **Maintain System**: Use `update-jammy.sh` for regular system updates and maintenance.
5.  **Decommission Domains**: Run `remove-jammy-domains.sh` to clean up unused domains.

Notes
-----

*   Customize script variables (e.g., paths, users, passwords, GitHub tokens, domains) to match your environment.
*   The scripts assume domain users (e.g., `snoopy`, `foobar`) are created by `setup-jammy-domains.sh` or align with Apache (e.g., `www-data`). Standardize user/group settings as needed.
*   MySQL and PHP are assumed to be pre-installed. Install them manually if needed (see Prerequisites).
*   For private repositories, ensure the GitHub PAT has appropriate permissions (e.g., `repo` scope).
*   Ensure AWS security groups allow HTTP (port 80) and HTTPS (port 443) traffic for web access.

Contributing
------------

Contributions are welcome! Please submit pull requests or open issues for bug reports, feature requests, or improvements.

License
-------

[MIT License](LICENSE)
