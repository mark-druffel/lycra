doc <-'lycra install_packages

Usage:
  install_packages.R  --packages <path> [--envir <name>] [--user_home <directory>] [--Ncpus <int>] 

Options:
 --envir <name>             Name of the environment which will be used as the github branch for all Propeller packages; defaults to main branch
 --packages <path>          File with R packages to be installed in the specified format; no default
 --user_home <directory>    Directory of the shared user home, required by git for credentials library install; no default
 --Ncpus <int>              Number of cpus to us in the installation process, recommend maximum number machine can allocate; no default'
opts <- docopt::docopt(doc)


# helper functions --------------------------------------------------------
read_rpkgs <- function(rpkgs, envir){
  # Remove commented lines
  rpkgs <- readLines(rpkgs, warn = F)[!grepl('#', readLines(rpkgs, warn = F))]
  # Remove blank lines
  rpkgs <- rpkgs[sapply(rpkgs, nchar) > 0] 
  return(rpkgs)
}
get_pkgs <- function(rpkgs, envir){
  # Drop repos listed after comma
  get_pkg <- function(pkg){ ifelse( grepl(pkg, pattern = ','), trimws(strsplit(pkg, split = ',')[[1]][1]), trimws(pkg) ) } 
  pkgs <- vapply(X = rpkgs, FUN = get_pkg, FUN.VALUE = character(1), USE.NAMES = F)
  
  # Add branch based on environ input
  add_branch <- function(pkg, envir){ 
    branch <- ifelse( trimws(tolower(envir)) == 'stage' && grepl(pkg, pattern = 'propellerpdx'), '@stage', '' )
    pkg <- paste0(pkg, branch)
    return(pkg)
  }
  pkgs <- vapply(X = pkgs, FUN = add_branch, envir = envir, FUN.VALUE = character(1), USE.NAMES = F)
  return(pkgs)
} 
get_repos <- function(rpkgs){
  get_repo <- function(pkg){ 
    if(grepl(pkg, pattern = '!http./')) {
      # Packages with the repo/package syntax are assigned github, http packages are ignored for packages with mirrors not in CRAN
      repo <- 'github'
    } else if(grepl(pkg, pattern = ',')){
      # Values after comma on package are assumed to be repos to replace CRAN mirror
      repo <- trimws(strsplit(pkg, split = ',')[[1]][2])
    } else {
      # otherwise CRAN mirror is used
      repo = 'CRAN'
    }
    return(repo)
  }
  repos <- vapply(X = rpkgs, FUN = get_repo, FUN.VALUE = character(1), USE.NAMES = F)
  return(repos)
}

# parse packages ----------------------------------------------------------
rpkgs <- read_rpkgs(opts$packages)
pkgs <- get_pkgs(rpkgs, opts$envir)
repos <- get_repos(rpkgs)
if('github' %in% repos ){
  install.packages(pkgs = 'remotes', 
                   repos = c('http://cran.rstudio.com','https://ftp.osuosl.org/pub/cran/','https://cran.wu.ac.at/'),
                   dependencies = c("Depends", "Imports", "LinkingTo"), 
                   Ncpus = opts$Ncpus)
}
if('rstan' %in% pkgs | 'credentials' %in% pkgs ){
  install.packages(pkgs = 'withr', 
                   repos = c('http://cran.rstudio.com','https://ftp.osuosl.org/pub/cran/','https://cran.wu.ac.at/'),
                   dependencies = c("Depends", "Imports", "LinkingTo"), 
                   Ncpus = opts$Ncpus)
}
for(i in 1:length(pkgs) ){ 
  if(pkg[i] == 'rstan'){
    # configure C++ toolchain; https://github.com/stan-dev/rstan/wiki/Configuring-C-Toolchain-for-Linux
    dotR <- file.path(Sys.getenv("HOME"), ".R")
    if (!file.exists(dotR)) dir.create(dotR)
    M <- file.path(dotR, "Makevars")
    if (!file.exists(M)) file.create(M)
    cat("\nCXX14FLAGS=-O3 -march=native -mtune=native -fPIC", "CXX14=g++", file = M, sep = "\n", append = TRUE)
    # create temporary environment variable for required installation of V8 (only required if node.js is not installed)
    withr::with_envvar(
      new = c('DOWNLOAD_STATIC_LIBV8' = '1'),
      install.packages(pkgs[i], repos = c('http://cran.rstudio.com','https://ftp.osuosl.org/pub/cran/','https://cran.wu.ac.at/'), dependencies = T, Ncpus = opts$Ncpus))
  } else if(pkg[i] == 'credentials'){
    # create temporary environment variable for git to find shared user home, sharing org git credentials for installations; https://github.com/r-lib/credentials/issues/11
    withr::with_envvar(
      new = c('HOME' = opts$user_home),
      install.packages(pkgs[i], repos = c('http://cran.rstudio.com','https://ftp.osuosl.org/pub/cran/','https://cran.wu.ac.at/'), dependencies = T, Ncpus = opts$Ncpus))
  } else if(tolower(tolower(repos[i])) == 'cran'){
    install.packages(pkgs[i], repos = c('http://cran.rstudio.com','https://ftp.osuosl.org/pub/cran/','https://cran.wu.ac.at/'), dependencies = T, Ncpus = opts$Ncpus)
  } else if(tolower(repos[i]) != 'github') { 
    install.packages(pkgs[i], repos = repos[i], dependencies = T, Ncpus = opts$Ncpus)
  } else { 
    remotes::install_github(repo = pkgs[i], dependencies = T, upgrade = 'always', force = T, Ncpus = opts$Ncpus)
  }
}