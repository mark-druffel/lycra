doc <-'Slack user account details to the user, email used to match users in Slack

Usage:
  Rscript lycra_path/slack_user_account_setup.R  --envir <path> --user_account <name> --pwd <pwd> 

Options:
 --envir <name>           Name of the environment specified during the build; no default 
 --user_account <name>    User account email (not username) which is used to find the slack account; no default
 --pwd <pwd>              User account pwd for login; no default'
opts <- docopt::docopt(doc)

# get AWS info ------------------------------------------------------------
library(aws.ec2metadata)
dns <- aws.ec2metadata::metadata$public_hostname() 
instance_id <- aws.ec2metadata::metadata$instance_id()
keypair_name <- stringr::str_split(aws.ec2metadata::metadata$public_key() , pattern = ' ')[[1]][[3]] 

# slack -------------------------------------------------------------------
library(slackr)
library(magrittr)
slackr::slackr_setup(incoming_webhook_url = Sys.getenv('SLACK_BOT_WEBHOOK_URL'), bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN'))
user_data <- slackr::slackr_users() %>% dplyr::filter(email == 'opts$user_account') 
user_data %$% 
  slackr::slackr_msg(glue::glue('Server Details\nEnvironment: {opts$envir}\nInstance ID: {instance_id}\nPublic DNS: {dns}\nSSH Keypair: {keypair_name}\nUser: {opts$user_account}\n Pwd: {opts$pwd}'), channel = paste0('@',name))