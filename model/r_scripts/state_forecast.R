# libraries ----------
library(tidyverse)
library(chron)
library(rjags)
library(gtools) #rdirichlet(n, alpha)
library(here)
library(eSIR)
library(devtools)

# Set variables based on testing or production
if ( Sys.getenv("production") == "TRUE" ) {
        data_repo <- "~/cov-ind-19-data/"
        Ms        <- 5e5    # 5e5 recommended (5e3 for testing - but not stable)
        nburnins  <- 2e5    # 2e5 recommended (2e3 for testing - but not stable)
} else {
        data_repo <- "~/cov-ind-19-test/"
        Ms        <- 5e3    # 5e5 recommended (5e3 for testing - but not stable)
        nburnins  <- 2e3    # 2e5 recommended (2e3 for testing - but not stable)
}

today    <- Sys.getenv("today")
state    <- Sys.getenv("state")
arrayid  <- Sys.getenv("SLURM_ARRAY_TASK_ID")
set.seed(20192020) # default: 20192020

# specificatioons ----------
delay              <- 7             # in days (default = 7)
pi_cautious        <- 0.6           # pi corresponding to cautious return
pi_lockdown        <- 0.4           # pi corresponding to lockdown
pi_moderate        <- 0.75          # pi corresponding to moderate return
pi_normal          <- 1             # pi corresponding to normal (pre-intervention) return
pi_sdtb            <- 0.75          # pi corresponding to social distancing and travel ban
R_0                <- 2             # basic reproduction number
save_files         <- TRUE
save_mcmc          <- FALSE         # output MCMC files (default = TRUE; needed for incidence CI calculations)
speed_lockdown     <- 7             # length of time for lockdown to drop (in days)
speed_return       <- 21            # length of time for pi to return to post-lockdown pi (in days)
start_date         <- "2020-03-01"
soc_dist_start     <- "2020-03-15"
soc_dist_end       <- "2020-03-24"
lockdown_start     <- as.Date(soc_dist_end) + 1
lockdown_end       <- "2020-05-03"
length_of_lockdown <- length(as.Date(lockdown_start):as.Date(lockdown_end))

# STATES
state_sub <- state

# data ----------
dat <- read_tsv(paste0(data_repo, today, "/covid19india_data.csv")) %>%
  filter(State == state_sub)

# populations from http://www.census2011.co.in/states.php
pops <-  c("up" = 199.8e6, "mh" = 112.4e6, "br" = 104.1e6, "wb" = 91.3e6, "ap" = 49.67e6,
           "mp" = 72.1e6, "tn" = 72.1e6, "rj" = 68.5e6, "ka" = 61.1e6, "gj" = 60.4e6,
           "or" = 42.0e6, "kl" = 33.4e6, "jh" = 33.0e6, "as" = 31.2e6, "pb" = 27.7e6,
           "ct" = 25.5e6, "hr" = 25.4e6, "dl" = 16.8e6, "jk" = 12.5e6, "ut" = 10.1e6,
           "hp" = 6.9e6, "tr" = 3.7e6, "ml" = 3.0e6, "mn" = 2.9e6, "nl" = 2.0e6, 
           "ga" = 1.6e6, "ar" = 1.4e6, "py" = 1.2e6, "mz" = 1.1e6, "ch" = 1.1e6,
           "sk" = 6.1e5, "an" = 3.8e5, "dn" = 3.4e5, "dd" = 2.4e5, "ld" = 6.4e4,
           "tg" = 35e6, "la" = NA)

start_date <-  min(dat$Date)

# function ----------
elefante <- function(dates, pis, anchor = Sys.Date()) {
  
  if (max(as.Date(dates, "%m/%d/%Y")) > anchor) {
    drpr      <- length(dates[dates <= format(anchor, "%m/%d/%Y")]) + 1
    tmp_dates <- c(format(anchor, "%m/%d/%Y"), dates[drpr:length(dates)])
    tmp_pis   <- c(1, pis[drpr:length(pis)])
  }
  
  if (max(as.Date(dates, "%m/%d/%Y")) <= anchor) {
    tmp_dates <- format(anchor, "%m/%d/%Y")
    tmp_pis   <- c(1, tail(pis, 1))
  }
  
  return(
    list(
      dates = tmp_dates,
      pis   = tmp_pis,
      check = ifelse(length(tmp_dates) + 1 == length(tmp_pis), "All good!", "Uh-oh...")
    )
  )
  
}

# directory ----------
wd <- paste0(data_repo, today, "/1wk/")
if (!dir.exists(wd)) {
  dir.create(wd, recursive = TRUE)
  message("Creating ", wd)
}
setwd(wd)

NI_complete <- dat$Cases
RI_complete <- dat$Recovered + dat$Deaths
N           <- pops[state_sub]                         # population of India
R           <- unlist(RI_complete/N)           # proportion of recovered per day
Y           <- unlist(NI_complete/N-R)

l <- length(as.Date((as.Date(soc_dist_start) + delay):(as.Date(soc_dist_end) + delay), origin = "1970-01-01"))


# models ---------

if (arrayid == 1) {
  change_time <- format(c(as.Date((as.Date(soc_dist_start) + delay):(as.Date(soc_dist_end) + delay), origin = "1970-01-01"),
                          as.Date(as.Date(soc_dist_start) + delay + l, origin = "1970-01-01")), "%m/%d/%Y")
  pi0         <- c(1,
                   rev(seq(pi_sdtb, 1, (1 - pi_sdtb) / l))[-1],
                   pi_sdtb)
  mod         <- elefante(dates = change_time, pis = pi0)
  
  model_2 <- tvt.eSIR(
    Y,
    R,
    begin_str      = format(start_date, "%m/%d/%Y"),
    death_in_R     = 0.2,
    T_fin          = 200,
    pi0            = mod$pis,
    change_time    = mod$dates,
    R0             = R_0,
    dic            = TRUE,
    casename       = paste0(state_sub, "_2"),
    save_files     = save_files,
    save_mcmc      = save_mcmc,
    save_plot_data = TRUE,
    M              = Ms,
    nburnin        = nburnins
  )
}

if (arrayid == 2) {
  model_3 <- tvt.eSIR(
    Y,
    R,
    begin_str      = format(start_date, "%m/%d/%Y"),
    death_in_R     = 0.2,
    T_fin          = 200,
    R0             = R_0,
    dic            = TRUE,
    casename       = paste0(state_sub, "_3"),
    save_files     = save_files,
    save_mcmc      = save_mcmc,
    save_plot_data = TRUE,
    M              = Ms,
    nburnin        = nburnins
  )
}

if (arrayid == 3) {
  print(paste0("Running model_4 (lockdown with moderate return) with ", speed_lockdown/7, " week delay and ", length_of_lockdown,"-day lockdown"))
  change_time <- format(c(as.Date((as.Date(soc_dist_start) + delay):(as.Date(soc_dist_end) + delay), origin = "1970-01-01"),
                          as.Date((as.Date(lockdown_start) + delay):(as.Date(lockdown_start) + delay + speed_lockdown), origin = "1970-01-01"),
                          as.Date((as.Date(lockdown_start) + delay + length_of_lockdown):(as.Date(lockdown_start) + delay + length_of_lockdown + speed_return), origin = "1970-01-01")), "%m/%d/%Y")
  pi0         <- c(1,
                   rev(seq(pi_sdtb, 1, (1-pi_sdtb) / l))[-1],
                   rev(seq(pi_lockdown, pi_sdtb, (pi_sdtb-pi_lockdown) / speed_lockdown))[-1],
                   seq(pi_lockdown, pi_moderate, (pi_moderate - pi_lockdown) / speed_return),
                   pi_moderate)
  mod         <- elefante(dates = change_time, pis = pi0)
  
  model_4 <- tvt.eSIR(
    Y,
    R,
    begin_str      = format(start_date, "%m/%d/%Y"),
    death_in_R     = 0.2,
    T_fin          = 200,
    pi0            = mod$pis,
    change_time    = mod$dates,
    R0             = R_0,
    dic            = TRUE,
    casename       = paste0(state_sub, "_4"),
    save_files     = save_files,
    save_mcmc      = save_mcmc,
    save_plot_data = TRUE,
    M              = Ms,
    nburnin        = nburnins
  )
}

if (arrayid == 4) {
  print(paste0("Running model_5 (lockdown with normal [pre-intervention] return) with ", speed_lockdown/7," week delay and ", length_of_lockdown, "-day lockdown"))
  change_time <- format(c(as.Date((as.Date(soc_dist_start) + delay):(as.Date(soc_dist_end) + delay), origin = "1970-01-01"),
                          as.Date((as.Date(lockdown_start) + delay):(as.Date(lockdown_start) + delay + speed_lockdown), origin = "1970-01-01"),
                          as.Date((as.Date(lockdown_start) + delay + length_of_lockdown):(as.Date(lockdown_start) + delay + length_of_lockdown + speed_return), origin = "1970-01-01")), "%m/%d/%Y")
  pi0         <- c(1,
                   rev(seq(pi_sdtb, 1, (1-pi_sdtb) / l))[-1],
                   rev(seq(pi_lockdown, pi_sdtb, (pi_sdtb-pi_lockdown) / speed_lockdown))[-1],
                   seq(pi_lockdown, pi_normal, (pi_normal - pi_lockdown) / speed_return),
                   pi_normal)
  mod         <- elefante(dates = change_time, pis = pi0)
  
  model_5 <- tvt.eSIR(
    Y,
    R,
    begin_str      = format(start_date, "%m/%d/%Y"),
    death_in_R     = 0.2,
    T_fin          = 200,
    pi0            = mod$pis,
    change_time    = mod$dates,
    R0             = R_0,
    dic            = TRUE,
    casename       = paste0(state_sub, "_5"),
    save_files     = save_files,
    save_mcmc      = save_mcmc,
    save_plot_data = TRUE,
    M              = Ms,
    nburnin        = nburnins
  )
}

if (arrayid == 5) {
  print(paste0("Running model_6 (lockdown with cautious return) with ", speed_lockdown/7, " week delay and ", length_of_lockdown, "-day lockdown"))
  change_time <- format(c(as.Date((as.Date(soc_dist_start) + delay):(as.Date(soc_dist_end) + delay), origin = "1970-01-01"),
                          as.Date((as.Date(lockdown_start) + delay):(as.Date(lockdown_start) + delay + speed_lockdown), origin = "1970-01-01"),
                          as.Date((as.Date(lockdown_start) + delay + length_of_lockdown):(as.Date(lockdown_start) + delay + length_of_lockdown + speed_return), origin = "1970-01-01")), "%m/%d/%Y")
  pi0         <- c(1,
                   rev(seq(pi_sdtb, 1, (1-pi_sdtb) / l))[-1],
                   rev(seq(pi_lockdown, pi_sdtb, (pi_sdtb-pi_lockdown) / speed_lockdown))[-1],
                   seq(pi_lockdown, pi_cautious, (pi_cautious - pi_lockdown) / speed_return),
                   pi_cautious)
  mod         <- elefante(dates = change_time, pis = pi0)
  
  model_6 <- tvt.eSIR(
    Y,
    R,
    begin_str      = format(start_date, "%m/%d/%Y"),
    death_in_R     = 0.2,
    T_fin          = 200,
    pi0            = mod$pis,
    change_time    = mod$dates,
    R0             = R_0,
    dic            = TRUE,
    casename       = paste0(state_sub, "_6"),
    save_files     = save_files,
    save_mcmc      = save_mcmc,
    save_plot_data = TRUE,
    M              = Ms,
    nburnin        = nburnins
  )
}
