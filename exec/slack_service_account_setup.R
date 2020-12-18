doc <-'Slack service account details to the service account channel

Usage:
  slack_service_account_setup.R  --envir <path> --service_acconut <name> --pwd <pwd> 

Options:
 --envir <name>             Name of the environment specified during the build; no default 
 --service_account <name>   Service account name for login; no default
 --pwd <pwd>                Service account pwd for login; no default'
opts <- docopt::docopt(doc)

# get AWS info ------------------------------------------------------------
library(aws.ec2metadata)
dns <- aws.ec2metadata::metadata$public_hostname()
keypair_name <- stringr::str_split(aws.ec2metadata::metadata$public_key() , pattern = " ")[[1]][[3]] 
instance_id <- aws.ec2metadata::metadata$instance_id() 
channel <- paste0("#server_setup_", tolower(opts$envir))

# slack -------------------------------------------------------------------
library(slackr)
slackr::slackr_setup(incoming_webhook_url = Sys.getenv('SLACK_BOT_WEBHOOK_URL'), bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN')) 
slackr::slackr_msg(glue::glue('Server Details\nEnvironment: {opts$envir}\nInstance ID: {instance_id}\nPublic DNS: {dns}\nSSH Keypair: {keypair_name}\nUsername: {opts$service_account}\n Pwd: {opts$pwd}'), channel = channel)