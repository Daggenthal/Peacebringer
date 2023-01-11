#!/bin/bash

Help()  {
   
    # Display Help
    echo
    echo     $'\t'"h    --      Prints this message."
    echo     $'\t'"fb   --      Backs up the server."
    echo     $'\t'"dbb  --      Backs up the database and timestamps it."
    echo     $'\t'"wb   --      Backs up NGINX, Certs, and other important files such as the website"
    echo     $'\n\t'"tb   --      Transfers to a new server."
    echo     $'\t'"s    --      Installs the necessarry files for the server."
    echo     $'\n\t'"fr   --      This restores the server, putting the files we've backed up into their proper directories."
    echo     $'\n\t'"dbr  --      This allows the user to select a specific .sql database and recover into it."
    echo     $'\n\t'"wbr  --      This attempts to restore the NGINX and webBackup that a user selects in the /tmp/ directory."
    echo

}

mainMenu() {

    clear

    printf      "\n\tWelcome to Peacebringer! Please input your selection: \n"
    
    printf      "\n\t1: Full Backup"
    printf      "\n\t2: Database Backup"
    printf      "\n\t3: Website / NGINX Backup\n"
    printf      "\n\t4: Transfer Backup"
    printf      "\n\t5: Server Setup\n"
    printf      "\n\t6: Restore Full Backup"
    printf      "\n\t7: Restore Database"
    printf      "\n\t8: Restore Website\n"
    printf      "\n\t9: Exit\n\t"

    read -p     $'\n\t'"Please input your choice: " userChoice

    if      [ $userChoice = '1' ]; then
        fullBackup
    elif    [ $userChoice = '2' ]; then
        dbBackup
    elif    [ $userChoice = '3' ]; then
        webBackup
    elif    [ $userChoice = '4' ]; then
        transferBackup
    elif    [ $userChoice = '5' ]; then
        serverSetup
    elif    [ $userChoice = '6' ]; then
        fullRestore
    elif    [ $userChoice = '7' ]; then
        dbRestore
    elif    [ $userChoice = '8' ]; then
        webRestore
    elif    [ $userChoice = '9' ]; then
        clear && exit
    fi
}

############################ FUNCTIONS ############################ 

fullBackup() {
    
    # Clears the terminal, creates a directory for where we'll store our website backup, then we'll tar the directories and move them into /home/$USER/Documents while being timestamped.

    clear

    # Cleans up the /tmp/Backup/ directory incase the script was executed without fully completing.

    cd /tmp/ && sudo rm -rf Backup/

    # Create a temporary directory that will be used throughout the script.

    mkdir /tmp/Backup/ && mkdir /tmp/Backup/etc/ && mkdir /tmp/Backup/usr/


    # Here we're asking the user to give us a Username and Password so we can iterate it into the backup process.

    clear
    printf      $'\n\t'"MariaDB backup initiated...\n"

    # Ask for the Username and Password, storing those into 2 variables we've aptly created.

    read -p     $'\n\t'"Please input your MariaDB Username: " userName
    read -sp    $'\n\t'"Please input your MariaDB Password: " passWord

    clear

    # Print out that we are initializing the backup, and tell the user where it will be located.

    echo        $'\n\t'"Backup initiated, this may take a bit and is active, please wait.."

    # Use the information we've gathered earlier, and CD into the specific user directory that this is being ran inside of. If we did this in /tmp/, we'd have to make a folder there and constantly check for it.
    # Instead, we're just storing it in their /Documents/ folder, as that is >typically< created upon user account creation.
    # We finalzie this process by tagging the Year, Month, and Day of DB creation so we can select which one to recover from later.

    cd /tmp/Backup && mysqldump --user=userName --password=passWord --lock-tables --all-databases > server_db_backup.sql

    # Clear the screen upon completion, and tell the user that it has finished successfully.

    clear
    printf      $'\n\t'"The DB was successfully backed up into /tmp/, exiting..."
    sleep 2.5

    # Starts the backup process of my.cnf, NGINX, apache(HTTPD), and postfix for the mail system / SendGrid settings, then moves them in the tmp directory.

    cp /etc/my.cnf /tmp/Backup/etc/ && cp /etc/php.ini /tmp/Backup/etc 

    sudo cp -r /etc/nginx/ /tmp/Backup/etc/ && sudo cp -r /etc/postfix/ /tmp/Backup/etc

    # Starts the backup process of the letsencrypt certs for the website's SSL

    sudo cp -r /etc/letsencrypt/ /tmp/Backup/etc/
    
    printf      $'\n\t'"/etc/ has been backed up! Backing up the website..."
    echo

    # Starts the backup process of the website, and its included files. This may take long depending on what's in there.

    sudo cp -r /usr/share/nginx/ /tmp/Backup/usr/
    
    printf      $'\n\t'"The website has been backed up! Compressing files..."
    echo

    # Dates and compresses the /tmp/Backup/ folder for RSYNC later on, then removes the temporary /tmp/Backup/ folder.

    cd /tmp/ && sudo tar -zcvf "$(date '+%Y-%m-%d')_webBackup.tar.gz" /tmp/Backup/

    # Moves the folder we've created to the /tmp/ directory to be cleared whenever the server is rebooted, or when /tmp/ is usually cleared.

    run cd /tmp/ && sudo rm -rf Backup/

    # Clear the terminal and tell the user that the operation finished.

    clear
    
    printf      $'\n\t'"The website and its subdirections have been backed up!"
    echo

    printf      $'\n\t'"Exiting program..."
    sleep 1.5
    clear
    
    exit

}

dbBackup() {

    # Here we're asking the user to give us a Username and Password so we can iterate it into the backup process.

    clear
    printf      $'\n\t'"MariaDB backup initiated...\n"

    # Ask for the Username and Password, storing those into 2 variables we've aptly created.

    read -p     $'\n\t'"Please input your MariaDB Username: " userName
    read -sp    $'\n\t'"Please input your MariaDB Password: " passWord

    clear

    # Print out that we are initializing the backup, and tell the user where it will be located.

    printf      $'\n\t'"The DB backup will be stored in /tmp/. Please wait..."
    sleep 2.5

    # Use the information we've gathered earlier, and CD into the specific user directory that this is being ran inside of. If we did this in /tmp/, we'd have to make a folder there and constantly check for it.
    # Instead, we're just storing it in their /Documents/ folder, as that is >typically< created upon user account creation.
    # We finalzie this process by tagging the Year, Month, and Day of DB creation so we can select which one to recover from later.

    cd /tmp/ && mysqldump --user=userName --password=passWord --lock-tables --all-databases > $(date '+%Y-%m-%d').sql

    # Clear the screen upon completion, and tell the user that it has finished successfully.

    clear
    printf      $'\n\t'"The DB was successfully backed up into /tmp/, exiting..."
    sleep 2.5
    clear

    exit

}

dbRestore() {

    clear

    echo        "Scanning the /tmp/ directory for any databases..."
    echo
    sleep 1

    # Get a list of files in /tmp/ directory.

    file_list=$(ls /tmp/ | grep '.sql' )

    # Print out each file in the directory with a number.

    index=1

    for file in $file_list; do
        echo "$index: $file"
        index=$((index + 1))
    done

    # Prompt user to select a file.

    echo -n     $'\n\t'"Select a file (enter a number): "
    read file_number

    # Store users selection into a variable.

    outputFile=$(echo "$file_list" | head -n$file_number | tail -1)

    clear

    # Ask the user for the MariaDB name so we can iterate it into the function to restore the DB.

    read -p     $'\n\t'"Please input your MariaDB Username: "   userName

    # Iterate with the information we were given, restore the DB forcefully.

    clear && sudo mysql --user userName --password --force < outputFile

    # Clear the terminal and tell the user that it passed, and will exit.

    clear
    printf      $'\n\t'"The Database was properly restored! Exiting now..."
    sleep 1.5
    clear

    exit

}

webBackup() {

    # Clears the terminal, creates a directory for where we'll store our website backup, then we'll tar the directories and move them into /home/$USER/Documents while being timestamped.

    clear

    # Cleans up the /tmp/Backup/ directory incase the script was executed without fully completing.

    cd /tmp/ && sudo rm -rf Backup/

    # Create a temporary directory that will be used throughout the script.

    mkdir /tmp/Backup/ && mkdir /tmp/Backup/etc/ && mkdir /tmp/Backup/usr/

    # Starts the backup process of my.cnf, NGINX, apache(HTTPD), and postfix for the mail system / SendGrid settings, then moves them in the tmp directory.

    cp /etc/my.cnf /tmp/Backup/etc/ && cp /etc/php.ini /tmp/Backup/etc 

    sudo cp -r /etc/nginx/ /tmp/Backup/etc/ && sudo cp -r /etc/postfix/ /tmp/Backup/etc

    # Starts the backup process of the letsencrypt certs for the website's SSL

    sudo cp -r /etc/letsencrypt/ /tmp/Backup/etc/
    
    printf      $'\n\t'"/etc/ has been backed up! Backing up the website..."
    echo

    # Starts the backup process of the website, and its included files. This may take long depending on what's in there.

    sudo cp -r /usr/share/nginx/ /tmp/Backup/usr/
    
    printf      $'\n\t'"The website has been backed up! Compressing files..."
    echo

    # Dates and compresses the /tmp/Backup/ folder for RSYNC later on, then removes the temporary /tmp/Backup/ folder.

    cd /tmp/ && sudo tar -zcvf "$(date '+%Y-%m-%d')_webBackup.tar.gz" /tmp/Backup/

    # Moves the folder we've created to the /tmp/ directory to be cleared whenever the server is rebooted, or when /tmp/ is usually cleared.

    run cd /tmp/ && sudo rm -rf Backup/

    # Clear the terminal and tell the user that the operation finished.

    clear
    
    printf      $'\n\t'"The website and its subdirections have been backed up!"
    echo

    printf      $'\n\t'"Exiting program..."
    sleep 1.5
    clear
    exit

}

webRestore() {

    clear

    echo        "Scanning the /tmp/ directory for any databases..."
    echo
    sleep 1

    # Get a list of files in /tmp/ directory.

    file_list=$(ls /tmp/ | grep '_webBackup.tar.gz' )

    # Print out each file in the directory with a number.

    index=1

    for file in $file_list; do
        echo "$index: $file"
        index=$((index + 1))
    done

    # Prompt user to select a file.

    echo -n     $'\n\t'"Select a file (enter a number): "
    read file_number

    # Store users selection into a variable.

    outputFile=$(echo "$file_list" | head -n$file_number | tail -1)

    clear

    # Here we're going to disable the services while we attempt to restore them.

    printf      $'\n\t'"Disabling services momentarily..."
    echo
    sleep 1.25

    sudo systemctl stop nginx postfix mariadb memcached.service

    printf      $'\n\t'"Services have successfully been disabled. Attempting restoration, please wait..."
    echo
    sleep 1.25

    # Here we're beginning to decompress the file we created, and moved, earlier. This contains everything we need to properly setup the new server.

    printf      $'\n\t'"Attempting to decompress the file, please wait..."
    echo
    sleep 2

    cd /tmp/ && sudo tar -xz outputFile
    clear

    printf      $'\n\t'"The file has successfully been decompressed! Attempting restore..."
    echo
    sleep 1.25

    # Here we're going to move the files to the proper directory that they came from.

    cd /tmp/tmp/Backup/etc && sudo cp my.cnf /etc/ && sudo cp php.ini /etc/ && sudo cp -r nginx/ /etc/ && sudo cp -r postfix/ /etc/

    printf      $'\n\t'"/etc/ folders have successfully been restored! Attempting website restore..."
    echo
    sleep 1.25

    # Now we're going to move the website and mail certs back to their origin.
    # We move the folder that's created by nginx, to the /tmp/ directory, so we can install our own copy.

    cd /usr/share && sudo mv nginx/ /tmp/
    cd /tmp/tmp/Backup/usr && sudo cp -r nginx/ /usr/share/

    printf      '\n\t'"Website has successfully been restored! Attempting API key restore..."
    echo
    sleep 1.25

    # Now we're going to setup postfix so we can use the same API keys

    sudo postmap /etc/postfix/sasl_passwd

    printf      $'\n\t'"API keys have successfully been restored! Attempting SSL certs restore..."
    echo
    sleep 1.25

    cd /tmp/tmp/Backup/etc/ && sudo cp -r letsencrypt/ /etc/

    printf      $'\n\t'"SSL certs have successfully been restored!"
    echo
    sleep 1.25

    # Now we'll start the services again, and enable them to persist on reboot

    printf      $'\n\t'"Starting services, and enabling them for future reboots, please wait..."
    echo

    sudo systemctl sart nginx postfix mariadb memcached.service && sudo systemctl enable nginx postfix mariadb memcached.service

    # Clearing the shell and telling the user that the process is complete.

    clear

    printf      $'\n\t'"Web Restore has successfully completed! Exiting now..."
    sleep 1.25
    clear
    exit

}

transferBackup() {
    
    clear

    read -p     $'\n\t'"Please input the Username: " userName
    read -p     $'\n\t'"Please input the IP: " ipAddress
    clear
    echo

    echo        $'\n\t'"Are these correct?"
    echo        $'\n\t'"Username: " $userName
    echo        $'\t'"IP Address: "   $ipAddress

    echo        $'\n\t'"1) Yes"
    echo        $'\t'"2) No"
    echo

    read -p     $'\t'"Answer: "   userChoice


    if [ $userChoice = '1' ]; then
        
        clear

        # Get a list of files in /tmp/ directory.

        file_list=$(ls /tmp/ | grep -E '.sql|.tar.gz|_webBackup.tar.gz|.log|_link')

        # Print out each file in the directory with a number.

        index=1

        for file in $file_list; do
            echo "$index: $file"
            index=$((index + 1))
        done

        # Prompt user to select a file.

        echo -n $'\n\t'"Select a file (enter a number): "
        read file_number

        # Store users selection into a variable.

        outputFile=$(echo "$file_list" | head -n$file_number | tail -1)

        clear

        echo        $'\n\t'"Preparing to transfer the file, please wait..."
        sleep       1.5
        clear

        echo        $'\n\t'"Transferring file now..."
        echo

        cd  /tmp && sudo rsync -av -P outputFile + '' + $userName + '@' + $ipAddress + ':/tmp/'

        clear

        echo        $'\n\t'"File has been successfully transferred, exiting now..."
        sleep 1.5
        clear
        exit


    elif [ $userChoice = '2' ]; then
        
        clear

        printf      $'\n\t'"Returning back to choices..."
        
        sleep       1.5

        transferBackup

    fi



}

serverSetup() {
    
    clear

    printf      $'\n\t'"Detecting Distribution and installing prerequisite software..."
    sleep 1.25

    #   Detect Linux Distro.

    OS=$(cat /etc/os-release)

    #   Install software based upon distro.

    if grep -Eq 'debian|ubuntu' /etc/os-release; then
        
        clear
        sudo apt install -y nginx mariadb-server memcached certbot postfix pv php-cli php-mysqli php-xml php-fpm memcached python3-certbot-nginx vsftpd

    elif  grep -Eq 'fedora' /etc/os-release; then
        
        clear
        sudo dnf install -y nginx mariadb-server memcached certbot postfix pv php-cli php-mysqli php-xml php-fpm php-pecl-memcached python3-certbot-nginx vsftpd

    elif grep -Eq 'rocky' /etc/os-release; then

        clear
        sudo dnf install -y epel-release && sudo dnf install nginx mariadb-server memcached certbot postfix pv php-cli php-mysqli php-xml php-fpm php-pecl-memcached python3-certbot-nginx vsftpd

    elif grep -Eq 'arch' /etc/os-release; then

        clear
        sudo pacman -S nginx mariadb-server memcached certbot postfix pv php-cli php-mysqli php-xml php-fpm memcached python3-certbot-nginx vsftpd

    elif grep -Eq 'opensuse' /etc/os-release; then

        clear
        sudo zypper install -y nginx mariadb-server memcached certbot postfix pv php-cli php-mysqli php-xml php-fpm memcached python3-certbot-nginx vsftpd

    elif grep -Eq 'freebsd' /etc/os-release; then

        clear
        sudo pkg install -y nginx mariadb106-server-10.6.8 mariadb106-client-10.6.8  memcached postfix py38-certbot-nginx-1.22.0 apache24-2.4.54
    
    fi
    
    clear

    echo        $'\n\t'"The prerequisites have been installed! Exiting now..."
    sleep 1.25

    clear

    exit

}

fullRestore() {
    
    clear

    printf      $'\n\t'"Disabling services momentarily..."
    sleep 1.25

    sudo systemctl stop nginx postfix mariadb memcached.service

    printf      $'\n\t'"Services have been disabled. Attempting restoration, please wait..."
    sleep 1.25

    clear

    echo        "Scanning the /tmp/ directory for any databases..."
    echo

    sleep 1

    # Get a list of files in /tmp/ directory.

    file_list=$(ls /tmp/ | grep '.tar.gz' )

    # Print out each file in the directory with a number.

    index=1

    for file in $file_list; do
        echo "$index: $file"
        index=$((index + 1))
    done

    # Prompt user to select a file.

    echo -n     $'\n\t'"Select a file (enter a number): "
    read file_number

    # Store users selection into a variable.

    outputFile=$(echo "$file_list" | head -n$file_number | tail -1)

    clear

	# Here we're beginning to decompress the file we created, and moved, earlier. This contains everything we need to properly setup the new server.

    printf      $'\n\t'"Attempting to decompress the file, please wait..."
    sleep 2

    # Decompress the selected file.

    cd /tmp/ && sudo pv outputFile | tar -xz

    clear

    printf      $'\n\t'"Decompression successful, attempting restore..."

    #   Copy the files back into their proper directories.

    cd /tmp/tmp/Backup/etc && sudo cp -r my.cnf php.ini nginx/ postfix/ /etc/

    clear

    printf      $'\n\t'"/etc/ has been successfully restored! Attempting website restore..."

    sudo postmap /etc/postfix/sasl_passwd

    printf      $'\n\t'"API keys have been restored! Attempting SSL certs restore..."

    cd /tmp/tmp/Backup/etc && sudo cp -r letsencrypt/ /etc/

    printf      $'\n\t'"SSL certs have been successfully restored!"

    #   Enable the services for future reboots and start them

    printf      $'\n\t'"Starting services and enabling them for future reboots, please wait..."

    sudo systemctl start nginx postfix mariadb memcached.service && sudo systemctl enable nginx postfix mariadb memcached.service

    printf      $'\n\t'"Services have been successfully enabled! Configuring the database..."
    sleep 1.25

    clear

    echo        $'\n\t'"Have you already setup MariaDB?"
    echo
    echo        $'\n\t'"1) Yes"
    echo        $'\t'"2) No"

    read -p     $'\n\t'"Please input your selection: " userChoice

    if [ $userChoice = '1' ]; then
        
        echo    $'\n\t'"Please input your MariaDB username: "
        read -p $'\n\t'"Response: " userName
        echo

        echo    $'\n\t'"Attempting mariaDB / mySQL Database restoration, please wait..."

        sudo mysql --user userName --password --force < /tmp/tmp/Backup/server_db_backup.sql

        echo    $'\n\t'"Database restoration successful! Exiting now..."
        sleep 1.25
        exit

    elif [ $userChoice = '1' ]; then

        echo    $'\n\t'"Would you like to go ahead and setup MariaDB?"
        echo    $'\n\t'"1) Yes"
        echo    $'\n\t'"2) No"

        read -p $'Please input your selection: ' userChoice
    
    fi

        if [ $userChoice = '1']; then
            
            #   Initiate the mariaDB setup wizard

            sudo mysql_secure_installation
            clear

            echo    $'\n\t'"Please input your MariaDB username: "
            read -p $'\n\t'"Response: " userName
            echo

            echo    $'\n\t'"Attempting mariaDB / mySQL Database restoration, please wait..."

            sudo mysql --user userName --password --force < /tmp/tmp/Backup/server_db_backup.sql

            echo    $'\n\t'"Database restoration successful! Exiting now..."
            sleep 1.25
            clear
            exit

        elif [ $userChoice = '2' ]; then

            clear

            printf  $'\n\t'"Please note, that you may need to manually set it up for MariaDB to work properly."
            printf  $'\n\t'"Restoration complete! Going back to main menu..."

            sleep 2
            break
        
        fi
}

############################ FUNCTIONS ############################


#	This here allows us to pass Command Line Options so we can skip the main menu itself

while [ -n "$0" ]; do

	case "$1" in
	
		-h)		Help
				exit;;
				
		-fb)	fullBackup
				exit;;
				
		-dbb)	dbBackup
				exit;;
				
		-dbr)	dbRestore
				exit;;
				
		-wb)	webBackup
				exit;;
				
		-wbr)	webRestore
				exit;;
				
		-tb)	transferBackup
				exit;;
				
		-s)		serverSetup
				exit;;
				
		-fr)	fullRestore
				exit;;
		
	esac
	shift
	
done

#	Executes the main menu after everything has been set-and-done

mainMenu
