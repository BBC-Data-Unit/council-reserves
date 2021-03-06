#' ---
#' title: "Council accounts: resilience test"
#' output: html_notebook
#' ---
#' 
#' # Testing resilience by analysing council accounts
#' 
#' This notebook details the process of analysing council accounts in order to arrive at a measure of 'resilience'.
#' 
#' The data comes from the Ministry of Housing, Communities & Local Government's [Local authority revenue expenditure and financing collection](https://www.gov.uk/government/collections/local-authority-revenue-expenditure-and-financing#2018-to-2019). 
#' 
#' We can find the latest by going to [Local authority revenue expenditure and financing collection](https://www.gov.uk/government/collections/local-authority-revenue-expenditure-and-financing#2018-to-2019) and looking for the latest "Local authority revenue expenditure and financing England: ... individual local authority data - outturn" then within that "Revenue outturn summary (RS) ...".
#' 
#' Begin by changing the line below so that the URL specifies the latest **Revenue account (RA) budget** URL:
#' 
## ------------------------------------------------------------------------
#Update this when new data is available
rourl <- "https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/740771/RS_2017-18_data_by_LA.xlsx"

#' 
#' 
#' ## Methodology
#' 
#' The methodology is adapted from that detailed in the [CIPFA consultation on an index of resilience](https://www.cipfa.org/policy-and-guidance/consultations/consultation-on-cipfa-index-of-resilience-for-english-councils). This identifies the following measures:
#' 
#' * The level of total reserves excluding schools and public health as a proportion of net revenue expenditure (from RO outturns) - weighted 0.25
#' * The percentage change in reserves, excluding schools and public health, over the past three years (from RO outturns) - weighted 0.25
#' * The ratio of government grants to net revenue expenditure (from RO outturns)  - weighted 0.1
#' * Proportion of net revenue expenditure accounted for by children’s social care, adult social care and debt interest payments (from RO outturns) - weighted 0.15
#' * Ofsted overall rating for children’s social care ([Ofsted report, released in July annually](https://www.gov.uk/government/statistics/childrens-social-care-data-in-england-2018)) - weighted 0.15
#' * Auditor’s VFM judgement (Public Sector Audit Appointment’s summary of the results of audit: an adverse or “except for” judgement may be indicative of poor financial management within a council) - weighted 0.1
#' 
#' These notebooks focus on the first four measures from RO outturns.
#' 
#' ## The level of total reserves excluding schools and public health as a proportion of net revenue expenditure
#' 
#' Let's grab this from the latest data - using `raurl` defined at the start of this notebook:
#' 
#' 
## ------------------------------------------------------------------------
#Activate the library for calling URLs
library(httr)
#Fetch that file and save it locally with a new name
GET(rourl, write_disk("revenueoutturn.xlsx", overwrite = T))

#' 
#' Now to import that, and clean it along the way. There are two problems here: first, the column headers don't start until row 4; and second, those headers are spread across 3 rows.
#' 
#' The most detailed headings are in row 7, with related codes for each heading in row 6, and broader categories in row 5. So we skip to row 7 for the main dataset, and store the other headings in another data frame just in case.
#' 
## ------------------------------------------------------------------------
#Import the library we need to read Excel
library(readxl)
#Read that file into a new data frame
#We want the 3rd sheet, and to skip the first 6 lines so row 7 is used for headers
rodata <- read_excel("revenueoutturn.xlsx", sheet = 3, skip = 6, na = "c('-','')")
#Rows 5 and 6 also contain useful info so we grab those just in case
#We specify the range because otherwise it skips the blank cells in the first 5 columns
#An alternative would be to change or remove the n_max so there are some full cells in those first 5 cols
ro.otherheads <- read_excel("revenueoutturn.xlsx", sheet = 3, skip = 4, n_max = 1, range = "A5:IR6")
#Most of these are empty so we need to copy from the previous cell.
#Start from index 2 because the i-1 below will generate an error otherwise
for(i in seq(2,length(ro.otherheads))){
  #grab first two characters
  first2 <- substr(colnames(ro.otherheads)[i],0,2)
  #If this is an unnamed column
  if (first2 == "X_"){
    #Replace with the name of the previous column
    colnames(ro.otherheads)[i] <- colnames(ro.otherheads)[i-1]
  }
}

#' 
#' 
#' ### Find the data points we need
#' 
#' There are 100 variables in this spreadsheet, so let's narrow down to the ones we want to focus on.
#' 
#' * "The level of total reserves" 
#' * "excluding schools and public health" 
#' * "as a proportion of"
#' * "net revenue expenditure"
#' 
#' We can use regex to find the columns where 'reserves' are mentioned:
#' 
## ------------------------------------------------------------------------
colnames(rodata)[grepl(".*[Rr]eserves.*",colnames(rodata))]

#' 
#' And narrow down further by simply adding a space - this excludes the ones that *end* with "reserves" and no space after:
#' 
## ------------------------------------------------------------------------
colnames(rodata)[grepl(".*[Rr]eserves .*",colnames(rodata))]

#' 
#' Now that we think we have the right columns, let's generate that subset:
#' 
## ------------------------------------------------------------------------
#We remove 'colnames' now so we are accessing the data frame as a whole
rodata.res <- rodata[grepl(".*[Rr]eserves .*",colnames(rodata))]
#Create a subset of just the basic names and codes in the first few columns - we'll probably need this again so useful to save as a separate data frame
rodata.councils <- rodata[c(1:3,5)]
#Combine the two using cbind
rodata.res <- cbind(rodata.councils,rodata.res)

#' 
#' We've now gone from 100 variables to 14, which is going to be much easier to deal with.
#' 
#' ### Subsetting by type of organisation
#' 
#' We also need to remove all the organisations we don't want. The type of organisation is shown in the 'Class' column:
#' 
## ------------------------------------------------------------------------
table(rodata.res$Class)

#' 
#' We don't want shire districts (SD), or other authorities such as police or fire (O). 
#' 
## ------------------------------------------------------------------------
rodata.res <- subset(rodata.res, rodata.res$Class != "O" & rodata.res$Class != "SD")
table(rodata.res$Class)

#' 
#' This gives us a data frame with 156 rows - 4 more than we might expect. This is because aggregate figures for each type (4 types) are also in the data. 
#' 
#' These make up the last 4 rows and have no code:
#' 
## ------------------------------------------------------------------------
#Subset so we only have rows where the code is not NA
rodata.res <- subset(rodata.res,rodata.res$`E-code` != "NA")
#Check a table to see each number has gone down by 1
table(rodata.res$Class)

#' 
#' 
#' 
#' ## Cleaning data types
#' 
#' To check if we need more cleaning we can generate a summary:
#' 
## ------------------------------------------------------------------------
summary(rodata.res)

#' 
#' This indicates that many of the columns have been imported as characters, rather than numeric, most likely because of the presence of dashes.
#' 
#' We need to fix this. Let's use the `tidyverse` library and use its `guess_parser` function to see what it thinks of one of the columns:
#' 
## ------------------------------------------------------------------------
library(tidyverse)
#Guess the first number columns
guess_parser(rodata.res[,5])

#' 
#' Now a `table` to see what values are in that column:
#' 
## ------------------------------------------------------------------------
summary(rodata.res[,5])
table(rodata.res[,5])

#' 
#' We'll need to parse it instead as a number during any analysis.
#' 
## ------------------------------------------------------------------------
#Parse as number
parse_number(rodata.res[,5])
#Replace column with numeric version
rodata.res[,5] <- parse_number(rodata.res[,5])
#Sum - this returns NA
sum(rodata.res[,5])
#Table to show frequency of numbers
table(rodata.res[,5])

#' 
#' Here's a quicker way to do this for all the columns from 5 onwards
#' 
## ------------------------------------------------------------------------
#Create a for loop to go through each number from 5 to the length of rodata.res
for(i in seq(5,length(rodata.res)))
  {
  #Replace the column at that position with the same column parsed as numbers
  rodata.res[,i] <- parse_number(rodata.res[,i])
  }
#Check the resulting dataframe
summary(rodata.res)

#' 
#' All of these have 2 NA entries, so let's look at those.
#' 
## ------------------------------------------------------------------------
is.na(rodata.res$`Estimated schools reserves level at 1 April`)

#' 
## ------------------------------------------------------------------------
#Export a pure R script version of this notebook
knitr::purl("4resiliencetest.Rmd", "4resiliencetest.R", documentation = 2)

