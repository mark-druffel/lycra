#!/bin/bash
#########################################################################
# Install Known Dependencies  											#
# https://linuxize.com/post/how-to-install-r-on-ubuntu-20-04/			#
# https://cran.r-project.org/doc/manuals/R-admin.html#Installation  	#
#########################################################################
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
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/'
apt -y install r-base

#################
# Set local TZ	#
#################
timedatectl set-timezone "America/Los_Angeles"

#########################
# Get R_HOME location 	#
#########################
TMP_R_HOME=$(mktemp)
Rscript -e "writeLines(trimws(paste('R_HOME=',R.home()), whitespace = '[ \t\r\n]| '), con = '$TMP_R_HOME', sep='\n')"
source $TMP_R_HOME

#########################
# Create site library	#
#########################
USERS_HOME=/home/rstudio
R_LIBS_SITE=$USERS_HOME/site-library
mkdir $USERS_HOME
mkdir $R_LIBS_SITE

#########################
# 	Create Rprofile.site	
#########################
touch $R_HOME/etc/Rprofile.site
echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), shiny.launch.browser = TRUE)" >> $R_HOME/etc/Rprofile.site
echo ".Library.site <- '$R_LIBS_SITE'" >> $R_HOME/etc/Rprofile.site

#################################
# Retrieve Renviron.site file	#
#################################
TMP_RENVIRON_FILE=$(mktemp)
aws s3 cp $RENVIRON_FILE $TMP_RENVIRON_FILE

#####################################################
# 	Create Renviron.site								
# 	Add keys file with API keys to Renviron.site		
#####################################################
TMP_R_LIBS_SITE_ENV_VAR=$(mktemp)
Rscript -e "writeLines(c(trimws(paste0('R_LIBS_SITE=$R_LIBS_SITE:',Sys.getenv('R_LIBS_SITE')), whitespace = '[ \t\r\n]| '), trimws(paste0('R_LIBS_USER=$R_LIBS_SITE:',Sys.getenv('R_LIBS_USER')), whitespace = '[ \t\r\n]| ')), con = '$TMP_R_LIBS_SITE_ENV_VAR', sep='\n')"
cat $TMP_R_LIBS_SITE_ENV_VAR >> $R_HOME/etc/Renviron.site
echo 'SERVER_ENV=$SERVER_ENV' >> $R_HOME/etc/Renviron.site
# sudo bash -c 'echo "SERVER_ENV=$SERVER_ENV" >> $R_HOME/etc/Renviron.site'
cat $TMP_RENVIRON_FILE >> $R_HOME/etc/Renviron.site
# sudo bash -c 'cat '$TMP_RENVIRON_FILE' >> '$R_HOME/etc/Renviron.site''

#########################################################################
# 	Source R Library Reference File	(i.e. what R libraries to install) 	
#########################################################################
TMP_R_PKGS=$TMP_EC2_SETUP_FILES/exec/r_pkgs

#############################################################################################################################################################################
# 	Install R Packages																																						
# 	Packages listed with no other info are installed using install.packages from the https://cloud.r-project.org repo															
# 	Packages listed with github are installed using install_github and if SERVER_ENV='stage' the stage branch is downloaded for github packages in all propeller repos 	
# 	Packages listed with something other than github are installed using install.packages with that something as the repo.													
#############################################################################################################################################################################
Rscript -e "r_pkgs <- readLines('$TMP_R_PKGS', warn = F)[!grepl('#', readLines('$TMP_R_PKGS', warn = F))]" -e "r_pkgs <- r_pkgs[sapply(r_pkgs, nchar) > 0]" -e "get_pkgs <- function(pkg){ ifelse( grepl(pkg, pattern = ','), trimws(strsplit(pkg, split = ',')[[1]][1]), trimws(pkg) ) }" -e "get_repos <- function(pkg){ ifelse( grepl(pkg, pattern = ','), trimws(strsplit(pkg, split = ',')[[1]][2]), 'https://cran.rstudio.com/' ) }" -e "get_branches <- function(pkg, env){ ifelse( tolower(env) == 'stage' && grepl(pkg, pattern = 'propellerpdx'), '@stage', '' )}" -e "pkgs <- vapply(X = r_pkgs, FUN = get_pkgs, FUN.VALUE = character(1), USE.NAMES = F)" -e "repos <- vapply(X = r_pkgs, FUN = get_repos, FUN.VALUE = character(1), USE.NAMES = F)" -e "branches <- vapply(X = r_pkgs, FUN = get_branches, env = '$SERVER_ENV', FUN.VALUE = character(1), USE.NAMES = F)" -e "for(i in 1:length(pkgs) ){ if(tolower(repos[i]) != 'github'){ install.packages(pkgs[i], repos = if(repos[i]=='https://cran.rstudio.com/'){c('http://cran.rstudio.com','https://ftp.osuosl.org/pub/cran/','https://cran.wu.ac.at/')} else{ repos[i] }, dependencies = T, ncpus = 4 )} else{ remotes::install_github(repo = paste0(pkgs[i], branches[i]), dependencies = T, upgrade = 'always' )} } "

#################################################
# Create user group	& company batch account		#
#################################################
groupadd rstudioadmins
TMP_PWD=$(openssl rand -base64 24)
useradd -d $USERS_HOME -g sudo -G rstudioadmins -p $TMP_PWD $SERVICE_ACCOUNT
usermod -a -G crontab $SERVICE_ACCOUNT
Rscript --default-packages=slackr,stringr,aws.ec2metadata,magrittr,dplyr -e "dns <- aws.ec2metadata::metadata\$public_hostname()" -e "keypair_name <- stringr::str_split(aws.ec2metadata::metadata\$public_key() , pattern = " ")[[1]][[3]]" -e "instance_id <- aws.ec2metadata::metadata\$instance_id()" -e "suppressWarnings(slackr::slackr_setup(incoming_webhook_url = Sys.getenv('SLACK_BOT_WEBHOOK_URL'), bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN')))" -e "slackr::slackr_msg(glue::glue('New Server\nEnvironment: $SERVER_ENV\nInstance ID: {instance_id}\nPublic DNS: {dns}\nKeypair Name: {keypair_name}\nUser: $SERVICE_ACCOUNT\n Pwd: $TMP_PWD'), channel = '#server_setups')"

####################################################################################################
# Install Rstudio                                                                                  #    
# Latest version: https://rstudio.com/products/rstudio/download-server/redhat-centos               #
####################################################################################################
TMP_RSTUDIO_INSTALL=$(mktemp -d)
wget -O $TMP_RSTUDIO_INSTALL/rstudio-server-rhel-1.3.1093-x86_64.rpm https://download2.rstudio.org/server/centos6/x86_64/rstudio-server-rhel-1.3.1093-x86_64.rpm
apt -y install $TMP_RSTUDIO_INSTALL/rstudio-server-rhel-1.3.1093-x86_64.rpm 
rm -f -r "$TMP_RSTUDIO_INSTALL"

#################################
# Configure RStudio Java 		# 
#################################
R CMD javareconf
rstudio-server restart

#################################
# Add users and send passwords	#
#################################
TMP_USERS_FILE=$(mktemp)
aws s3 cp $USERS_FILE $TMP_USERS_FILE
while IFS= read -r line || [ -n "$line" ];
do 
	TMP_USER=$(echo "$line" | cut -d '@' -f 1)
	TMP_PWD=$(openssl rand -base64 24)
	Rscript --default-packages=slackr,stringr,aws.ec2metadata,magrittr,dplyr -e "dns <- aws.ec2metadata::metadata\$public_hostname()" -e "instance_id <- aws.ec2metadata::metadata\$instance_id()" -e "keypair_name <- stringr::str_split(aws.ec2metadata::metadata\$public_key() , pattern = ' ')[[1]][[3]]" -e "suppressWarnings(slackr::slackr_setup(incoming_webhook_url = Sys.getenv('SLACK_BOT_WEBHOOK_URL'), bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN')))" -e "user_data <- slackr::slackr_users() %>% dplyr::filter(email == '$line')" -e "user_data %$% slackr::slackr_msg(glue::glue('New Server\nEnvironment: $SERVER_ENV\nInstance ID: {instance_id}\nPublic DNS: {dns}\nKeypair Name: {keypair_name}\nUser: $TMP_USER\n Pwd: $TMP_PWD'), channel = paste0('@',name))"
	useradd -m -d $USERS_HOME -g users -G rstudioadmins -p $TMP_PWD $TMP_USER
	usermod -a -G crontab $TMP_USER
done < $TMP_USERS_FILE

#####################################
# Add ssh keys to user directory	#
#####################################
mkdir $USERS_HOME/.ssh
cp ~/.ssh/authorized_keys $USERS_HOME/.ssh/authorized_keys 


#####################################################################################################
# read/write/execute access for service account & rstudio admins 									#
# read/excute for other users (currently none) 														#
# for: 																								#
# group home (which includes site-library), Renviron.site, & Rprofile.site							#
# read/write/excute access for service account														#
# read/execute for rstudioadmins & users  															#
# for:																								#
# R program (in theory allows service account to update version of R )								#
#####################################################################################################
chown -R $SERVICE_ACCOUNT:rstudioadmins $USERS_HOME
chmod -R 775 $USERS_HOME
chown -R $SERVICE_ACCOUNT:rstudioadmins $R_HOME/etc/Rprofile.site
chmod -R 775 $R_HOME/etc/Rprofile.site
chown -R $SERVICE_ACCOUNT:rstudioadmins $R_HOME/etc/Renviron.site
chmod -R 775 $R_HOME/etc/Renviron.site
chown -R $SERVICE_ACCOUNT:rstudioadmins $R_HOME
chmod -R 755 $R_HOME
chown -R $SERVICE_ACCOUNT:rstudioadmins /home/$USERS_HOME/.ssh

#####################################
# Add cronR logging directories		#
#####################################
LOG_PATH=$USERS_HOME/logs
mkdir $LOG_PATH
chown -R $SERVICE_ACCOUNT:rstudioadmins $LOG_PATH
chmod -R 775 $LOG_PATH

#################################################
# Turn on cron system logs by removing comment	#
#################################################
sed -i '/^#.*cron/s/^#//' /etc/rsyslog.d/50-default.conf
systemctl restart rsyslog

#####################
# Create cron jobs	#
#####################
RSCRIPT_PATH=$R_HOME/bin/Rscript

JOB_LOCATION=$R_LIBS_SITE/dataPipeline/exec/invoke.R
JOB_NAME=dataPipeline_ytd
TMP_CRON_FILE=$LOG_PATH/$SERVICE_ACCOUNT
touch $TMP_CRON_FILE
touch $LOG_PATH/$JOB_NAME.log
chown -R $SERVICE_ACCOUNT:rstudioadmins $LOG_PATH/$JOB_NAME.log
chmod -R 755 $LOG_PATH/$JOB_NAME.log
echo "2 0 * * * $RSCRIPT_PATH --verbose --no-save --no-restore $JOB_LOCATION --year_expr 'lubridate::year(lubridate::today()-1)' --messaging T >> $LOG_PATH/$JOB_NAME.log 2>&1" > $TMP_CRON_FILE
#Rscript --default-packages=cronR,stringr,lubridate,glue -e "package <- 'dataPipeline'" -e "exec <- 'invoke.R'" -e "dataPipeline_ytd_args <- c(r\"(--year_expr 'lubridate::year(lubridate::today()-1)')\", '--verbose T')" -e "dataPipeline_ytd_cmd <- cron_rscript(rscript = system.file('exec', exec, package = package), rscript_args = dataPipeline_ytd_args, rscript_log = sprintf('%s%s.log', '/home/$RSTUDIO_USER/logs/$cronR_job_id', '-%F%t%T'), log_append = F)" -e "cron_add(command = dataPipeline_ytd_cmd, id = 'dataPipeline_ytd', frequency = 'daily', at='2AM', tags = c('dataPipeline','ytd'), description = 'Daily dataPipeline ytd')"

#####################################
# Move crontab for scheduling		#
# Change crontab file permissions	#
#####################################
cp $TMP_CRON_FILE /var/spool/cron/crontabs/$SERVICE_ACCOUNT
chmod 600 /var/spool/cron/crontabs/$SERVICE_ACCOUNT
touch /var/spool/cron/crontabs/$SERVICE_ACCOUNT

#################
# Start cron 	#
#################
service cron restart

#####################################
# Add password to rstudio account	# 
# Copy setup logs to users path		#
#####################################
Rscript  --default-packages=slackr,aws.ec2metadata -e "instance_id <- aws.ec2metadata::metadata\$instance_id()" -e "slackr_upload(filename = '/var/log/cloud-init-output.log', title = instance_id, channels = '#server_setups', bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN'))"
cp /var/log/cloud-init-output.log $LOG_PATH

#############
# cleanup	# 
#############
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