library(tidyverse)
library(vroom)

today   <- Sys.Date()

jhu.data <- vroom(paste0("~/cov-ind-19-data/", today, "/jhu_data.csv")) %>%
filter(Country == "India" & Date >= "2020-03-01")

state.data <- vroom(paste0("~/cov-ind-19-data/", today, "/covid19india_data.csv")) %>%
filter(Date >= "2020-03-01")

adj_len         <- 2
adj             <- T
plot_start_date <- "2020-03-01"
plot_end_date   <- "2020-04-30"

forecasts <- c("India", "dl", "mh", "kl")
pops <- c("India" = 1.34e9, "dl" = 16.8e6, "mh" = 112.4e6, "kl" = 33.4e6)
for (forecast in forecasts) {
    pop  <- pops[forecast]
    if (forecast == "India")
        data <- jhu.data
    else
        data <- state.data %>% filter(State == forecast)

    observed.data    <- data$Cases
    forecast.len     <- 200
    forecasted.dates <- seq(from = max(data$Date) + 1, by =  1,
                            length.out = forecast.len)
    for (arrayid in 1:2) {
        path    <- paste0("~/cov-ind-19-data/", today, "/", arrayid, "wk")

        fig_4_data <- function(x)
        {
            load(x)

            t           <- plot_data_ls[[2]][[1]]
            y_text_ht   <- plot_data_ls[[4]][[1]]
            data_comp   <- plot_data_ls[[4]][[3]]
            data_comp_R <- plot_data_ls[[5]][[3]]

            confirm <- round(pop * (data_comp[(t + 1):(t + forecast.len), "mean"] +
                data_comp_R[(t + 1):(t + forecast.len), "mean"]))
            confirm_up <- round(pop * (data_comp[(t + 1):(t + forecast.len), "upper"] +
                data_comp_R[(t + 1):(t + forecast.len), "upper"]))
            if (adj == TRUE) {
                adj_v <- mean(as.vector(observed.data[(t - adj_len):t]) /
                    pop / (data_comp[(t - adj_len):t, "mean"] +
                    data_comp_R[(t - adj_len):t, "mean"]), na.rm = T)

                confirm_up <- round(confirm_up * adj_v)
                confirm    <- round(confirm * adj_v)
            }
            return(list(confirm, confirm_up))
        }

        mod_2    <- fig_4_data(paste0(path, "/", forecast, "_2_plot_data.RData"))
        mod_2_up <- mod_2[[2]]
        mod_2    <- mod_2[[1]]

        mod_3    <- fig_4_data(paste0(path, "/", forecast, "_3_plot_data.RData"))
        mod_3_up <- mod_3[[2]]
        mod_3    <- mod_3[[1]]

        mod_4    <- fig_4_data(paste0(path, "/", forecast, "_4_plot_data.RData"))
        mod_4_up <- mod_4[[2]]
        mod_4    <- mod_4[[1]]

        observed_plot <- tibble(
            Dates    = data$Date,
            variable = "True",
            value    = observed.data
        )

        forecasts_plot <- tibble(
            Dates    = forecasted.dates,
            mod_2    = mod_2,
            mod_3    = mod_3,
            mod_4    = mod_4,
        ) %>%
        gather(variable, value, -Dates)

        forecasts_plot_ci <- tibble(
            Dates = forecasted.dates,
            mod_2 = mod_2_up,
            mod_3 = mod_3_up,
            mod_4 = mod_4_up,
        ) %>%
        gather(variable, upper_ci, -Dates)

        forecasts_plot <- left_join(forecasts_plot, forecasts_plot_ci,
                                    by = c("Dates", "variable"))

        complete_plot <- bind_rows(observed_plot, forecasts_plot) %>%
        mutate(variable = as.factor(variable)) %>%
        arrange(Dates) %>%
        mutate(
            color = as.factor(case_when(
            variable == "True" ~ "Observed",
            variable == "mod_2" ~ "Social distancing",
            variable == "mod_3" ~ "No intervention",
            variable == "mod_4" ~ "Lockdown with moderate release",
            variable == "Limit" ~ "Limit"
        )),
            type = as.factor(if_else(variable == "Limit", "dashed", "solid"))
        )

        vroom_write(complete_plot, path = paste0(path, "/", forecast, "_figure_4_data.csv"))

        fig_5_data <- function(x)
        {
            load(x)

            t           <- plot_data_ls[[2]][[1]]
            y_text_ht   <- plot_data_ls[[4]][[1]]
            data_comp   <- plot_data_ls[[4]][[3]]
            data_comp_R <- plot_data_ls[[5]][[3]]

            confirm    <- round(pop * (data_comp[(t + 1):(t + forecast.len), "mean"] +
                data_comp_R[(t + 1):(t + forecast.len),"mean"]))
            confirm_up <- round(pop*(data_comp[(t + 1):(t + forecast.len),"upper"] +
            data_comp_R[(t + 1):(t + forecast.len),"upper"]))
            if (adj == T) {
                adj_v <- mean(as.vector(observed.data[(t - adj_len):t]) / pop
                    / (data_comp[(t - adj_len):t, "mean"] +
                    data_comp_R[(t - adj_len):t, "mean"]), na.rm = T)

                confirm_up <- round(confirm_up * adj_v)
                confirm    <- round(confirm * adj_v)
            }
            return(list(confirm, confirm_up))
        }

        mod_2    <- fig_5_data(paste0(path, "/", forecast, "_2_plot_data.RData"))
        mod_2_up <- mod_2[[2]]
        mod_2    <- mod_2[[1]]

        mod_3    <- fig_5_data(paste0(path, "/", forecast, "_3_plot_data.RData"))
        mod_3_up <- mod_3[[2]]
        mod_3    <- mod_3[[1]]

        mod_4    <- fig_5_data(paste0(path, "/", forecast, "_4_plot_data.RData"))
        mod_4_up <- mod_4[[2]]
        mod_4    <- mod_4[[1]]

        mod_5    <- fig_5_data(paste0(path, "/", forecast, "_5_plot_data.RData"))
        mod_5_up <- mod_5[[2]]
        mod_5    <- mod_5[[1]]

        mod_6    <- fig_5_data(paste0(path, "/", forecast, "_6_plot_data.RData"))
        mod_6_up <- mod_6[[2]]
        mod_6    <- mod_6[[1]]

        observed_plot <- tibble(
          Dates    = data$Date,
          variable = "True",
          value    = observed.data
          )

        forecasts_plot <- tibble(
          Dates    = forecasted.dates,
          mod_2    = mod_2,
          mod_3    = mod_3,
          mod_4    = mod_4,
          mod_5    = mod_5,
          mod_6    = mod_6,
          ) %>%
          gather(variable, value, -Dates)

        forecasts_plot_ci <- tibble(
          Dates    = forecasted.dates,
          mod_2 = mod_2_up,
          mod_3 = mod_3_up,
          mod_4 = mod_4_up,
          mod_5 = mod_5_up,
          mod_6 = mod_6_up,
          ) %>%
          gather(variable, upper_ci, -Dates)

        forecasts_plot <- left_join(forecasts_plot, forecasts_plot_ci,
                                    by = c("Dates", "variable"))

        connect_plot <- tibble(
          Dates    = rep(as.Date("03-23-2020", format = "%m-%d-%y"), 5),
          variable = c("mod_2", "mod_3", "mod_4", "mod_5", "mod_6"),
          value    = rep(499, 5)
          )

        complete_plot <- bind_rows(observed_plot, forecasts_plot, connect_plot) %>%
        mutate(variable = as.factor(variable)) %>%
        arrange(Dates) %>%
        mutate(
            color = as.factor(case_when(
            variable == "True" ~ "Observed",
            variable == "mod_2" ~ "Soc. Dist. + Travel Ban",
            variable == "mod_3" ~ "No Intervention",
            variable == "mod_4" ~ "Moderate return",
            variable == "mod_5" ~ "Normal (pre-intervention)",
            variable == "mod_6" ~ "Cautious return",
            variable == "Limit" ~ "Limit"
        )),
            type = as.factor(if_else(variable == "Limit", "dashed", "solid"))
        )

        vroom_write(complete_plot, path = paste0(path, "/", forecast, "_figure_5_data.csv"))

        observed_plot <- tibble(
            Dates    = data$Date,
            variable = "True",
            value    = observed.data
        )

        mod_2               <- mod_2    - dplyr::lag(mod_2)
        mod_2_up            <- mod_2_up - dplyr::lag(mod_2_up)
        mod_3               <- mod_3    - dplyr::lag(mod_3)
        mod_3_up            <- mod_3_up - dplyr::lag(mod_3_up)
        mod_4               <- mod_4    - dplyr::lag(mod_4)
        mod_4_up            <- mod_4_up - dplyr::lag(mod_4_up)
        mod_5               <- mod_5    - dplyr::lag(mod_5)
        mod_5_up            <- mod_5_up - dplyr::lag(mod_5_up)
        mod_6               <- mod_6    - dplyr::lag(mod_6)
        mod_6_up            <- mod_6_up - dplyr::lag(mod_6_up)
        observed_plot$value <- observed_plot$value - lag(observed_plot$value)

        forecasts_plot <- tibble(
            Dates    = forecasted.dates,
            mod_2    = mod_2,
            mod_3    = mod_3,
            mod_4    = mod_4,
            mod_5    = mod_5,
            mod_6    = mod_6,
        ) %>%
        gather(variable, value, -Dates)

        forecasts_plot_ci <- tibble(
            Dates    = forecasted.dates,
            mod_2 = mod_2_up,
            mod_3 = mod_3_up,
            mod_4 = mod_4_up,
            mod_5 = mod_5_up,
            mod_6 = mod_6_up,
        ) %>%
        gather(variable, upper_ci, -Dates)

        forecasts_plot <- left_join(forecasts_plot, forecasts_plot_ci,
                                    by = c("Dates", "variable"))

        connect_plot <- tibble(
          Dates    = rep(as.Date("03-23-2020", format = "%m-%d-%y"), 10),
          variable = c("mod_2", "mod_2_up", "mod_3","mod_3_up", "mod_4",
                       "mod_4_up", "mod_5","mod_5_up", "mod_6", "mod_6_up"),
          value    = rep(499, 10)
          )

        complete_plot <- bind_rows(observed_plot, forecasts_plot, connect_plot) %>%
        mutate(variable = as.factor(variable)) %>%
        arrange(Dates) %>%
        mutate(
            color = as.factor(case_when(
                variable == "True" ~ "Observed",
                variable == "mod_2" ~ "Soc. Dist. + Travel Ban",
                variable == "mod_3" ~ "No Intervention",
                variable == "mod_4" ~ "Moderate return",
                variable == "mod_5" ~ "Normal (pre-intervention)",
                variable == "mod_6" ~ "Cautious return",
                variable == "Limit" ~ "Limit"
        )),
            type = as.factor(if_else(variable == "Limit", "dashed", "solid"))
        )

        vroom_write(complete_plot, path = paste0(path, "/", forecast,
                                                 "_figure_5_inc_data.csv"))
    }
}