#!/bin/bash
###########################################################################
# 	Install Known Dependencies  											
# 		https://linuxize.com/post/how-to-install-r-on-ubuntu-20-04/			
# 		https://cran.r-project.org/doc/manuals/R-admin.html#Installation  
#		https://fahim-sikder.github.io/post/how-to-install-r-ubuntu-20/
###########################################################################
echo "Installing apt dependencies"
apt -y update
apt -y upgrade
apt -y install dirmngr gnupg apt-transport-https ca-certificates software-properties-common
apt -Y install bzip2
apt -y install nginx
apt -y install libssl-dev
apt -y install texlive-base
apt -y install default-jre
apt -y install default-jdk
apt -y install libmagick++-dev 
apt -y install gfortran 
apt -y install libcairo2-dev
apt -y install xorg-dev
apt -y install libfribidi-dev
apt -y install libharfbuzz-dev
apt -y install libpng-dev
apt -y install libjpeg-dev
apt -y install libtiff-dev
apt -y install vflib3-dev
apt -y install openbox
apt -y install libsodium-dev
apt -y install libxml2-dev
apt -y install libcurl4-openssl-dev 
apt -y install libharfbuzz-dev
apt -y install libfribidi-dev
apt -y install awscli
apt -y install unixodbc-dev
apt -y install libpq-dev
apt -y install libudunits2-dev 
apt -y install libmariadbclient-dev
apt -y install libgit2 
apt -y install libv8-dev
apt -y install libglpk-dev
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/'
apt -y install r-base

#####################
# 	Set local TZ	
#####################
echo "Setting local timezone"
timedatectl set-timezone "America/Los_Angeles"

###########################
# 	Get R_HOME location 	
###########################
echo "Getting R_HOME"
TMP_R_HOME=$(mktemp)
Rscript -e "writeLines(trimws(paste('R_HOME=',R.home()), whitespace = '[ \t\r\n]| '), con = '$TMP_R_HOME', sep='\n')"
source $TMP_R_HOME

###########################
# 	Create site library	
###########################
echo "Creating site library and users home"
USERS_HOME=/home/rstudio
SITE_LIB=$USERS_HOME/site-library
mkdir $USERS_HOME
mkdir $SITE_LIB

############################
# 	Create Rprofile.site	
############################
echo "Setting up Rprofile.site"
touch $R_HOME/etc/Rprofile.site
echo "options(repos = c(CRAN = c('http://cran.rstudio.com','https://cloud.r-project.org','https://ftp.osuosl.org/pub/cran/')), shiny.launch.browser = TRUE)" > $R_HOME/etc/Rprofile.site
echo ".Library.site <- '$SITE_LIB'" >> $R_HOME/etc/Rprofile.site

##################################
# 	Retrieve Renviron.site file	
##################################
echo "Setting up Renviron.site"
TMP_RENVIRON_FILE=$(mktemp)
aws s3 cp $RENVIRON_FILE $TMP_RENVIRON_FILE

#####################################################
# 	Create Renviron.site								
# 	Add keys file with API keys to Renviron.site		
#####################################################
TMP_R_LIBS_SITE_ENV_VAR=$(mktemp)
Rscript -e "R_LIBS_SITE <- Sys.getenv('R_LIBS_SITE')" -e "R_LIBS_USER <- Sys.getenv('R_LIBS_USER')" -e "writeLines(c(trimws(paste0('R_LIBS_SITE=$SITE_LIB:',R_LIBS_SITE), whitespace = '[ \t\r\n]| '), trimws(paste0('R_LIBS_USER=$SITE_LIB:',R_LIBS_USER), whitespace = '[ \t\r\n]| ')), con = '$TMP_R_LIBS_SITE_ENV_VAR', sep='\n')"
cat $TMP_R_LIBS_SITE_ENV_VAR >> $R_HOME/etc/Renviron.site
echo "SERVER_ENV=$SERVER_ENV" >> $R_HOME/etc/Renviron.site
# sudo bash -c 'echo "SERVER_ENV=$SERVER_ENV" >> $R_HOME/etc/Renviron.site'
cat $TMP_RENVIRON_FILE >> $R_HOME/etc/Renviron.site
# sudo bash -c 'cat '$TMP_RENVIRON_FILE' >> '$R_HOME/etc/Renviron.site''

#########################################################################
# 	Install docopt	
#########################################################################
echo "Installing docopt"
Rscript -e "install.packages('docopt', dependencies = c('Depends','Imports'), Ncpus = $NCPUS)"

#############################################################################################################################################################################
# 	Install R Packages
# 	Packages listed with no other info are installed using install.packages from the https://cloud.r-project.org repo		
# 	Packages listed with github are installed using install_github and if SERVER_ENV='stage' the stage branch is downloaded for github packages in all propeller repos
# 	Packages listed with something other than github are installed using install.packages with that something as the repo.
# 	https://github.com/stan-dev/rstan/wiki/Installing-RStan-from-Source#linux
#############################################################################################################################################################################
echo "Installing R pkgs"
TMP_R_PKGS=$TMP_EC2_SETUP_FILES/exec/r_pkgs
Rscript $TMP_EC2_SETUP_FILES/exec/install_packages.R --packages $TMP_R_PKGS --envir $SERVER_ENV --user_home $USERS_HOME --Ncpus $NCPUS

#################################################
# 	Create user group	& company batch account		
#################################################
echo "Setting up users groups and service account"
groupadd rstudioadmins
#groupadd sftp
TMP_PWD=$(openssl rand -base64 24)
useradd -d $USERS_HOME -g sudo -G rstudioadmins $SERVICE_ACCOUNT
usermod -a -G crontab $SERVICE_ACCOUNT
#usermod -a -G sftp $SERVICE_ACCOUNT
echo "$SERVICE_ACCOUNT:$TMP_PWD" | chpasswd
# Slack the details to the locked channel, might want to write to S3 as alternative
Rscript $TMP_EC2_SETUP_FILES/exec/slack_service_account_setup.R --envir $SERVER_ENV --service_account $SERVICE_ACCOUNT --pwd $TMP_PWD

###################################
# 	Add users and send passwords	
###################################
echo "Setting up users from list"
TMP_USERS_FILE=$(mktemp)
aws s3 cp $USERS_FILE $TMP_USERS_FILE
for user in `more $TMP_USERS_FILE`
do 
	TMP_USER=$(echo "$user" | cut -d '@' -f 1)
	TMP_PWD=$(openssl rand -base64 24)
	useradd -m -d $USERS_HOME -g users -G rstudioadmins $TMP_USER
	usermod -a -G crontab $TMP_USER
	#usermod -a -G sftp $TMP_USER
	echo "$TMP_USER:$TMP_PWD" | chpasswd
	Rscript $TMP_EC2_SETUP_FILES/exec/slack_user_account_setup.R --envir $SERVER_ENV --user_account $user --pwd $TMP_PWD
done

####################################################################################################
# 	Install Rstudio                                                                                      
# 	Latest version: https://rstudio.com/products/rstudio/download-server/redhat-centos               
####################################################################################################
echo "Installing RStudio"
TMP_RSTUDIO_INSTALL=$(mktemp -d)
sudo apt-get install gdebi-core
wget -O $TMP_RSTUDIO_INSTALL/rstudio-server-1.3.1093-amd64.deb https://download2.rstudio.org/server/bionic/amd64/rstudio-server-1.3.1093-amd64.deb
gdebi $TMP_RSTUDIO_INSTALL/rstudio-server-1.3.1093-amd64.deb
rm -f -r $TMP_RSTUDIO_INSTALL

#################################
# 	Configure RStudio Java 		 
#################################
R CMD javareconf
rstudio-server restart

#######################################
# 	Add cronR logging directories		
#######################################
echo "Setting up cron jobs"
LOG_PATH=$USERS_HOME/logs
mkdir $LOG_PATH
chown -R $SERVICE_ACCOUNT:rstudioadmins $LOG_PATH
chmod -R 775 $LOG_PATH

#####################################################
# 	Turn on cron system logs by removing comment	
#####################################################
sed -i '/^#.*cron/s/^#//' /etc/rsyslog.d/50-default.conf
systemctl restart rsyslog

#########################
# 	Create cron jobs	
#########################
RSCRIPT_PATH=$R_HOME/bin/Rscript


TMP_CRON_FILE=$LOG_PATH/$SERVICE_ACCOUNT
touch $TMP_CRON_FILE

JOB_LOCATION=$SITE_LIB/dataPipeline/exec/invoke.R
JOB_NAME=dataPipeline_ytd
JOB_LOG=$LOG_PATH/$JOB_NAME.log
touch $JOB_LOG
echo "05 0 * * * $RSCRIPT_PATH --verbose --no-save --no-restore $JOB_LOCATION --year 'lubridate::year(lubridate::today()-1)' --verbose T >> $JOB_LOG 2>&1" > $TMP_CRON_FILE

JOB_LOCATION=$SITE_LIB/dataPipeline/exec/invoke.R
JOB_NAME=dataPipeline_jan_reruns
JOB_LOG=$LOG_PATH/$JOB_NAME.log
echo "0 3-23/3 1-21 1 * $RSCRIPT_PATH --verbose --no-save --no-restore $JOB_LOCATION --year 'lubridate::year(lubridate::today()-lubridate::days(x=30))' --verbose T >> $JOB_LOG 2>&1" >> $TMP_CRON_FILE

chown -R $SERVICE_ACCOUNT:rstudioadmins $LOG_PATH/$JOB_NAME.log
chmod -R 755 $LOG_PATH/$JOB_NAME.log

#######################################
# 	Move crontab for scheduling		
# 	Change crontab file permissions	
#######################################
cp $TMP_CRON_FILE /var/spool/cron/crontabs/$SERVICE_ACCOUNT
chown  $SERVICE_ACCOUNT:crontab /var/spool/cron/crontabs/$SERVICE_ACCOUNT
chmod 600 /var/spool/cron/crontabs/$SERVICE_ACCOUNT

#################
# 	Start cron 	
#################
service cron restart

#######################################
# 	Add ssh keys to user directory	
# 	This isn't working, need to read the AWS documentation
#######################################
#mkdir $USERS_HOME/.ssh
#cp ~/.ssh/authorized_keys $USERS_HOME/.ssh/authorized_keys 
# Can import users keypairs from R, don't know if I can put all user keypairs in a shared home and just provide read only access to each .ssh file by user? 
# aws.ec2metadata::metadata$item("meta-data/public-keys")
# aws.ec2::describe_keypairs()

#####################################################################################################
# 	read/write/execute access for service account & rstudio admins 									
# 	read/excute for other users (currently none) 														
# 	for: 																								
# 		group home (which includes site-library), Renviron.site, & Rprofile.site							
# 	
#	read/write/excute access for service account														
# 	read/execute for rstudioadmins & users  															
# 	for:																								
# 		R program (in theory allows service account to update version of R )								
#####################################################################################################
echo "Modifying permissions"
chown -R $SERVICE_ACCOUNT:rstudioadmins $USERS_HOME
chmod -R 775 $USERS_HOME
chown -R $SERVICE_ACCOUNT:rstudioadmins $R_HOME/etc/Rprofile.site
chmod -R 775 $R_HOME/etc/Rprofile.site
chown -R $SERVICE_ACCOUNT:rstudioadmins $R_HOME/etc/Renviron.site
chmod -R 775 $R_HOME/etc/Renviron.site
chown -R $SERVICE_ACCOUNT:rstudioadmins $R_HOME
chmod -R 755 $R_HOME
#chown -R $SERVICE_ACCOUNT:rstudioadmins /home/$USERS_HOME/.ssh

##########################################################################################
# 	SFTP configurations
#	https://linuxhandbook.com/sftp-server-setup/
# 	https://www.golinuxcloud.com/sftp-chroot-restrict-user-specific-directory/
##########################################################################################
#TMP_SFTP_HOME=/home/sftp 
#mkdir $TMP_SFTP_HOME
#groupadd sftpjail

##############################
# Add user for vendors
##############################
#TMP_JOBVITE_HOME=$TMP_SFTP_HOME/$vendor
#TMP_PWD_JOBVITE=$(openssl rand -base64 24)
#useradd -m -d $TMP_SFTP_HOME/$vendor -g sftpjail -p $TMP_PWD $vendor

#######################################
# 	Add password to rstudio account	 
# 	Copy setup logs to users path		
#######################################
echo "Sending cloud.init"
Rscript $TMP_EC2_SETUP_FILES/exec/install_packages.R  --envir $SERVER_ENV
cp /var/log/cloud-init-output.log $LOG_PATH

###############
# 	cleanup	
###############
rm -f $TMP_AWS_CLI
rm -f $TMP_RSTUDIO_INSTALL
rm -f $TMP_RENVIRON_FILE
rm -f $TMP_USERS_FILE
rm -f $TMP_CRON_FILE
#####################################################################################################
# Install Shiny Server                                                                          	#    
# Latest version: https://rstudio.com/products/shiny/download-server/redhat-centos/					#
#####################################################################################################
#TMP_SHINY_SERVER_INSTALL=$(mktemp)
#wget -O $TMP_SHINY_SERVER_INSTALL https://download2.rstudio.org/server/centos6/x86_64/rstudio-server-rhel-1.3.1093-x86_64.rpm
#yum -y install --nogpgcheck $TMP_SHINY_SERVER_INSTALL
#rm -f "$TMP_SHINY_SERVER_INSTALL"