## Trying non-negative exploitation rates.
## Alternative zero negative: arbitrary multipliers
code <- "complex_labour_multiplier.emp.r.un"

meta_indicators[code,"name"] <- "Complex labour multiplier"
meta_indicators[code,"description"] <- 
  paste0("Multiplier of labour accordingly it's complexty and intensity.")
meta_indicators[code,"observation"] <- 
  paste0("Reduction Problem: Alternative 2: considers a feasible, but ",
         "arbitrary, scale of multipliers of high and medium skilled labour ",
         "regarding low skilled labour (6.25x for high skilled and 2.5x for ",
         "medium skilled labour).")
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

multiplier_h <- 1
multiplier_m <- 1

sea_sectors[,"complex_labour_multiplier.emp.r.un",,] <- 
  (multiplier_h * sea_sectors[,"hours_worked.empe_hs.r.pc",,]) +
  (multiplier_m * sea_sectors[,"hours_worked.empe_ms.r.pc",,]) +
  sea_sectors[,"hours_worked.empe_ls.r.pc",,]

