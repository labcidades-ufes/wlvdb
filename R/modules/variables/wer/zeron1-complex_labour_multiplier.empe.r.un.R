## Trying non-negative exploitation rates.
## Alternative zero negative: arbitrary multipliers
code <- "complex_labour_multiplier.empe.r.un"

meta_indicators[code,"name"] <- "Complex labour multiplier (employees only)"
meta_indicators[code,"description"] <- 
  paste0("Multiplier of labour of emplyees accordingly it's complexty and ",
         "intensity.")
meta_indicators[code,"observation"] <- 
  paste0("Reduction Problem: Alternative 2: considers a feasible, but ",
         "arbitrary, scale of multipliers of high and medium skilled labour ",
         "regarding low skilled labour (7x for high skilled and 3x for ",
         "medium skilled labour).")
meta_indicators[code,"type"] <- "index"
meta_indicators[code,"group"] <- "Others"
meta_indicators[code,"reverted"] <- FALSE

sea_sectors[,"complex_labour_multiplier.empe.r.un",,] <- 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]

# sets new rates for hours ratio (of abstract labour)
sea_sectors[,"hours_worked.empe_hs.r.pc",,] <- 
  (multiplier_h * sea_sectors[,"hours_worked.empe_hs.r.pc",,]) / 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]
sea_sectors[,"hours_worked.empe_ms.r.pc",,] <- 
  (multiplier_m * sea_sectors[,"hours_worked.empe_ms.r.pc",,]) / 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]
sea_sectors[,"hours_worked.empe_ls.r.pc",,] <- 
  sea_sectors[,"hours_worked.empe_ls.r.pc",,] / 
  sea_sectors[,"complex_labour_multiplier.emp.r.un",,]
