# ================================================================
# JRCS revision script (df.csv version)
# Purpose:
#   - reproduce CFA / SEM using the full csv that includes demographics
#   - reproduce the supplementary SEM with controls
#   - document listwise attrition in the PNA sample
#   - estimate sensitivity networks with alternative missing-data handling
#
# Notes:
#   1) The current df.csv already contains AGE, GENDER, MARRIAGE, INCOME, CHILD,
#      the EXQ items, RSAT, and SoW. So there is no need to maintain a separate df4 file.
#   2) For bootnet::estimateNetwork with default = "EBICglasso", CRAN documentation
#      indicates that missing can be set to "pairwise", "listwise", "fiml", or "stop",
#      and qgraph::cor_auto also has a missing argument. This script uses those options
#      to run sensitivity checks.
#   3) The manuscript narrative should still be cautious: even if H3 reaches p = .050,
#      the effect is substantively negligible and should not be overstated.
# ================================================================

# -------------------------------
# 0) Reproducibility & packages
# -------------------------------
set.seed(20260314)

library(lavaan)
library(semTools)
library(dplyr)
library(bootnet)
library(qgraph)
library(igraph)
library(networktools)

dir.create("outputs", showWarnings = FALSE, recursive = TRUE)

# -------------------------------
# 1) Read data
# -------------------------------
df_all <- read.csv("df.csv", na.strings = c("NA", "", "."), stringsAsFactors = FALSE)

required_cols <- c(
  "AGE", "GENDER", "MARRIAGE", "INCOME", "CHILD",
  "BRE1", "BRE2", "BRE3", "BRE4", "BRE5", "BRE6", "BRE7",
  "SPE1", "SPE2", "SPE3", "SPE4", "SPE5", "SPE6", "SPE7", "SPE8", "SPE9", "SPE10", "SPE11",
  "PPE1", "PPE2", "PPE3", "PPE4", "PPE5", "PPE6", "PPE7",
  "RSAT", "SoW"
)

missing_required <- setdiff(required_cols, names(df_all))
if (length(missing_required) > 0) {
  stop("Missing required columns: ", paste(missing_required, collapse = ", "))
}

# Keep naming consistent with the original script:
df  <- df_all
df4 <- df_all

# Basic missing-count audit
missing_counts <- sapply(df_all, function(x) sum(is.na(x)))
write.csv(
  data.frame(variable = names(missing_counts), n_missing = as.integer(missing_counts)),
  "outputs/missing_counts_df.csv",
  row.names = FALSE
)

# -------------------------------
# 2) PNA attrition diagnostics
# -------------------------------
nodes <- c(
  "BRE2", "BRE6", "BRE7",
  "SPE1", "SPE2", "SPE4", "SPE6", "SPE7", "SPE9", "SPE11",
  "PPE2", "PPE3", "PPE5",
  "RSAT", "SoW"
)

df_all$PNA_complete <- complete.cases(df_all[, nodes])

welch_row <- function(varname) {
  x1 <- df_all[df_all$PNA_complete, varname]
  x0 <- df_all[!df_all$PNA_complete, varname]
  tt <- t.test(x1, x0, var.equal = FALSE)
  s1 <- sd(x1, na.rm = TRUE)
  s0 <- sd(x0, na.rm = TRUE)
  n1 <- sum(!is.na(x1))
  n0 <- sum(!is.na(x0))
  sp <- sqrt((((n1 - 1) * s1^2) + ((n0 - 1) * s0^2)) / (n1 + n0 - 2))
  d  <- (mean(x1, na.rm = TRUE) - mean(x0, na.rm = TRUE)) / sp

  data.frame(
    variable = varname,
    type = "continuous",
    complete_n = n1,
    complete_mean = mean(x1, na.rm = TRUE),
    complete_sd = s1,
    incomplete_n = n0,
    incomplete_mean = mean(x0, na.rm = TRUE),
    incomplete_sd = s0,
    test = "Welch t",
    statistic = unname(tt$statistic),
    p_value = tt$p.value,
    effect_size = d
  )
}

chisq_row <- function(varname) {
  tab <- table(df_all[[varname]], df_all$PNA_complete)
  cs  <- suppressWarnings(chisq.test(tab, correct = FALSE))
  n   <- sum(tab)
  phi2 <- unname(cs$statistic) / n
  v <- sqrt(phi2 / min(nrow(tab) - 1, ncol(tab) - 1))

  data.frame(
    variable = varname,
    type = "categorical",
    complete_n = sum(tab[, "TRUE"]),
    complete_mean = NA,
    complete_sd = NA,
    incomplete_n = sum(tab[, "FALSE"]),
    incomplete_mean = NA,
    incomplete_sd = NA,
    test = "Chi-square",
    statistic = unname(cs$statistic),
    p_value = cs$p.value,
    effect_size = v
  )
}

attrition_table <- bind_rows(
  welch_row("AGE"),
  welch_row("INCOME"),
  welch_row("RSAT"),
  welch_row("SoW"),
  chisq_row("GENDER"),
  chisq_row("MARRIAGE"),
  chisq_row("CHILD")
)

write.csv(attrition_table, "outputs/pna_attrition_comparison.csv", row.names = FALSE)

sink("outputs/pna_attrition_notes.txt")
cat("PNA complete cases:", sum(df_all$PNA_complete), "\n")
cat("PNA incomplete cases:", sum(!df_all$PNA_complete), "\n\n")
print(attrition_table)
sink()

# -------------------------------
# 3) CFA
# -------------------------------
cfa_model_13 <- "
  BRE =~ BRE2 + BRE6 + BRE7
  SPE =~ SPE1 + SPE2 + SPE4 + SPE6 + SPE7 + SPE9 + SPE11
  PPE =~ PPE2 + PPE3 + PPE5
"

fit_cfa_13 <- cfa(
  model = cfa_model_13,
  data = df,
  estimator = "MLR",
  missing = "fiml"
)

sink("outputs/cfa_13_summary.txt")
print(summary(fit_cfa_13, fit.measures = TRUE, standardized = TRUE))
sink()

sink("outputs/cfa_13_reliability.txt")
print(reliability(fit_cfa_13))
sink()

htmt_13 <- htmt(model = cfa_model_13, data = df)
write.csv(as.data.frame(htmt_13), "outputs/cfa_13_htmt.csv", row.names = TRUE)

cfa_model_19 <- "
  BRE =~ BRE1 + BRE2 + BRE3 + BRE5
  SPE =~ SPE1 + SPE2 + SPE3 + SPE4 + SPE6 + SPE7 + SPE8 + SPE10 + SPE11
  PPE =~ PPE1 + PPE2 + PPE3 + PPE4 + PPE6 + PPE7
"

fit_cfa_19 <- cfa(
  model = cfa_model_19,
  data = df,
  estimator = "MLR",
  missing = "fiml"
)

sink("outputs/cfa_19_summary.txt")
print(summary(fit_cfa_19, fit.measures = TRUE, standardized = TRUE))
sink()

sink("outputs/cfa_19_reliability.txt")
print(reliability(fit_cfa_19))
sink()

# -------------------------------
# 4) SEM (main and with controls)
# -------------------------------
sem_model <- "
  BRE =~ BRE2 + BRE6 + BRE7
  SPE =~ SPE1 + SPE2 + SPE4 + SPE6 + SPE7 + SPE9 + SPE11
  PPE =~ PPE2 + PPE3 + PPE5
  EXQ =~ BRE + SPE + PPE

  RSAT ~ a*EXQ
  SoW  ~ b*RSAT + c*EXQ

  indirect := a*b
  total    := c + (a*b)
"

fit_sem <- sem(
  sem_model,
  data = df,
  estimator = "MLR",
  missing = "fiml"
)

sink("outputs/sem_main_summary.txt")
print(summary(fit_sem, fit.measures = TRUE, standardized = TRUE, rsquare = TRUE))
sink()

write.csv(parameterEstimates(fit_sem, standardized = TRUE),
          "outputs/sem_main_parameter_estimates.csv",
          row.names = FALSE)

sem_model_controls <- "
  BRE =~ BRE2 + BRE6 + BRE7
  SPE =~ SPE1 + SPE2 + SPE4 + SPE6 + SPE7 + SPE9 + SPE11
  PPE =~ PPE2 + PPE3 + PPE5
  EXQ =~ BRE + SPE + PPE

  RSAT ~ a*EXQ + AGE + GENDER + MARRIAGE + INCOME + CHILD
  SoW  ~ b*RSAT + c*EXQ + AGE + GENDER + MARRIAGE + INCOME + CHILD

  indirect := a*b
  total    := c + (a*b)
"

fit_sem_controls <- sem(
  sem_model_controls,
  data = df4,
  estimator = "MLR",
  missing = "fiml"
)

sink("outputs/sem_controls_summary.txt")
print(summary(fit_sem_controls, fit.measures = TRUE, standardized = TRUE, rsquare = TRUE))
sink()

write.csv(parameterEstimates(fit_sem_controls, standardized = TRUE),
          "outputs/sem_controls_parameter_estimates.csv",
          row.names = FALSE)

fit_comp <- data.frame(
  model = c("main", "controls"),
  AIC = c(AIC(fit_sem), AIC(fit_sem_controls)),
  BIC = c(BIC(fit_sem), BIC(fit_sem_controls))
)
write.csv(fit_comp, "outputs/sem_model_comparison.csv", row.names = FALSE)

# -------------------------------
# 5) PNA: primary network (listwise) + sensitivity
# -------------------------------
net_data <- df_all %>% select(all_of(nodes))

estimate_one_network <- function(data, missing_mode) {
  estimateNetwork(
    data,
    default = "EBICglasso",
    corMethod = "cor_auto",
    missing = missing_mode,
    threshold = TRUE,
    lambda.min.ratio = 0.0001
  )
}

net_listwise <- estimate_one_network(net_data, "listwise")
net_pairwise <- estimate_one_network(net_data, "pairwise")

net_fiml <- tryCatch(
  estimate_one_network(net_data, "fiml"),
  error = function(e) {
    message("FIML network estimation failed: ", e$message)
    return(NULL)
  }
)

saveRDS(net_listwise, "outputs/net_listwise.rds")
saveRDS(net_pairwise, "outputs/net_pairwise.rds")
if (!is.null(net_fiml)) saveRDS(net_fiml, "outputs/net_fiml.rds")

# -------------------------------
# 6) Network summaries for SoW
# -------------------------------
node_strength <- function(W, node) {
  sum(abs(W[node, setdiff(colnames(W), node)]))
}

extract_sow_edges <- function(net_obj, label) {
  if (is.null(net_obj)) return(NULL)
  W <- net_obj$graph
  x <- W["SoW", setdiff(colnames(W), "SoW")]
  data.frame(
    network = label,
    node = names(x),
    edge = as.numeric(x),
    abs_edge = abs(as.numeric(x)),
    nonzero = abs(as.numeric(x)) > 0
  ) |>
    arrange(desc(abs_edge))
}

network_overview <- function(net_obj, label) {
  if (is.null(net_obj)) {
    return(data.frame(
      network = label,
      n_person = NA,
      sow_nonzero_edges = NA,
      sow_strength = NA,
      sow_max_abs_edge = NA
    ))
  }
  W <- net_obj$graph
  sow_edges <- W["SoW", setdiff(colnames(W), "SoW")]
  data.frame(
    network = label,
    n_person = net_obj$nPerson,
    sow_nonzero_edges = sum(abs(sow_edges) > 0),
    sow_strength = sum(abs(sow_edges)),
    sow_max_abs_edge = ifelse(any(abs(sow_edges) > 0), max(abs(sow_edges)), 0)
  )
}

sow_edges_all <- bind_rows(
  extract_sow_edges(net_listwise, "listwise"),
  extract_sow_edges(net_pairwise, "pairwise"),
  extract_sow_edges(net_fiml, "fiml")
)

write.csv(sow_edges_all, "outputs/sow_edge_sensitivity.csv", row.names = FALSE)

network_overview_all <- bind_rows(
  network_overview(net_listwise, "listwise"),
  network_overview(net_pairwise, "pairwise"),
  network_overview(net_fiml, "fiml")
)

write.csv(network_overview_all, "outputs/network_sensitivity_overview.csv", row.names = FALSE)

# -------------------------------
# 7) Plots
# -------------------------------
groups <- list(BRE = 1:3, SPE = 4:10, PPE = 11:13, Outcome = 14:15)

pdf("outputs/net_listwise_plot.pdf", width = 8, height = 6)
plot(
  net_listwise,
  layout = "spring",
  groups = groups,
  legend = FALSE,
  vsize = 5,
  theme = "colorblind",
  edge.labels = FALSE
)
dev.off()

pdf("outputs/net_pairwise_plot.pdf", width = 8, height = 6)
plot(
  net_pairwise,
  layout = "spring",
  groups = groups,
  legend = FALSE,
  vsize = 5,
  theme = "colorblind",
  edge.labels = FALSE
)
dev.off()

if (!is.null(net_fiml)) {
  pdf("outputs/net_fiml_plot.pdf", width = 8, height = 6)
  plot(
    net_fiml,
    layout = "spring",
    groups = groups,
    legend = FALSE,
    vsize = 5,
    theme = "colorblind",
    edge.labels = FALSE
  )
  dev.off()
}

# Centrality plot for the primary (listwise) network
pdf("outputs/centrality_strength_listwise.pdf", width = 8, height = 6)
centralityPlot(net_listwise, include = "Strength", orderBy = "Strength")
dev.off()

# -------------------------------
# 8) Stability & accuracy for the primary network
# -------------------------------
n_cores <- max(1L, parallel::detectCores(logical = TRUE) - 1L)

boot_case <- bootnet(
  net_listwise,
  nBoots = 2500,
  nCores = n_cores,
  type = "case",
  statistics = c("strength", "closeness", "betweenness")
)

cs <- corStability(boot_case)
write.csv(data.frame(statistic = names(cs), CS_coefficient = as.numeric(cs)),
          "outputs/centrality_cs_coefficients.csv",
          row.names = FALSE)

boot_edges <- bootnet(
  net_listwise,
  nBoots = 2500,
  nCores = n_cores,
  type = "nonparametric"
)

pdf("outputs/edge_accuracy_listwise.pdf", width = 10, height = 8)
plot(boot_edges, labels = TRUE, order = "sample")
dev.off()

boot_strength <- bootnet(
  net_listwise,
  nBoots = 2500,
  nCores = n_cores,
  type = "nonparametric",
  statistics = c("strength")
)

write.csv(summary(boot_strength), "outputs/boot_strength_summary.csv", row.names = FALSE)

# -------------------------------
# 9) Bridge centrality (primary network)
# -------------------------------
communities <- c(
  BRE2="BRE", BRE6="BRE", BRE7="BRE",
  SPE1="SPE", SPE2="SPE", SPE4="SPE", SPE6="SPE", SPE7="SPE", SPE9="SPE", SPE11="SPE",
  PPE2="PPE", PPE3="PPE", PPE5="PPE",
  RSAT="Outcome", SoW="Outcome"
)

bridge_res <- bridge(net_listwise$graph, communities = communities)

sink("outputs/bridge_summary.txt")
print(summary(bridge_res))
sink()

pdf("outputs/bridge_plot_listwise.pdf", width = 8, height = 6)
plot(bridge_res)
dev.off()

# -------------------------------
# 10) Optional note for the response letter
# -------------------------------
sink("outputs/revision_note_for_response_letter.txt")
cat("Key points for revision:\n")
cat("- H3 should not be described as substantively supported if the indirect effect remains trivial and total effect is nonsignificant.\n")
cat("- Report the control-variable SEM as a robustness check, not as the primary specification unless theory requires it.\n")
cat("- Add the attrition comparison table to the appendix or response letter.\n")
cat("- Use the pairwise/FIML network as a sensitivity analysis to address the reviewer concern about N discrepancy.\n")
print(network_overview_all)
sink()
