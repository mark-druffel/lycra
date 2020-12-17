doc <-'lycra slack_cloud_init

Usage:
  lycra slack_cloud_init  --envir <path> [ cloud_int <path> ]

Options:
 --envir <name>           Name of the environment specified during the build; no default 
 --cloud_int <path>    User account name for login; no default
 --pwd <pwd>              User account pwd for login; no default'
opts <- docopt::docopt(doc)

# get AWS info ------------------------------------------------------------
library(aws.ec2metadata)
instance_id <- aws.ec2metadata::metadata$instance_id() 
channel <- paste0("#server_setup_", tolower(opts$envir))

# slack -------------------------------------------------------------------
library(slackr)
slackr::slackr_setup(incoming_webhook_url = Sys.getenv('SLACK_BOT_WEBHOOK_URL'), bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN')) 
slackr_upload(filename = '/var/log/cloud-init-output.log', title = instance_id, channels = channel, bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN'))