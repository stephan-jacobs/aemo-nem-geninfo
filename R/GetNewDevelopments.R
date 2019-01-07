GetNewDevelopments <- function(filename){
  temp_wb <- openxlsx::loadWorkbook(file = filename)
  sheet_names <- names(temp_wb)
  newGen <- openxlsx::read.xlsx(temp_wb, sheet = "New Developments", startRow = 2)
}