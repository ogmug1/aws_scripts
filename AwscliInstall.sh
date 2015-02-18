#####
#####
##
##
## Created by Paul Beebe
## 2/18/2015
##
##
## This script is intended to use curl to get aws-cli and install it in the CWD. If the user is root, it will install it in /root
## It checks for the existance of zip/unzip before it downloads it, and installs that if it missing. This is written for use in 
## macs and linux servers. However it will not install packages for MAC. 
##
##
#####
#####
OS=`uname -s`
if [ $OS = "Linux" ]
	then

# determine if zip or unzip is present
	UNZIP=`dpkg -s unzip |grep ^Status`

	if [ -z $UNZIP ]
		then
		echo "Unzip is not installed. Installing unzip using apt."
		apt-get install -y zip unzip
	fi	
fi

# get aws-cli
curl 'https://s3.amazonaws.com/aws-cli/awscli-bundle.zip' -o './awscli-bundle.zip'

#unzip
if [ $OS = "Linux" ]
	then
	/usr/bin/unzip ./awscli-bundle.zip
	else
	unzip ./awscli-bundle.zip
fi

# run the installler

./awscli-bundle/install -b ~/bin/aws

# Test aws installation
AWSINST=`aws help|head -10`
if [ -z "$AWSINST" ]
	then
	echo "Installation failed. Please troubleshoot and if necessary contact Paul Beebe"
	exit 1
fi

echo
echo "Running aws configure and enter in your keys."
echo
aws configure


