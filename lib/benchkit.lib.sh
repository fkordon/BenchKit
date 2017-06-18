#!/bin/bash
################################################################################
#
#    Contact            : Fabrice Kordon (Fabrice.Kordon@lip6.fr)
#                         Francis Hulin-Hubard (fhh@lsv.ens-cachan.fr)
#    Web                : https://github.com/fkordon/BenchKit
#    Sources            : https://github.com/fkordon/BenchKit
#    Description        : "BenchKit" is a system to massively invoke
#    programs to be benchmarked and evaluated. It handles their execution
#    in virtual machines and smaple times, CPU and I/O consuption.
#    Licence            : GPL3
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>
#
################################################################################
# Initializing parameters
################################################################################

#config_file="configuration.sh" ;
INVOCATION_TEMPLATE_FILE="conf/invocation_template.txt" ;


_run="$(basename ${0})" ;
_benchkit_version="2" ;
_benchkit_svn_date='$Date:: 2017-06-06 22:37:20 +0200 (Mar, 06 jui 2017) $' ;
_benchkit_svn_rev='$Rev:: 3408                                          $' ;
_benchkit_svn_aut='$Author:: fko                                        $' ;

# default values for execution parameters
BK_DEFAULT_VALUE_MEMORY="1024"
BK_DEFAULT_VALUE_TIME="300"
BK_DEFAULT_VALUE_PRIVATE_KEYFILE="conf/bk-private_key"
BK_DEFAULT_VALUE_SSHP="2222"
BK_DEFAULT_VALUE_VNC="1024"
BK_MAP_FILENAME="./bkmap.conf"
BK_MAP_DEFAULT_CONFIG_FILENAME="./bkhosts.conf" 
BK_DEFAULT_VALUE_VM_LOGIN="mcc"
BK_DEFAULT_RESULT_BASEDIR_NAME="BK_RESULTS"
BENCHKIT_VERSION="$_benchkit_version-$(echo "$_benchkit_svn_rev" | cut -d ' ' -f 2)" ;
BK_DEFAULT_VALUE_NBPROC="1"

# CPU type
# to exploit the host processor, just set this variable to "host" 
BK_CPU_TYPE="SandyBridge" # this corresponds to the following flags ''

# }}}

# {{{ Comon functions 
################################################################################
# Comon functions
################################################################################

die () {
	echo "$@" >&2 ;
	exit 1 ;
}

common_usage () {
	cat <<_eof_

Options 
	-c | --config 	config file (default : embedded values)
	-d | --debug 	mode debug
	-h | --help		this help message
	-v | --version	display version informations
_eof_
}

init_env () {
	: ${_config_file:=${cmd_config_file:=${config_file} }} ;
}

# }}}

# {{{ BenchKit Map (bkmap) 
################################################################################
# BenchKit Map (bkmap)
################################################################################

bkmap_usage () {
	cat <<_eof_
${_run} : BenchKit Map
 $ ${_run} [filename]

Map all physical node ressources load from filename (default "./bkhosts.conf")
in "bkmap.conf" file.

$(common_usage)
_eof_
	exit ${1:-1} ;
}

bkmap () {
	if [ -z "$1" ] ; then
		mapfile=${BK_MAP_DEFAULT_CONFIG_FILENAME}
	else
		mapfile=$1
	fi
	
	if [ ! -f ${mapfile} ] ; then
		die "Err > ${mapfile} not found"
	fi

	if [ -f "${BK_MAP_FILENAME}" ] ; then
		die "Err > A map exist, please remove it before generate a new file" 
	fi

	sed -e '{s/[[:blank:]]//g;s/#.*$//g;s,//.*,,g;/^$/d;s/-$//;}' "${mapfile}" | \
	while IFS=':' read fqdn login port reste ; do
		ssh_cmd="ssh"
		if [ ! -z "${port}" ] ; then
			ssh_cmd="${ssh_cmd} -p ${port}" ;
		fi
		if [ ! -z "${login}" ] ; then
			ssh_cmd="${ssh_cmd} -l ${login}" ;
		fi
#	Order : FQDN	physical processor(s)	physical cores per CPU	logical cores
		${ssh_cmd} -n ${fqdn} 'echo -e "'${fqdn}'\t$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)\t$(grep "cpu cores" /proc/cpuinfo | sort -u | cut -d":" -f2 | sed -e "s/[[:blank:]]//g")\t$(grep -c "processor" /proc/cpuinfo)\t$(grep ^MemTotal /proc/meminfo | cut -d":" -f2 | sed -e "{s/[[:blank:]]//g;s/\(.*\)kB$/\1/;}")\t$(uname -m)"' >> "${BK_MAP_FILENAME}"
	done
}

# }}}

# {{{ BenchKit Launch Run (bklr or launch_a_run) 
################################################################################
# BenchKit Launch Run (bklr or launch_a_run)
################################################################################

bklr_usage () {
	cat <<_eof_
${_run} : BenchKit Launch a Run
 $ ${_run} <disk image> <input name> <examination name>

 The following environment variables allow one to configure the execution
 	BK_MAXMEM
 		the maximum of memory allocated to the VM (Mbytes, default is $BK_DEFAULT_VALUE_MEMORY)
 	BK_MAXTIME
 		the maximum execution time for the VM (seconds, default is $BK_DEFAULT_VALUE_TIME)
	BK_VM_LOGIN
		the login of the account to be used to connect the VM (default value is $BK_DEFAULT_VALUE_VM_LOGIN)
	BK_TOOL_NAME
		The name of the tool (otherwize, the radix of the disk image file name is used)
	BK_NBPROC
		the number of cores to be affected to the VM (defailt is $BK_DEFAULT_VALUE_NBPROC)

$(common_usage)
_eof_
	exit ${1:-1} ;
}

bklr () {
	disk="$1" ;
	BK_INPUT_NAME="$2" ;
	BK_EXAMINATION="$3"
	# these parameters may be empty, this is not a problem (default values assumed in bklv)
	export BK_SSHP=$4
	export BK_VNC=$5
	if [ -z "$BK_TOOL_NAME" ] ; then
		export BK_TOOL_NAME=${BK_TOOL_NAME:=$(basename ${disk} | cut -d '.' -f 1)} ;
	fi

	if [ -z "${OUTPUT_DIR}" ] ; then
		#OUTPUT_DIR="$HOME/$BK_DEFAULT_RESULT_BASEDIR_NAME"
		OUTPUT_DIR="/tmp/$BK_DEFAULT_RESULT_BASEDIR_NAME"
	fi

	echo "bklr runs $BK_TOOL_NAME on $BK_INPUT_NAME ($BK_EXAMINATION)" ;
	# create outputs directories (if needed)
	if [ ! -d "${OUTPUT_DIR}/CSV" ] ; then
		mkdir -p "${OUTPUT_DIR}/CSV"
	fi
	if [ ! -d "${OUTPUT_DIR}/CONFIGURATIONS" ] ; then
		mkdir -p "${OUTPUT_DIR}/CONFIGURATIONS"
	fi
	if [ ! -d "${OUTPUT_DIR}/OUTPUTS" ] ; then
		mkdir -p "${OUTPUT_DIR}/OUTPUTS"
	fi
	# default value of the run id (if needed)
	if [ -z "$BK_RUN_IDENTIFIER" ] ; then
		BK_RUN_IDENTIFIER="drid-"$(perl -e "printf '%0.5d', $(expr $RANDOM % 10000)")
	fi
	# default value of the allocated cores (if needed)
	if [ -z "$BK_NBPROC" ] ; then
		BK_NBPROC=$BK_DEFAULT_VALUE_NBPROC
	fi
	# default value of the allocated time (if needed)
	if [ -z "$BK_MAXTIME" ] ; then
		BK_MAXTIME=$BK_DEFAULT_VALUE_TIME
	fi
	# default value of the allocated memory (if needed)
	if [ -z "$BK_MAXMEM" ] ; then
		BK_MAXMEM=$BK_DEFAULT_VALUE_MEMORY
	fi
	# default value for login (the one of the MCC)
	if [ -z "$BK_VM_LOGIN" ] ; then
		BK_VM_LOGIN=$BK_DEFAULT_VALUE_VM_LOGIN
	fi
	SUM_FILE="${OUTPUT_DIR}/CSV/summary_$BK_TOOL_NAME.csv" ;
	CONF_FILE="$OUTPUT_DIR/CONFIGURATIONS/${BK_TOOL_NAME}_${BK_INPUT_NAME}_${BK_EXAMINATION}_${BK_RUN_IDENTIFIER}.conf" ;
	STDOUT_FILE="$OUTPUT_DIR/OUTPUTS/${BK_TOOL_NAME}_${BK_INPUT_NAME}_${BK_EXAMINATION}_${BK_RUN_IDENTIFIER}_$(uname -n).stdout"
	STDERR_FILE="$OUTPUT_DIR/OUTPUTS/${BK_TOOL_NAME}_${BK_INPUT_NAME}_${BK_EXAMINATION}_${BK_RUN_IDENTIFIER}_$(uname -n).stderr"
	SAMPLING_FILE="${OUTPUT_DIR}/CSV/${BK_TOOL_NAME}_${BK_INPUT_NAME}_${BK_EXAMINATION}_${BK_RUN_IDENTIFIER}_$(uname -n).csv"	

	export BK_INPUT_NAME BK_TOOL_NAME BK_EXAMINATION BENCHKIT_VERSION OUTPUT_DIR BK_RUN_IDENTIFIER SAMPLING_FILE STDERR_FILE
	cat $INVOCATION_TEMPLATE_FILE | sed -e "s/__TEST_NAME__/$BK_INPUT_NAME/g
s/__TOOL_NAME__/$BK_TOOL_NAME/g
s/__BENCHKIT_VERSION__/$BENCHKIT_VERSION/g
s/__EXAMINATION_TYPE__/$BK_EXAMINATION/g
s/__TIME_CONFINEMENT__/$BK_MAXTIME/g
s/__MEMORY_MAX__/$BK_MAXMEM/g
s/__NBCORES__/$BK_NBPROC/g
s|__OUTPUT_DIR__|$OUTPUT_DIR/OUTPUTS|g
s/__BK_RID__/$BK_RUN_IDENTIFIER/g" > $CONF_FILE

	bklc "${disk}" "$(cat $CONF_FILE)" "$BK_TOOL_NAME" "$BK_INPUT_NAME" | tee "$STDOUT_FILE" ;
	BEFORE="$(grep ^BK_START "${STDOUT_FILE}" | cut -d ' ' -f 2)" ;
	AFTER="$(grep ^BK_STOP "${STDOUT_FILE}" | cut -d ' ' -f 2)" ;

	# write execution data into the log-file for this run
	if [ ! -f "$SUM_FILE" ] ; then
		echo '### tool,Input,Examination,max memory (MB),CPU (ms),Time (ms),i/o wait (ms),Status,run id' > "$SUM_FILE"
	fi
	if [ -z "${AFTER}" ] ; then
		DIFFERENCE=$(expr $BK_MAXTIME \* 1000) # estimation (we reached the time confinement)
		ENDSTATUS="timeout"
	else
		DIFFERENCE=$(expr $AFTER - $BEFORE) ;
		ENDSTATUS="normal"
	fi
	# compute memory and CPU usage from the log file generated by bklc
	# to get monitoring iformations about the execution
	grep -v '#' "$SAMPLING_FILE" | (CPU=0
	MEM=0
	IOW=0
	while read LINE ; do
		idle=$(echo $LINE | cut -d ';' -f 11)
		iow=$(echo $LINE | cut -d ';' -f 9)
		mem=$(echo $LINE | cut -d ';' -f 13)
		#echo "idle=$idle mem=$mem iow=$iow"
		CPU=$(perl -e "print $CPU + (100 - $idle - $iow) * 10 * $BK_NBPROC")
		IOW=$(perl -e "print $IOW + $iow * 10")
		if [ "$mem" -gt "$MEM" ] ; then
			MEM=$mem
		fi
	done
	echo "BK_TIME    : $DIFFERENCE ms"
	echo "BK_CPU     : $CPU ms"
	echo "BK_IO_WAIT : $IOW ms"
	echo "BK_MEMORY  : $MEM KB"
	echo "$BK_TOOL_NAME,$BK_INPUT_NAME,$BK_EXAMINATION,$(perl -e 'printf "%.2f", '$MEM' / 1024'),$(echo $CPU | cut -d '.' -f 1),$DIFFERENCE,$IOW,$ENDSTATUS,$BK_RUN_IDENTIFIER" >> "$SUM_FILE")
}
# }}}

# {{{  BenchKit Launch Command (bklc or launch_a_command) 
################################################################################
# BenchKit Launch Command (bklc or launch_a_command) 
################################################################################

bklc_usage () {
	cat <<_eof_
${_run} : BenchKit Launch Command
 $ ${_run}  <path-to-disk-image> <command-to-operate> <tool-name> <inputname> 

The following environment variables allow one to configure the execution
	BK_MAXMEM
		the maximum of memory allocated to the VM (Mbytes, default is $BK_DEFAULT_VALUE_MEMORY)
	BK_MAXTIME
		the maximum execution time for the VM (seconds, default is $BK_DEFAULT_VALUE_TIME)
	BK_PRIVATE_KEY_FILE
		the path to the file containin the private key associated to the public keys in the VM
		(default is $BK_DEFAULT_VALUE_PRIVATE_KEYFILE)
	BK_SSHP
		the SSH port to be redirected to 22 in the VM (default is $BK_DEFAULT_VALUE_SSHP)
	BK_VM_LOGIN
		the login of the account to be used to connect the VM (default value is $BK_DEFAULT_VALUE_VM_LOGIN)
	BK_VNC
		the VNC port to be redirected to 42 in the VM (default is $BK_DEFAULT_VALUE_VNC)
	BK_NBPROC
		the number of cores to be affected to the VM (defailt is $BK_DEFAULT_VALUE_NBPROC)

The execution is also associated to a run-id that is defined in the BK_RUN_IDENTIFIER environment
variable. 

$(common_usage)
_eof_
	exit ${1:-1} ;
}

bklc () {
	if [ $# -ne 4 ] ; then
		bklc_usage
		die "Err > \"$0\" : bad usage!!!!!!!!!!!!"
	fi
	VMPATH="$1"
	COMMAND="$2"
	bklc_toolname="$3"
	bklc_inputname="$4"
	# Suppress the known_ost file to avoid ssh connection problems
	# if [ -f "$HOME/.ssh/known_hosts" ] ; then
	# 	rm -f "$HOME/.ssh/known_hosts"
	# fi
	if [ -z "${OUTPUT_DIR}" ] ; then
		OUTPUT_DIR="/tmp"
	fi
	# create outputs directories if needed
	if [ ! -d "${OUTPUT_DIR}/OUTPUTS" ] ; then
		mkdir -p "${OUTPUT_DIR}/OUTPUTS"
	fi
	if [ ! -d "${OUTPUT_DIR}/CSV" ] ; then
		mkdir -p "${OUTPUT_DIR}/CSV"
	fi
	if [ ! -d "${OUTPUT_DIR}/CONFIGURATIONS" ] ; then
		mkdir -p "${OUTPUT_DIR}/CONFIGURATIONS"
	fi
	if [ -z "$BK_VM_LOGIN" ] ; then
		BK_VM_LOGIN=$BK_DEFAULT_VALUE_VM_LOGIN
	fi
	# default value of the VNC port (if needed)
	if [ -z "$BK_VNC" ] ; then
		BK_VNC=$BK_DEFAULT_VALUE_VNC
	fi
	# default value of the SSH port (if needed)
	if [ -z "$BK_SSHP" ] ; then
		BK_SSHP=$BK_DEFAULT_VALUE_SSHP
	fi
	# default value of the run id (if needed)
	if [ -z "$BK_RUN_IDENTIFIER" ] ; then
		BK_RUN_IDENTIFIER="drid-"$(perl -e "printf '%0.5d', $(expr $RANDOM % 10000)")
	fi
	# checking for the private ket file
	if [ -z "$BK_PRIVATE_KEY_FILE" ] ; then
		bklc_ssh_key_file_parameter="-i $BK_DEFAULT_VALUE_PRIVATE_KEYFILE"
	else
		bklc_ssh_key_file_parameter="-i $BK_PRIVATE_KEY_FILE"
	fi
	# default value of the allocated cores (if needed)
	if [ -z "$BK_NBPROC" ] ; then
		BK_NBPROC=$BK_DEFAULT_VALUE_NBPROC
	fi
	# setting environment variables for output data (stderr, sampling and summary)
	if [ -z "$STDERR_FILE" ] ; then
		STDERR_FILE="${OUTPUT_DIR}/OUTPUTS/${bklc_toolname}_${bklc_inputname}_${BK_RUN_IDENTIFIER}_$(uname -n).stderr"	
	fi
	if [ -z "$SAMPLING_FILE" ] ; then
		SAMPLING_FILE="${OUTPUT_DIR}/CSV/${bklc_toolname}_${bklc_inputname}_${BK_RUN_IDENTIFIER}_$(uname -n).csv"	
	fi
	if [ -z "$SUMMARY_FILE" ] ; then
		SUMMARY_FILE="${OUTPUT_DIR}/CSV/summary-${bklc_toolname}.csv"	
	fi
	# let's launch the VM
	bklv $VMPATH #2> /dev/null
	# let's launch the monitor
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p "$BK_SSHP" $bklc_ssh_key_file_parameter $BK_VM_LOGIN@localhost '[ -e /usr/lib/sysstat/sadc ] && { rm -f ~/collected.db ; /usr/lib/sysstat/sadc -S XALL 1 ~/collected.db & } ;' &
	sleep 1
	# let's launch the command to be monitored (limited to the time confinement
	# thanks to Unix timeout command, cf conf/invocation_template.txt)
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p "$BK_SSHP" $bklc_ssh_key_file_parameter $BK_VM_LOGIN@localhost "$COMMAND" 2>> "$STDERR_FILE"
	# let's extract the VM execution informaion
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p "$BK_SSHP" $bklc_ssh_key_file_parameter $BK_VM_LOGIN@localhost 'kill $(pidof sadc) ; \
while IFS=$";" read -ra entry ; do [[ ${entry[3]} == "CPU" ]] && { _size=$(( ${#entry[@]} -1 )) ; echo -n "runid;%idle/cpu;" > idle.csv ; ( IFS=$";" ; echo "${entry[*]}" ) > cpu.csv ; continue ; } ; [[ ${entry[3]} == -1 ]] && { ts=${entry[2]} ;  ( IFS=$";" ; echo "${entry[*]}" ) >> cpu.csv ; echo -ne "\n'${BK_RUN_IDENTIFIER}';" >> idle.csv ; continue ; } ; [[ ${ts} == ${entry[2]} ]] && { echo -n "${entry[$_size]};" >> idle.csv ; } ; done <<< "$(sadf -T -d ~/collected.db -- -u -P ALL)" ; \
sadf -T -d ~/collected.db -- -r > mem.csv ; \
paste -d ";" cpu.csv mem.csv idle.csv | cut -d ";" --complement -f2,4,11,12,13 | sed "s/^/'$bklc_toolname';'$bklc_inputname';'$BK_EXAMINATION';/"' > "$SAMPLING_FILE"

	#halting the VM
	kill -9 $(ps ux | grep :$BK_SSHP | grep $VMPATH | grep -v grep | tr -s ' ' | cut -d ' ' -f 2)
	sleep 1 # to let the process disapear from the system table
}
# }}}

# {{{ BenchKit Launches Virtual Machine (bklv or launch_a_vm) 
################################################################################
# BenchKit Launches Virtual Machine (bklv or launch_a_vm) 
################################################################################

bklv_usage () {
	cat <<_eof_
${_run} : BenchKit Launch Virtual Machine
 $ ${_run} <path-to-disk-image>
$(common_usage)
_eof_
	exit ${1:-1} ;
}

bklv_launch () {
	KVM=$(which qemu-system-x86_64)
	if [ -z "$KVM" ] ; then
		KVM=$(which qemu-kvm)
	fi
	if [ -z "$KVM" ] ; then
		die "CANNOT EXECUTE, qemu-kvm is not installed"
	fi
	KEYBOARD=fr
	HDD=$1
	# checking for the private ket file
	if [ -z "$BK_PRIVATE_KEY_FILE" ] ; then
		bklv_ssh_key_file_parameter="-i $BK_DEFAULT_VALUE_PRIVATE_KEYFILE"
	else
		bklv_ssh_key_file_parameter="-i $BK_PRIVATE_KEY_FILE"
	fi
	if [ -z "$BK_NBPROC" ] ; then
		BK_NBPROC=$BK_DEFAULT_VALUE_NBPROC
	fi
	# launching the virtual machine
	$KVM -vnc :$BK_VNC \
		-enable-kvm\
		-smp $BK_NBPROC\
		-cpu $BK_CPU_TYPE \
		-daemonize \
		-k $KEYBOARD \
		-m $BK_MAXMEM \
		-drive file=$HDD \
		-net nic,vlan=1 -net user,vlan=1 -name MCC \
		-redir tcp:$BK_SSHP::22
	# checking if it is OK
	echo "Waiting for the VM to be ready (probing ssh)"
	while true ; do
	  echo -n "."
	  ssh -o ConnectTimeout=1 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $BK_SSHP $bklv_ssh_key_file_parameter root@localhost 'exit' 2> /dev/null
	  if [ $? -eq 0 ] ; then
		  break
	  fi
	done
	echo
}

bklv () {
	# default value of the VNC port (if needed)
	if [ -z "$BK_VNC" ] ; then
		BK_VNC=$BK_DEFAULT_VALUE_VNC
	fi
	# default value of the SSH port (if needed)
	if [ -z "$BK_SSHP" ] ; then
		BK_SSHP=$BK_DEFAULT_VALUE_SSHP
	fi
	# default value of the allocated memory (if needed)
	if [ -z "$BK_MAXMEM" ] ; then
		BK_MAXMEM=$BK_DEFAULT_VALUE_MEMORY
	fi
	# launching the vM
	bklv_launch $1
	# if needed, operating a vnc client
	if [ "$bklv_dovnc" = "YES" ] ; then
		(sleep 3 ; vncviewer localhost:$BK_VNC) &
	fi
}

# }}}

# {{{ BenchKit Launches a Benchmark (bklb or launch_a_benchmark) 
################################################################################
# BenchKit Launches a Benchmark (bklb or launch_a_benchmark) 
################################################################################

bklb_usage () {
	cat <<_eof_
${_run} : BenchKit Launches a Benchmark
 $ ${_run} -generate|-execute|-deploy <parameters>

	-generate: generates data for a given run. It must be invoked with the following parameters:

	<bench-id> <hostid> <vnodes> <login> <time-limit> <memory-limit> <vmlog> <filet> <filei> <filee> <location>

	with:
	  -	bench-id, an identifier that allows you to identify a consistent benchmark
	  -	hostid, the adresse of the execution machine
	  -	vnode, the number of cores you want to use on this machine
	  -	login, the qualified login on this machine to execute the tests
	  -	time-limit, the maximum time allowed for one tes to be executed (in seconds)
	  -	memory-limit, the maximum memory allowed for one tes to be executed (in MB)
	  -	vmlog, the login in the virtual machines executing the benchmark on the execution machine
	  -	filet, a file containing the list of tools to be processed (one tool per line)
	  -	filei, a file containing the list of inputs to be processed (one input per line)
	  -	filee, a file containing the list of examination to be processed (one examination per line)
	  -	location, the location of all disk image in the execution machine. If it is not an absolute
		path, the path will be concatened to \$HOME
	This command generates a benchmark file that represent your benchmark and that list all
	the executions to be performed on the target machine. Since each execution is referenced
	by a unique identifier, it is easy to extract parts of this benchmark description for
	later use or to rerun partially the tests

	the three last parameters are plain ASCII files with one entry per line. The format of
	the <filet> file is : <toolname>:<disk-image> where the tool name is an identifier to
	be transmitted to BenchKit for the execution of the VM and disk-image a disk-image file
	in vmdk or in qcow format.

	-execute: perform execution of a benchmark generated by means of the -generate option.
	It must be invoked with the following parameters:

	<file> <email>

	with:
	  -	file, being a file generated with the -generate option
	  -	email, being the email to send progression results

	-deploy: deploy some benchkit element on the target machine. It must be invoked in the
	following way

	-benchkit <jobfile>|-disk_images <jobfile> [<dir>]

	with:
	  -	-benchkit meaning the deployment of the sources in the home directory of the
		execution machine referenced by the job file.
	  -	-disk_images meaning an help to deploy the images disks referenced in
		the job file in the execution machine referenced in the job file. Original
		images to be copied are found in the directory referenced in the command
		line (. is assumed by default).
		IMPORTANT: if requested images are in qcow2 formats and if, in the local
		machine, you only have the vmdk images, conversion is done automatically.

$(common_usage)
_eof_
	exit ${1:-1} ;
}

bklb () {
	echo
	echo "----------------------------------------------------------------"
	echo "BenchKit $BENCHKIT_VERSION ($0)"
	echo "    F. Kordon & F. Hulin-Hubard"
	echo "----------------------------------------------------------------"
	echo
	if [ "$bklb_cmd" = "-deploy" ] ; then
		if [ "$bklb_deploy" = "-benchkit" ] ; then
			LINE=$(grep BK_CONFIGURATION $bklb_file)
			bklb_benchid=$(echo "$LINE" | cut -d ':' -f 2)
			bklb_login=$(echo "$LINE" | cut -d ':' -f 3)
			bklb_host=$(echo "$LINE" | cut -d ':' -f 4)
			echo "Deploying BenchKit on $bklb_login@$bklb_host for benchmark $bklb_benchid"
			make selfdistrib where=/tmp
			scp /tmp/BenchKit2.tgz $bklb_login@$bklb_host:
			ssh $bklb_login@$bklb_host 'if [ -d BenchKit2 ] ; then rm -rf BenchKit2 ; fi ; tar xzf BenchKit2.tgz ; rm -f BenchKit2.tgz ; cd BenchKit2 ; make install'
			rm -fr /tmp/BenchKit2*
		elif [ "$bklb_deploy" = "-disk_images" ] ; then
			if [ -z "$bklb_dir" ] ; then
				bklb_dir="."
			fi
			grep -v ^# $bklb_file | cut -d ',' -f 3 | sort -u > /tmp/vmtodeploy.$$
			disk_image_list=$(cut -d ',' -f 1 /tmp/vmtodeploy.$$)
			LINE=$(grep BK_CONFIGURATION $bklb_file)
			bklb_benchid=$(echo "$LINE" | cut -d ':' -f 2)
			bklb_login=$(echo "$LINE" | cut -d ':' -f 3)
			bklb_host=$(echo "$LINE" | cut -d ':' -f 4)
			bklb_location=$(echo "$LINE" | cut -d ':' -f 10)
			echo "Deployment for benchmark $bklb_benchid of the following VMs at $bklb_login@$bklb_host:$bklb_location"
			echo
			echo "$disk_image_list"
			echo
			echo "Do you confirm ? (Ctrl-C to cancel)"
			read AAA
			(DEPLOYED=""
			cd "$bklb_dir"
			export COPYFILE_DISABLE=true # disable special files under MacOS
			for imagefile in $(cat /tmp/vmtodeploy.$$) ; do
				# We first look for the disk image. If it is not there, it may
				# be because the image is in vmdk and qcow2 conversion has not
				# been done yet. Then let's transmit the vmdk and convert it
				# in qcow2 format.
				if [ -f "$imagefile" ] ; then
					echo "   Copying $imagefile at $bklb_login@$bklb_host:$bklb_location"
					#scp $imagefile $bklb_login@$bklb_host:$bklb_location
					tar czvf - $imagefile | ssh $bklb_login@$bklb_host 'tar xzvf -'
					ssh $bklb_login@$bklb_host "mv $imagefile $bklb_location"
					DEPLOYED="$DEPLOYED $imagefile"
				elif [ "$(echo "$imagefile" | cut -d '.' -f 2)" = "qcow2" ] ; then
					alternative_image=$(echo "$imagefile" | cut -d '.' -f 1).vmdk
					if [ -f "$alternative_image" ] ; then
						echo "   Copying $alternative_image at $bklb_login@$bklb_host:$bklb_location"
						tar czvf - $alternative_image | ssh $bklb_login@$bklb_host 'tar xzvf -'
						echo "   Converting $alternative_image into $imagefile"
						#ssh $bklb_login@$bklb_host "mv $alternative_image $bklb_location ; cd $bklb_location ; qemu-img convert $alternative_image -c -O qcow2 $imagefile"
						ssh $bklb_login@$bklb_host "mv $alternative_image $bklb_location ; cd $bklb_location ; qemu-img convert $alternative_image -O qcow2 $imagefile"
						DEPLOYED="$DEPLOYED $alternative_image"
					else
						echo "   Cannot find file $imagefile (or $alternative_image) in $bklb_dir, skipping"
					fi
				else
					echo "   Cannot find file $imagefile in $bklb_dir, skipping"
				fi
			done
			echo
			echo "The following images have been deployed:$DEPLOYED")
			#rm -f /tmp/vmtodeploy.$$
		else
			die "$0, unknown option after -deploy"
		fi
		exit
	elif [ "$bklb_cmd" = "-generate" ] ; then
		echo "Generating a benchmark with the following information:"
	else
		echo "Ready to execute a benchmark with the following information:"
		LINE=$(grep BK_CONFIGURATION $bklb_file)
		bklb_benchid=$(echo "$LINE" | cut -d ':' -f 2)
		bklb_login=$(echo "$LINE" | cut -d ':' -f 3)
		bklb_host=$(echo "$LINE" | cut -d ':' -f 4)
		bklb_vmlog=$(echo "$LINE" | cut -d ':' -f 6)
		bklb_vnode=$(echo "$LINE" | cut -d ':' -f 5)
		bklb_maxt=$(echo "$LINE" | cut -d ':' -f 7)
		bklb_maxm=$(echo "$LINE" | cut -d ':' -f 8)
		bklb_nbcore=$(echo "$LINE" | cut -d ':' -f 9)
		bklb_location=$(echo "$LINE" | cut -d ':' -f 10)
	fi
	echo "   - benchmark name            : $bklb_benchid"
	echo "   - execution machine         : $bklb_login@$bklb_host ($bklb_vnode virtual nodes)"
	echo "   - core per VM               : $bklb_nbcore"
	echo "   - login in VMs              : $bklb_vmlog"
	echo "   - confinement in VMs        : $bklb_maxt s and $bklb_maxm MB"
	echo "   - disk images location      : $bklb_location"
	if [ "$bklb_cmd" = "-generate" ] ; then
		echo "   - config file (tools)       : $bklb_ft"
		echo "   - config file (inputs)      : $bklb_fi"
		echo "   - config file (examinations): $bklb_fe"
		echo
	fi
	echo "----------------------------------------------------------------"
	if [ "$bklb_cmd" = "-execute" ] ; then
		echo "Do you confirm ? (ctrl-C to cancel):"
		read AAA
		echo "   Copying $bklb_file into the target machine"
		scp $bklb_file $bklb_login@$bklb_host:BenchKit2
		if [ "$(ssh $bklb_login@$bklb_host 'ls /tmp/$BK_DEFAULT_RESULT_BASEDIR_NAME 2> /dev/null')" ] ; then
			echo
			echo "WARNING, results from a previous execution remain, they will be destroyed"
			echo "Do you confirm ? (ctrl-C to cancel):"
			read AAA
		fi
		echo "   Launching the Benchmark"
		#ssh $bklb_login@$bklb_host "rm -rf $BK_DEFAULT_RESULT_BASEDIR_NAME 2> /dev/null ; cd BenchKit2 ; nohup ./bksc $bklb_file $bklb_email 2>&1 | mailx -s \"BenchKit, execution of $bklb_benchid\" $bklb_email &" &
		ssh $bklb_login@$bklb_host "rm -rf /tmp/$BK_DEFAULT_RESULT_BASEDIR_NAME 2> /dev/null ; cd BenchKit2 ; nohup ./bksc $(basename $bklb_file) $bklb_email > /dev/null 2> /dev/null &" &
		echo
		echo "Results will be sent by email to $bklb_email"
	elif [ "$bklb_cmd" = "-generate" ] ; then
		OUTPUT="${bklb_benchid}.bkjobs"
		echo "# the configuration (benchid, login, hostid, nb cores, login on the vm, max time, max memory, max core, location of vm in the execution machine)" > $OUTPUT
		echo "#BK_CONFIGURATION:$bklb_benchid:$bklb_login:$bklb_host:$bklb_vnode:$bklb_vmlog:$bklb_maxt:$bklb_maxm:$bklb_nbcore:$bklb_location" >> $OUTPUT
		GCPT=1
		cpt_executions=0
		grep -v ^# "$bklb_ft" | (while read LINE ; do
			tname=$(echo "$LINE" | cut -d ':' -f 1)
			dimg=$(echo "$LINE" | cut -d ':' -f 2)
			echo -n "   $tname "
			echo "#" >> $OUTPUT
			echo "# tool $tname ($dimg)" >> $OUTPUT
			for input in $(grep -v ^# $bklb_fi) ; do
				echo -n "."
				for examination in $(grep -v ^# $bklb_fe) ; do
					runID="${bklb_benchid}-"$(date +%s)$(perl -e "printf '%0.5d', $GCPT")
					GCPT=$(expr $GCPT + 1)
					echo "$runID,$tname,$dimg,$input,$examination" >> $OUTPUT
					cpt_executions=$(expr $cpt_executions + 1)
				done
			done
			echo
		done
		echo
		echo "Benchmark $bklb_benchid (in file $bklb_benchid.bkjobs) contains $cpt_executions runs")
	else
		die "ERR>>> internal error, option unknown"
	fi
}
# }}}

# {{{  BenchKit Halt a Virtual Machine (bkhv or halt_a_vm) 
################################################################################
# BenchKit Halt a Virtual Machine (bkhv or halt_a_vm) 
################################################################################

bkhv_usage () {
	cat <<_eof_
${_run} : BenchKit Halt Virtual Machine
 $ ${_run}
$(common_usage)
_eof_
	exit ${1:-1} ;
}

bkhv () {
	# default definition of the access to the BenchKit private key file (if needed)
	if [ -z "$BK_PRIVATE_KEY_FILE" ] ; then
		bkhv_ssh_key_file_parameter="-i $BK_DEFAULT_VALUE_PRIVATE_KEYFILE"
	else
		bkhv_ssh_key_file_parameter="-i $BK_PRIVATE_KEY_FILE"
	fi

	# default definition of the SSH port (if needed)
	if [ -z "$BK_SSHP" ] ; then
		BK_SSHP=$BK_DEFAULT_VALUE_SSHP
	fi
	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $bkhv_ssh_key_file_parameter -p "$BK_SSHP" root@localhost halt
}
# }}}

#	{{{ The scheduler, that orchestrates executions on a Physical machine
################################################################################
# The scheduler, that orchestrates executions on a Physical machine
################################################################################

bksc_usage () {
	cat <<_eof_
${_run} : Scheduler on the target executing machine
 $ ${_run} <benchmark file> <email for results>
$(common_usage)
_eof_
	exit ${1:-1} ;
}

bksc () {
	# Get the job FIFO
	if [ $# -ne 2 ] ; then
		bksc_usage
		exit 1
	else
		bksc_file=$1
		bksc_mail=$2
	fi
	if [ ! -f "$bksc_file" ] ; then
		die "ERR >> file $bksc_file is not there!"
	fi
	echo
	echo "----------------------------------------------------------------"
	echo "BenchKit $BENCHKIT_VERSION ($0)"
	echo "    F. Kordon & F. Hulin-Hubard"
	echo "----------------------------------------------------------------"
	echo

	# Get global parameters parameters from the benchmark file...
	LINE=$(grep BK_CONFIGURATION $bksc_file)
	export bksc_benchid=$(echo "$LINE" | cut -d ':' -f 2)
	bklc_login=$(echo "$LINE" | cut -d ':' -f 3) # we do not need these since we are already logged on the machine
	bklc_host=$(echo "$LINE" | cut -d ':' -f 4) # we do not need these since we are already logged on the machine
	export BK_VM_LOGIN=$(echo "$LINE" | cut -d ':' -f 6)
	export BK_MAXCORES=$(echo "$LINE" | cut -d ':' -f 5)
	export BK_MAXTIME=$(echo "$LINE" | cut -d ':' -f 7)
	export BK_MAXMEM=$(echo "$LINE" | cut -d ':' -f 8)
	export BK_NBPROC=$(echo "$LINE" | cut -d ':' -f 9)
	export BK_VM_PATH=$(echo "$LINE" | cut -d ':' -f 10)
	
	if [ "$(echo $BK_VM_PATH | cut -b1)" != "/" ] ; then
		export BK_VM_PATH=$HOME$BK_VM_PATH
	fi

	# Check if the disk images are all in .qcow2 format or not
	lst_vm=$(grep -v ^# $bksc_file | cut -d ',' -f 3 | sort -u | grep -v .qcow2$)
	if [ "$lst_vm" -a "$BK_MAXCORES" -gt 1 ] ; then
		echo "WARNING: not all disk images are in qcow format, only one core can be exploited in the current version of BenchKit"
		export BK_MAXCORES=1
	fi

	# This is the main running loop
	BEGIN_TIME=$(date +%s)
	grep -v ^# $bksc_file | grep -v BK_CONFIGURATION | (CurrentlyUsedVCores=0
		while read LINE ; do 
			# Get the local parameters for a given benchmark
			export BK_RUN_IDENTIFIER=$(echo "$LINE" | cut -d ',' -f 1)
			export BK_TOOL_NAME=$(echo "$LINE" | cut -d ',' -f 2)
			disk_img=$(echo "$LINE" | cut -d ',' -f 3)
			Input=$(echo "$LINE" | cut -d ',' -f 4)
			Examination=$(echo "$LINE" | cut -d ',' -f 5)
			# if the image format is qcow2, create a working copy
			if [ "$(echo $(basename $disk_img) | cut -d '.' -f 2)" = "qcow2" ] ; then
				KVMIMG=$(which qemu-img)
				if [ -z "$KVMIMG" ] ; then
					die "$0 WARNING!!!, qemu-img must be installed to operate qcow2 format"
				fi
				TMP_DISK_IMAGE="$BK_VM_PATH/$BK_RUN_IDENTIFIER.qcow2"
				$KVMIMG create -f qcow2 -b $BK_VM_PATH/$disk_img $TMP_DISK_IMAGE
			else
				TMP_DISK_IMAGE=""
			fi
			echo
			echo "================================================================"
			echo "running $BK_RUN_IDENTIFIER ($BK_TOOL_NAME, $Input, $Examination)"
			if [ "$TMP_DISK_IMAGE" ] ; then
				# simple way to avoid port conflicts - scritc increment. This
				# simpler strategy that limits the number of runs in a single
				# benchmark to 43500 ;-)
				if [ -z "$BK_SSHP" ] ; then
					BK_SSHP="$BK_DEFAULT_VALUE_SSHP"
				else
					BK_SSHP=$(expr $BK_SSHP + 1)
				fi
				BK_VNC=$(expr $BK_SSHP + 20000) # this lets ~ 1.8 hour delay (considering approx 3 execution perminute) before conflit between VNC and SSH, that is less than the confinement time for the MCC...
				(bklr $TMP_DISK_IMAGE $Input $Examination $BK_SSHP $BK_VNC
				rm -f $TMP_DISK_IMAGE) &
			
			else
				bklr $BK_VM_PATH/$disk_img $Input $Examination $BK_SSHP $BK_VNC & 
			fi
			#PROCESS_IDS="$PROCESS_IDS $!"
			CurrentlyUsedVCores=$(expr $
			 + 1) # increment for the case of 1 core use only...
			# wait for a free virtual core in the machine
			while true ; do
				if [ "$CurrentlyUsedVCores" -lt "$BK_MAXCORES" ] ; then
					break # there are some free core left
				else # all cores are busy, let's wait for one to terminate
					CurrentlyUsedVCores=$(ls $BK_VM_PATH/${bksc_benchid}*.qcow2 2>/dev/null | wc -l)
					#CurrentlyUsedVCores=$(ls $BK_VM_PATH/r*.qcow2 2>/dev/null | wc -l) # for rerun of mixed runs at MCC'2014
				fi
				sleep 1
			done
		done
		# now the main loop is finished, we wait for all remaining child processes
		wait
	)
	cd /tmp # se positionner juste au dessus du répertoire des résultats
	tar czf $bksc_benchid.tgz $BK_DEFAULT_RESULT_BASEDIR_NAME
	END_TIME=$(date +%s)
	DURATION=$(expr $END_TIME - $BEGIN_TIME)
	day=$(perl -e 'printf "%0.2d", '$DURATION' / 86400')
	hours=$(perl -e 'printf "%0.2d", ('$DURATION' % 86400) / 3600')
	min=$(perl -e 'printf "%0.2d", ('$DURATION' % 3600) / 60')
	sec=$(perl -e 'printf "%0.2d", '$DURATION' % 60')
	# To send emails
	MSG="Here are the results of $(echo $bksc_file | cut -d '.' -f 1) on $(uname -n) that lasted $day d, $hours h, $min mn, $sec s $($DURATION seconds)."
	# mail with attached document (may become too large)
	#echo $MSG | mailx -s "BenchKit: results of $(echo $bksc_file | cut -d '.' -f 1) on $(uname -n)" -a /tmp/$bksc_benchid.tgz $bksc_mail
	echo "results for  $(echo $bksc_file | cut -d '.' -f 1) on $(uname -n) are in /tmp/$bksc_benchid.tgz

You may get them thanks to the following command:

	scp $bklc_login@$bklc_host:/tmp/$bksc_benchid.tgz .

The benchmark lasted $day d, $hours h, $min mn, $sec s (a total of $DURATION seconds)." > /tmp/x_${bksc_file}.txt
   cat /tmp/x_${bksc_file}.txt | mailx -s "BenchKit: results of $(echo $bksc_file | cut -d '.' -f 1) on $(uname -n)" $bksc_mail
	# Special sending of a SMS (for fko only)
	wget --no-check-certificate -O /dev/null "https://smsapi.free-mobile.fr/sendmsg?user=19296963&pass=0EkrVzu8eHIQ60&msg=$(echo "$MSG" | sed -e 's/ /%20/g')" 
}

#	}}}

#	{{{ export_config (bkec) that is used to query the configuration file
################################################################################
# bkec
################################################################################

bkec_usage () {
	cat <<_eof_
${_run} : BenchKit Extract Configuration information
 $ $0 <data type> <config identifier>
 or
 $ $0 -listident

	<data type> to extract a given information, valutes are:
		-login		the login for the machine
		-host		the hostname of the machine
		-bkdir		the BenchKit directory
		-vmdir		the directory hosting VM images disk
		-outputdir	the directory BenchKit uses towrite outputs
		-nbvnode	the number of virtual nodes to be used for this machine
		-class		the class this machine belongs to
	-listident to get the list of machine identifiers
	$(common_usage)
_eof_
}

bkec () {
	echo "NOT IMPLEMENTED (default value for tests)"
	case ${bkec_cmd} in
		-login)
			echo "fko" ;;
		-host)
			echo "quadhexa-2.u-paris10.fr" ;;
		-bkdir)
			echo "/tmp" ;;
		-vmdir)
			echo "/tmp" ;;
		-outputdir)
			echo "/tmp" ;;
		-nbvnode)
			echo "4" ;;
		-class)
			echo "quadhexa" ;;
		-listident)
			echo "coucou --) a faire" ;;
	esac
}

#	{{{ monitor some current execution
################################################################################
# bkec
################################################################################

bkmonitor_usage () {
	cat <<_eof_
${_run} : BenchKit Extract Configuration information
 $ $0 [-continuous] <job file> [delay]

Displays information about the execution stage of the designated benchmark

	-continuous regularly checks the execution status (eveny minute) and ends
	once all executions are terminated
	<delay> the time interval between two updates (default is 22s)

$(common_usage)
_eof_
}

bkmonitor () {
	OS="$(uname -s)"
	if [ "$bkcontinuous" -a "$OS" != "Darwin" ] ; then
		echo "WARNING: -continuous is only available on MacOS"
		bkcontinuous=""
	fi
	bk_jobfile="$1"
	bk_delay="$2"
	if [ -z "$bk_delay" ] ; then
		bk_delay=15
	fi
	totaljobs=$(grep -v ^# $bk_jobfile | wc -l | tr -s ' ' | cut -d ' ' -f 2)
	LINE=$(grep BK_CONFIGURATION $bk_jobfile)
	bklc_login=$(echo "$LINE" | cut -d ':' -f 3)
	bklc_host=$(echo "$LINE" | cut -d ':' -f 4)
	while [ -z "$crtjobs" ] ; do
		crtjobs=$(ssh $bklc_login@$bklc_host 'grep -v ^### /tmp/BK_RESULTS/CSV/summary_* 2>/dev/null | wc -l | tr -s " " | cut -d " " -f 1') 
		if [ -z "$crtjobs" ] ; then
			sleep $bk_delay
		fi
	done
	percent=$(expr $crtjobs \* 100 / $totaljobs)
	if [ "$OS" = "Darwin" ] ; then
		if [ "$bkcontinuous" ] ; then
			(echo "stop enable" # display STOP button + shows first computation 
			echo "$percent $crtjobs executions done out of $totaljobs ($percent%)"
			sleep $bk_delay # only 10 seconds to display something in case the benchmark is finished
			while [ "$crtjobs" -lt "$totaljobs" ]  ; do
				percent=$(expr $crtjobs \* 100 / $totaljobs)
				echo "$percent $crtjobs executions done out of $totaljobs ($percent%)"
				crtjobs=$(ssh $bklc_login@$bklc_host 'grep -v ^### /tmp/BK_RESULTS/CSV/summary_* 2>/dev/null | wc -l | tr -s " " | cut -d " " -f 1');
				sleep $bk_delay
			done) | lib/CocoaDialog.app/Contents/MacOS/CocoaDialog progressbar --stoppable --title "BenchKit ($BENCHKIT_VERSION) status for $(basename $bk_jobfile .bkjobs)" &
		else
			(echo "$percent $crtjobs executions done out of $totaljobs ($percent%)"; sleep 5 ) | \
				lib/CocoaDialog.app/Contents/MacOS/CocoaDialog progressbar --title "BenchKit ($BENCHKIT_VERSION) status for $(basename $bk_jobfile .bkjobs)" &
		fi
	else
		echo "----------------------------------------------------------------"
		echo "BenchKit $BENCHKIT_VERSION ($0)"
		echo "    F. Kordon & F. Hulin-Hubard"
		echo "----------------------------------------------------------------"
		echo
		echo "$$crtjobs done out of $totaljobs ($percent%)"
	fi
	
}

# }}}

# {{{ Main program 
################################################################################
# Main program
################################################################################

#	{{{ BenchKit call method 
case "${_run}" in
	bkmonitor)
		_run="bkmonitor" ;;
	bksc|scheduler)
		_run="bksc" ;;
	bklr|launch_a_run)
		_run="bklr" ;;
	bklc|launch_a_command)
		_run="bklc" ;;
	bklv|launch_a_vm)
		_run="bklv" ;;
	bklb|launch_benchmark)
		_run="bklb" ;;
	bkhv|halt_a_vm)
		_run="bkhv" ;;
	bkec|export_config)
		_run="bkec" ;;
	bkmap)
		_run="bkmap" ;;
	*)
		die "Err > \"${_run}\" Unknown command" ;;
esac
#	}}}

#	{{{ Manage options 
while [ "$1" != "$(echo $1 | sed -e 's/^-//')" ] ; do
	case ${1} in
		-c|--config)
			cmd_config_file="${2}" 
			shift ;;
		-h|--help)
			echo "---------------------------------------------------"
			echo "BenchKit $BENCHKIT_VERSION"
			echo "    F. Kordon & F. Hulin-Hubard"
			echo "---------------------------------------------------"
			${_run}_usage 0 ;;
		-v|--version)
			echo "---------------------------------------------------"
			echo "BenchKit $BENCHKIT_VERSION"
			echo "    F. Kordon & F. Hulin-Hubard"
			echo "---------------------------------------------------"
			echo "last revised           : "$(echo $_benchkit_svn_date | cut -d ' ' -f 2,3)
			echo "last commited revision : "$(echo $_benchkit_svn_rev | cut -d ' ' -f 2)" (by "$(echo $_benchkit_svn_aut| cut -d ' ' -f 2)")"
			echo "---------------------------------------------------"
			exit;;
		-d|--debug)
			set -x ;;
		-login|-host|-bkdir|-vmdir|-outputdir|-outputdir|-nbvnode|-class)
			if [ "$_run" != "bkec" ]; then
				die "Err > \"$1\" : llegal argument for ${_run}" 
			fi
			if [ "$2" ] ; then
				bkec_cmd="$1"
				bkec_par="$2"
				shift
			else
				die "Err > \"$1\" requires a configuration identifier"
			fi ;;
		-listident)
			if [ "$_run" != "bkec" ]; then
				die "Err > \"$1\" : llegal argument for ${_run}" 
			fi 
			bkec_cmd="$1" ;;
		-vnc)
			if [ "$_run" != "bklv" ]; then
				die "Err > \"$1\" : llegal argument for ${_run}" 
			fi
			bklv_dovnc="YES";;
		-generate)
			if [ "$_run" != "bklb" -o "$#" -ne "13" ]; then
				die "Err > \"$*\" : llegal or malformed argument for ${_run}" 
			fi
			bklb_cmd="$1"
			bklb_benchid="$2"
			if [ "$bklb_benchid" != "$(echo "$bklb_benchid" | tr '_' 'x')" ] ; then
				die "Err > \"$bklb_benchid\" : Benchmark id must NOT contain _" 
			fi
			bklb_host="$3"
			bklb_vnode="$4"
			bklb_login="$5"
			bklb_maxt="$6"
			bklb_maxm="$7"
			bklb_vmlog="$9"
			bklb_nbcore="$8"
			bklb_ft="${10}"
			bklb_fi="${11}"
			bklb_fe="${12}"
			bklb_location="${13}"
			shift 10 ;;
		-execute)
			if [ "$_run" != "bklb" -o "$#" -ne "3" ]; then
				die "Err > \"$*\" : llegal or malformed argument for ${_run}" 
			fi
			bklb_cmd="$1"
			bklb_file="$2"
			bklb_email="$3"
			shift ;;
		-deploy)
			if [ "$_run" != "bklb" -o "$#" -lt "3" ]; then
				die "Err > \"$*\" : llegal or malformed argument for ${_run}" 
			fi
			bklb_cmd="$1"
			bklb_deploy="$2"
			bklb_file="$3"
			bklb_dir="$4"
			shift 2;;
		-continuous)
			if [ "$_run" != "bkmonitor" -o "$#" -lt "2" ]; then
				die "Err > \"$*\" : llegal or malformed argument for ${_run}" 
			fi
			bkcontinuous="YES" ;;
		-*)
			echo -e "> Unknown option \"-${OPTARG}\".\n" ;
			${_run}_usage 1 ;;
	esac
	shift
done

case ${_run} in
	bkmonitor)
		if [ $# -lt 1 ] ; then
			${_run}_usage ;
		fi ;;
	bklr)
		if [ $# -lt 2 ] ; then
			${_run}_usage ;
		fi ;;
	bklv)
		if [ $# -lt 1 ] ; then
			${_run}_usage ;
		fi ;;
	bklc)
		if [ $# -lt 2 ] ; then
			${_run}_usage ;
		fi ;;
esac
#	}}}

#	{{{ Manage options 

#}}}

#	{{{ main
init_env ;
${_run} "${@}" ;
#	}}}

# }}} End Main
