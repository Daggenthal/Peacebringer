#!/bin/bash

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

    read -p $'\n\t'"Please input your choice: " userChoice

    if      [ $userChoice = '1' ]; then
        clear && exit
    elif    [ $userChoice = '2' ]; then
        dbBackup
    elif    [ $userChoice = '3' ]; then
        webBackup
    elif    [ $userChoice = '4' ]; then
        echo "Test 3"
    elif    [ $userChoice = '5' ]; then
        echo "Test 3"
    elif    [ $userChoice = '6' ]; then
        echo "Test 3"
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
    echo
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
    sleep 1.5

    # Use the information we've gathered earlier, and CD into the specific user directory that this is being ran inside of. If we did this in /tmp/, we'd have to make a folder there and constantly check for it.
    # Instead, we're just storing it in their /Documents/ folder, as that is >typically< created upon user account creation.
    # We finalzie this process by tagging the Year, Month, and Day of DB creation so we can select which one to recover from later.

    cd /tmp/ && mysqldump --user=$userName --password=$passWord --lock-tables --all-databases > $(date '+%Y-%m-%d').sql

    # Clear the screen upon completion, and tell the user that it has finished successfully.

    clear
    printf      $'\n\t'"The DB was successfully backed up into /tmp/, exiting..."

    echo
    echo

    sleep 2.5

    exit

}

dbRestore() {

    clear

    echo "Scanning the /tmp/ directory for any databases..."
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

    echo -n "Select a file (enter a number): "

    read file_number

    # Store users selection into a variable.

    outputFile=$(echo "$file_list" | head -n$file_number | tail -1)

    clear

    # Ask the user for the MariaDB name so we can iterate it into the function to restore the DB.

    read -p     $'\n\t'"Please input your MariaDB Username: "   userName

    # Iterate with the information we were given, restore the DB forcefully.

    clear && sudo mysql --user $userName --password --force < outputFile

    # Clear the terminal and tell the user that it passed, and will exit.

    clear && printf $'\n\t'"The Database was properly restored! Exiting now..."
    sleep 1.5
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
    
    printf $'\n\t'"/etc/ has been backed up! Backing up the website..."
    echo

    # Starts the backup process of the website, and its included files. This may take long depending on what's in there.

    sudo cp -r /usr/share/nginx/ /tmp/Backup/usr/
    
    printf $'\n\t'"The website has been backed up! Compressing files..."
    echo

    # Dates and compresses the /tmp/Backup/ folder for RSYNC later on, then removes the temporary /tmp/Backup/ folder.

    cd /tmp/ && sudo tar -zcvf "$(date '+%Y-%m-%d')_webBackup.tar.gz" /tmp/Backup/

    # Moves the folder we've created to the /tmp/ directory to be cleared whenever the server is rebooted, or when /tmp/ is usually cleared.

    run cd /tmp/ && sudo rm -rf Backup/

    # Clear the terminal and tell the user that the operation finished.

    clear
    
    printf $'\n\t'"The website and its subdirections have been backed up!"
    echo

    printf $'\n\t'"Exiting program..."
    sleep 1.5
    exit

}

webRestore() {

    clear

    echo "Scanning the /tmp/ directory for any databases..."
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

    echo -n "Select a file (enter a number): "

    read file_number

    # Store users selection into a variable.

    outputFile=$(echo "$file_list" | head -n$file_number | tail -1)

    clear

    # Here we're going to disable the services while we attempt to restore them.

    printf $'\n\t'"Disabling services momentarily..."
    echo

    sleep 1.25

    sudo systemctl stop nginx postfix mariadb memcached.service

    printf $'\n\t'"Services have successfully been disabled. Attempting restoration, please wait..."
    echo

    sleep 1.25

    # Here we're beginning to decompress the file we created, and moved, earlier. This contains everything we need to properly setup the new server.

    printf $'\n\t'"Attempting to decompress the file, please wait..."
    echo

    sleep 2

    cd /tmp/ && sudo tar -xz outputFile
    clear

    printf $'\n\t'"The file has successfully been decompressed! Attempting restore..."
    echo

    sleep 1.25

    # Here we're going to move the files to the proper directory that they came from.

    cd /tmp/tmp/Backup/etc && sudo cp my.cnf /etc/ && sudo cp php.ini /etc/ && sudo cp -r nginx/ /etc/ && sudo cp -r postfix/ /etc/

    printf $'\n\t'"/etc/ folders have successfully been restored! Attempting website restore..."
    echo
    sleep 1.25

    # Now we're going to move the website and mail certs back to their origin.
    # We move the folder that's created by nginx, to the /tmp/ directory, so we can install our own copy.

    cd /usr/share && sudo mv nginx/ /tmp/
    cd /tmp/tmp/Backup/usr && sudo cp -r nginx/ /usr/share/

    printf $'\n\t'"Website has successfully been restored! Attempting API key restore..."
    echo
    sleep 1.25

    # Now we're going to setup postfix so we can use the same API keys

    sudo postmap /etc/postfix/sasl_passwd

    printf $'\n\t'"API keys have successfully been restored! Attempting SSL certs restore..."
    echo

    sleep 1.25

    cd /tmp/tmp/Backup/etc/ && sudo cp -r letsencrypt/ /etc/

    printf $'\n\t'"SSL certs have successfully been restored!"
    echo

    sleep 1.25

    # Now we'll start the services again, and enable them to persist on reboot

    printf $'\n\t'"Starting services, and enabling them for future reboots, please wait..."
    echo

    sudo systemctl start nginx postfix mariadb memcached.service && sudo systemctl enable nginx postfix mariadb memcached.service

    # Clearing the shell and telling the user that the process is complete.

    clear

    printf $'\n\t'"Web Restore has successfully completed! Exiting now..."
    sleep 1.25
    clear
    exit

}

transferBackup() {
    echo
}

serverSetup() {
    echo
}

fullRestore() {
    echo
}

############################ FUNCTIONS ############################

mainMenu
