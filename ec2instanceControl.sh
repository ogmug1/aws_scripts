########
########
## ec2instanceControl.sh
##
##
## Created by Paul Beebe
## Created on : 2/9/2015
##
##
## this script is designed to work with aws cli from the command line in linux (though it may also work for mac). 
## it needs to be set up properly: IE: having run aws configure beforehand and entered in the appropriate credentials
## additionally this is set for region: us-west-2 and will select an ubuntu free tier image and put it on a t1.micro
## if you are in an different default region, you will need to replace the variables below with your own
##
## This program was designed to assist in creating and terminating one instance on the free tier. No warranty is implied
## if you have more than one instance.
##
########
########

# AWS variables you will need to adjust these to your own instances. 
AWSREG="us-west-2"
AWSAMI="ami-23ebb513"
AWSTYPE="t1.micro"
AWSKEY="ogmug1"
AWSSECGP="default"
AWSACCSEC=`echo $aws_access_key_id`
AWSACCSECKEY=`echo $aws_secret_access_key`
AWSDIR="/root/.aws"
AWSCONFIG="/root/.aws/config"
AWSCRED="/root/.aws/credentials"

# list of packages to be installed after startup
PKGS="ansible python-pip zip unzip git"

# Ansible directory structure
ANSDIR1="/var/lib/ansible/{production,stage} group_vars host_vars library filter_plugins roles/{common/{tasks handlers templates files vars defalts meta} webtier monitoring fooapp}}"

if [ -z $1 ]
	then
	echo "need argument: either start or stop"
	exit 1
fi


# case statement for start or stop

case $1 in

# start ec2 instance 

	start)
		echo "checking for existing instance"
		INSTANCE=`aws ec2 describe-instances |grep -i instanceid |awk -F\" '{print$4}'|head -1` 
		INSTANCESTATE=`aws ec2 describe-instances  |grep -A1 -i code |grep -i -A1 code |awk -F\" '{print$4}' | grep -i running`
		if [ -n "$INSTANCE" ]  && [ -n "$INSTANCESTATE" ]
			then
			echo "instance already running. Terminating program. Please check to see if instance is already running via GUI"
			exit 1
		else
		echo "starting instance in EC2"
		aws ec2 run-instances --image-id $AWSAMI --count 1 --instance-type $AWSTYPE --key-name $AWSKEY --security-groups $AWSSECGP
		sleep 10
		while true ; do 
			clear
			echo ; echo ; echo
			CURSTATE=`aws ec2 describe-instances --filter="Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" |grep -A2 '"State": {' |awk -F\" '{print$4}' |tail -1`
			echo "Current state is $CURSTATE"
			if [ "$CURSTATE" = "running" ]
				then
				echo " System is up and running. Installing ansible. You can attach to the server using the IP/NAME below:"
				aws ec2 describe-instances --filter "Name=instance-state-name,Values=running" |grep "PublicDnsName\|PublicIpAddress" |head -2

echo
echo "waiting for subsystems to finish starting. 60 second default time"
echo

sleep 60

# installing ansible
				echo
				echo "Installing Ansible"
				INSTANCEIP=`aws ec2 describe-instances --filter "Name=instance-state-name,Values=running" |grep "PublicIpAddress" |head -1 |awk -F\" '{print$4}'`

				/usr/bin/ssh -o StrictHostKeyChecking=no -i /root/.ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo apt-get -y install software-properties-common"
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo apt-add-repository ppa:ansible/ansible"
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo apt-get update"
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo apt-get -y install $PKGS"
# install python-boto
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo pip install -U boto"

# install AWSCLI
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo curl 'https://s3.amazonaws.com/aws-cli/awscli-bundle.zip' -o '/root/awscli-bundle.zip'" 
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo unzip /root/awscli-bundle.zip -d /root/" 

# set up aws config and credentials. 

# config
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo mkdir -p $AWSDIR"
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo sh -c 'echo \"[default]\" >$AWSCONFIG'"
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo sh -c 'echo \"output = json\" >>$AWSCONFIG'"
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo sh -c 'echo \"region = \"$AWSREG >>$AWSCONFIG'"

# Credentials 
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo sh -c 'echo $AWSACCSEC >$AWSCONFIG'"
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo sh -c 'echo $AWSACCSECKEY >>$AWSCONFIG'"

# create ansible dir structure

				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo mkdir -p /var/lib/ansible/{production,stage,group_vars,host_vars} "
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo mkdir -p /var/lib/ansible/{library filter_plugins } "
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo mkdir -p /var/lib/ansible/roles/common/{tasks,handlers,templates,files,vars,defaults,meta} "
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo mkdir -p /var/lib/ansible/roles/{webtier,monitoring,fooapp}"

# install ec2.py for dynamic inventory
				
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo sh -c 'curl \"https://raw.githubusercontent.com/ansible/ansible/devel/plugins/inventory/ec2.py\" > /var/lib/ansible/ec2.py '"
				ssh -o StrictHostKeyChecking=no -i .ssh/$AWSKEY.pem ubuntu@$INSTANCEIP "sudo sh -c 'curl \"https://raw.githubusercontent.com/ansible/ansible/devel/plugins/inventory/ec2.ini\" > /var/lib/ansible/ec2.ini '"
	
	

				exit 0
			fi
			sleep 10 
			CURSTATE=""
		done
	fi
;;

# stop ec2 instance

	stop)
# get instance ID
		INSTANCE=`aws ec2 describe-instances --filter "Name=instance-state-name,Values=running"|grep -i instanceid |awk -F\" '{print$4}'` 

# if we have more than  one running instance, error out and do nothing

		COUNT=`echo $INSTANCE |wc -l`
		if [ $COUNT != "1" ]
			then
			echo "There is more than one running instance. This script is for the starting and terminating of only one instance. This script will exit without doing anything, and please log on via the GUI to shutdown instances"
			exit 1
		fi

		echo "stopping instance $INSTANCE in EC2"

# stop specific instanceID

# check for a running instance. If there isn't one, then exit

		CURSTATE=`aws ec2 describe-instances --filter="Name=instance-state-name,Values=running" |grep -A2 '"State": {' |awk -F\" '{print$4}' |tail -1`
		if [ -z $CURSTATE ]
			then 
			echo "No running instances"
			exit 0
		fi

		aws ec2 terminate-instances --instance-ids $INSTANCE
		while true ; do 
			clear
			echo ; echo ; echo
			CURSTATE=`aws ec2 describe-instances --instance-ids $INSTANCE |grep -A2 '"State": {' |awk -F\" '{print$4}'|tail -1`
			echo "Current state: $CURSTATE"
			if [ "$CURSTATE" = "terminated" ]
				then
				echo " System is shutdown and terminated"
				exit 0
			fi
			sleep 10 
			CURSTATE=""
		done
;;

*)
	echo "Incorrect argument: must be start or stop"
	exit 1
;;
esac
