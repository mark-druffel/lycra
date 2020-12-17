## Does not work without a seperate pkg parser, not worth the effort at the moment - just use cloud-init

doc <-'lycra slack_cloud_init

Usage:
  lycra slack_cloud_init  --envir <path> [ cloud_int <path> ]

Options:
 --envir <name>           Name of the environment specified during the build; no default 
 --cloud_int <path>    User account name for login; no default
 --pwd <pwd>              User account pwd for login; no default'
log_file <- tempfile()
log <- log4r::logger(threshold = "INFO", appenders = log4r::file_appender(file = log_file, append = T))
purrr::map(pkgs, function(x){if( !x %in% installed.packages()){ log4r::error(log, glue::glue("{x} is not in installed packages")) } })


# get AWS info ------------------------------------------------------------
library(aws.ec2metadata)
instance_id <- aws.ec2metadata::metadata$instance_id() 
channel <- paste0("#server_setup_", tolower(opts$envir))

# slack -------------------------------------------------------------------
library(slackr)
slackr::slackr_setup(incoming_webhook_url = Sys.getenv('SLACK_BOT_WEBHOOK_URL'), bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN')) 
slackr_upload(filename = log_file, title = instance_id, channels = channel, bot_user_oauth_token = Sys.getenv('SLACK_BOT_USER_OAUTH_TOKEN'))