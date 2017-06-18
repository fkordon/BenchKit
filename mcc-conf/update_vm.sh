#/bin/bash

if [ $# -ne 2 ] ; then
	echo "usage : $0 <vm path> <port to redirect to ssh>"
	exit
fi

dimg=$1
port=$2

diskhome=$HOME/scratch

# converting disk image to vmdk
qemu-img convert $diskhome/$dimg.qcow2 -O vmdk $diskhome/$dimg.vmdk
#starting tthe VM
export BK_SSHP=$port
./bklv $diskhome/$dimg.vmdk
#loggin into the vm and doing stuff...
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -P $port -i ~/BenchKit2/conf/bk-private_key $HOME/StrippedAndSurprise.tgz mcc@localhost:
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $port -i ~/BenchKit2/conf/bk-private_key mcc@localhost 'tar xzf StrippedAndSurprise.tgz ; rm -f StrippedAndSurprise.tgz'
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $port -i ~/BenchKit2/conf/bk-private_key root@localhost 'systemctl power off'

sleep 10

(cd $diskhome ; tar czf $dimg.vmdk.tgz $dimg.vmdk)

rm -f $diskhome/$dimg.qcow2

# converting disk image to cqow2
qemu-img convert $diskhome/$dimg.vmdk -O qcow2 $diskhome/$dimg.qcow2
