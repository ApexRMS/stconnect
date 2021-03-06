# Workspace setup
# Check for installed packages and install missing ones
list.of.packages <- c("raster", "rsyncrosim", "RSQLite", "tidyverse")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(raster)
library(rsyncrosim)
library(RSQLite)
library(tidyverse)

e = ssimEnvironment()
source(file.path(e$PackageDirectory, "common.R"))

# Output frequency of conservation prioritization analyses ---------------------------------------------------

# Get the output options datasheet
outputOptionsDatasheet <- datasheet(ssimObject = GLOBAL_Scenario, name = "stconnect_CPOutputOptions")

# If datasheet is not empty, get the output frequency
if(is.na(outputOptionsDatasheet$SpatialOutputCPTimesteps)){
  stop("No conservation prioritization output frequency specified.")
} else {
  outputFreq <- outputOptionsDatasheet$SpatialOutputCPTimesteps
}


# Zonation Info -------------------------------------------------------------

# Get the spades datasheet 
zonationDatasheet <- datasheet(ssimObject = GLOBAL_Scenario, name = "stconnect_CPZonationConfig")

# If datasheet is not empty, get the path
if(nrow(zonationDatasheet) == 0){
  stop("No Zonation executable specified.")
} else {
  if (is.na(zonationDatasheet$Filename)){
    stop("No Zonation executable specified.")
  } else {
    zonationExePath <- zonationDatasheet$Filename
  }
}

# Parameters
# These will eventually be moved to the UI
# Which carbon stock group should be used in prioritization
carbonPriorityStockGroupName <- "Total Ecosystem"

#datasheets
runSettingsIn = GetDataSheetExpectData("stconnect_CPRunSetting", GLOBAL_Scenario)
prioritizationOut = datasheet(GLOBAL_Scenario, "stconnect_CPOutputCumulative")

#file paths
tempFolderPath = envTempFolder("ConservationPrioritization")

rasTemplate<-datasheetRaster(GLOBAL_Scenario, datasheet = "stconnect_HSOutputHabitatSuitability", iteration = GLOBAL_MinIteration, timestep = GLOBAL_MinTimestep)[[1]]
rasRes<-res(rasTemplate)[1]
rasExtend<-c(xmin(rasTemplate)-rasRes,xmax(rasTemplate)+rasRes,ymin(rasTemplate)-rasRes,ymax(rasTemplate)+rasRes)

zonationSet<-readLines(file.path(e$PackageDirectory, "ALL_set_template.dat"))
removalRule<-data.frame(Code=c(1:5), Name=c("Basic core-area Zonation", "Additive benefit function", "Target based planning", "Generalized benefit function", "Random removal"))
zonationSet[2]<-paste("removal rule =", removalRule$Code[which(removalRule$Name==runSettingsIn$RemovalValue)])
zonationSet[3]<-paste("warp factor =", runSettingsIn$WarpFactor)
edgeRemoval<-if(runSettingsIn$EdgeRemoval=="TRUE") 1 else 0
zonationSet[4]<-paste("edge removal =", edgeRemoval)
zonationSet[5]<-paste("add edge points =", runSettingsIn$AddEdgePoints)
zonationSetName <- paste(tempFolderPath, "RunSetting.dat", sep="/")
writeLines(zonationSet, zonationSetName)

# Set of timesteps to analyse
timestepSet <- seq(GLOBAL_MinTimestep, GLOBAL_MaxTimestep, by=outputFreq)

#Simulation
envBeginSimulation(GLOBAL_TotalIterations * GLOBAL_TotalTimesteps)

for (iteration in GLOBAL_MinIteration:GLOBAL_MaxIteration) {
  
  for (timestep in timestepSet) {
    
    envReportProgress(iteration, timestep)
    
    carbonStockRasters <- stack(datasheetRaster(GLOBAL_Scenario, datasheet = "stsimsf_OutputSpatialStockGroup", iteration = iteration, timestep = timestep))
    # Keep only Total Ecosystem Carbon
    # Connect to SQLite database
    mydbname <- filepath(GLOBAL_Library)
    mydb <- dbConnect(drv = SQLite(), dbname= mydbname)
    # Get Stock Group Table
    stockGroupTable <- dbGetQuery(mydb, 'SELECT * FROM stsimsf_StockGroup')
    # Disconnect from database
    dbDisconnect(mydb)

    # Get stock group id
    stockGroupID <- stockGroupTable %>%
      filter(Name == carbonPriorityStockGroupName) %>%
      pull(StockGroupID)
    
    # Identify the focal raster from raster stack of stock groups
    result <- data.frame("CarbonPriority"=rep(NA, length(names(carbonStockRasters))))
    for(i in 1:length(names(carbonStockRasters))){
      result$CarbonPriority[i]<-grepl(paste0("stkg_", stockGroupID), names(carbonStockRasters)[i], fixed=TRUE)
    }
    carbonStockRasters <- dropLayer(carbonStockRasters, which(result==FALSE))
    rasIn<-stack(carbonStockRasters,
                 datasheetRaster(GLOBAL_Scenario, datasheet = "stconnect_HSOutputHabitatSuitability", iteration = iteration, timestep = timestep), 
                 datasheetRaster(GLOBAL_Scenario, datasheet = "stconnect_CCOutputCumulativeCurrent", iteration = iteration, timestep = timestep))

    rasOut<-extend(rasIn, rasExtend, -9999)
    rasOutFilename<-paste0(tempFolderPath,"\\",names(rasOut),".tif")
    writeRaster(rasOut, rasOutFilename, bylayer=TRUE, overwrite=TRUE)
  
    zonationSpp<-data.frame(1, 0, 1, 1, 1, rasOutFilename)
    zonationSppName <- paste(tempFolderPath, "BiodiversityFeatureList.spp", sep="/")
    write.table(zonationSpp, zonationSppName, row.names = FALSE, col.names=FALSE)
    zonationOutName <- file.path(tempFolderPath, CreateRasterFileName("OutputZonation", iteration, timestep, "txt"))
    zonationScenario<-paste0("-r ", "\"", zonationSetName, "\" ", "\"", zonationSppName, "\" ", "\"", zonationOutName, "\" ", "0.0 0 1.0 0")
    zonationScenarioName<-paste(tempFolderPath, "ZonationScenario.bat",sep="/")
    writeLines(zonationScenario, zonationScenarioName)
            
    #run Zonation
    system(paste0("\"",zonationExePath, "\" ", zonationScenario))

    df = data.frame(Iteration = iteration, Timestep = timestep, Filename = file.path(tempFolderPath, CreateRasterFileName("OutputZonation", iteration, timestep, "rank.compressed.tif")))
    prioritizationOut<-addRow(prioritizationOut, df)
    
    envStepSimulation()
  }
}
    
saveDatasheet(GLOBAL_Scenario, prioritizationOut, "stconnect_CPOutputCumulative")

