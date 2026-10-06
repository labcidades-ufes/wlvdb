#preparar eurostat


ertlinkeurostat <- 
  "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/ert_bil_eur_a/?format=SDMX-CSV&lang=en&label=label_only"

dir.create("source_data/eurostat",showWarnings = F)

download.file(ertlinkeurostat,
              "source_data/eurostat/estat_ert_bil_eur_a_en.csv")