# Workspace setup -------------------------------------------------------------------------------------
# Check for installed packages and install missing ones
packagesToLoad <- c("raster", "rsyncrosim", "RSQLite", "tidyverse")
# Identify packages that are not already installed
packagesToInstall <- packagesToLoad[!(packagesToLoad %in% installed.packages()[,"Package"])]
# Install missing packages
if(length(packagesToInstall)) install.packages(packagesToInstall)
# Load packages
lapply(packagesToLoad, library, character.only = TRUE)

# Parameters
# These will eventually be moved to the UI
# Which carbon stock group should be used in prioritization
# carbonPriorityStockGroupName <- "Total Ecosystem"

# Connect to ST-Connect library -----------------------------------------------------------------------
# Path to package
packagePath <- ssimEnvironment()$PackageDirectory
# Active project
myProject <- project()
# Active scenario
myScenario <- scenario()
# Create SyncroSim temporary folder
tempFolderPath = envTempFolder("ConservationPrioritization")

# Source common R functions for error messaging
source(file.path(packagePath, "common.R"))

# Read in datasheets
# Library datasheets
zonationDatasheet <- datasheetExpectData(myScenario, "stconnect_CPZonationConfig")

# Scenario datasheets
# Input datasheets
runSettings <- datasheetExpectData(myScenario, "stsim_RunControl")
zonationRunSettings <- datasheetExpectData(myScenario, "stconnect_CPRunSetting")
outputOptions <- datasheetExpectData(myScenario, "stconnect_CPOutputOptions")

# Output datasheets
prioritizationOut <- datasheet(myScenario, "stconnect_CPOutputCumulative")


# Manipulate datasheets and prep for simulation --------------------------------------------
# Set of timesteps to analyse
timestepSet <- seq(runSettings$MinimumTimestep, runSettings$MaximumTimestep, by=outputOptions$SpatialOutputCPTimesteps)
# Total iterations
totalIterations <- runSettings$MaximumIteration - runSettings$MinimumIteration + 1
# Total timesteps
totalTimesteps <- runSettings$MaximumTimestep - runSettings$MinimumTimestep + 1

# Create Zonation run settings file
# Read in template
zonationSet <- readLines(file.path(packagePath, "ALL_set_template.dat"))
# Data frame of removal rules
removalRule <- data.frame(Code=c(1:5), Name=c("Basic core-area Zonation", "Additive benefit function", "Target based planning", "Generalized benefit function", "Random removal"))
# Overwrite template with user-input values
zonationSet[2] <- paste("removal rule =", removalRule$Code[which(removalRule$Name==zonationRunSettings$RemovalValue)])
zonationSet[3] <- paste("warp factor =", zonationRunSettings$WarpFactor)
edgeRemoval <- if(zonationRunSettings$EdgeRemoval=="TRUE") 1 else 0
zonationSet[4] <- paste("edge removal =", edgeRemoval)
zonationSet[5] <- paste("add edge points =", zonationRunSettings$AddEdgePoints)
zonationSetName <- paste(tempFolderPath, "RunSetting.dat", sep="/")
writeLines(zonationSet, zonationSetName)


# Run simulation ---------------------------------------------------------------------------
# Report on simulation progress
envBeginSimulation(totalIterations * totalTimesteps)

# Loop over all iterations and timesteps
for (iteration in runSettings$MinimumIteration:runSettings$MaximumIteration) {
  
  for (timestep in timestepSet) {

    # Report on simulation progress
    envReportProgress(iteration, timestep)
    
    # Read in carbon stock rasters
    # carbonStockRasters <- stack(datasheetRaster(GLOBAL_Scenario, datasheet = "stsimsf_OutputSpatialStockGroup", iteration = iteration, timestep = timestep))
    # # Keep only Total Ecosystem Carbon
    # # Connect to SQLite database
    # mydbname <- filepath(GLOBAL_Library)
    # mydb <- dbConnect(drv = SQLite(), dbname= mydbname)
    # # Get Stock Group Table
    # stockGroupTable <- dbGetQuery(mydb, 'SELECT * FROM stsimsf_StockGroup')
    # # Disconnect from database
    # dbDisconnect(mydb)
    # 
    # # Get stock group id
    # stockGroupID <- stockGroupTable %>%
    #   filter(Name == carbonPriorityStockGroupName) %>%
    #   pull(StockGroupID)
    # 
    # # Identify the focal raster from raster stack of stock groups
    # result <- data.frame("CarbonPriority"=rep(NA, length(names(carbonStockRasters))))
    # for(i in 1:length(names(carbonStockRasters))){
    #   result$CarbonPriority[i]<-grepl(paste0("stkg_", stockGroupID), names(carbonStockRasters)[i], fixed=TRUE)
    # }
    # carbonStockRasters <- dropLayer(carbonStockRasters, which(result==FALSE))

    # rasIn<-stack(carbonStockRasters,
    #   datasheetRaster(myScenario, "stconnect_HSOutputHabitatSuitability", iteration = iteration, timestep = timestep), 
    #   datasheetRaster(myScenario, "stconnect_CCOutputCumulativeCurrent", iteration = iteration, timestep = timestep))
    
    # Read in rasters and stack
    # Check to see if habitat and/or connectivity layers were provided
    includeHabitat <- ifelse(nrow(datasheet(myScenario, "stconnect_HSOutputHabitatSuitability")) > 0, TRUE, FALSE)
    includeCircuit <- ifelse(nrow(datasheet(myScenario, "stconnect_CCOutputCumulativeCurrent")) > 0, TRUE, FALSE)

    if(includeHabitat & includeCircuit){
      
      rasIn<-stack(datasheetRaster(myScenario, "stconnect_HSOutputHabitatSuitability", iteration = iteration, timestep = timestep), 
                   datasheetRaster(myScenario, "stconnect_CCOutputCumulativeCurrent", iteration = iteration, timestep = timestep))
      
    } else if (includeHabitat){
      
      rasIn<-stack(datasheetRaster(myScenario, "stconnect_HSOutputHabitatSuitability", iteration = iteration, timestep = timestep))
      
    } else if (includeCircuit){
      
      rasIn<-stack(datasheetRaster(myScenario, "stconnect_CCOutputCumulativeCurrent", iteration = iteration, timestep = timestep))
      
    } else {
      
      stop("No data for stconnect_HSOutputHabitatSuitability and stconnect_CCOutputCumulativeCurrent")
      
    }
    
    
    # Use one of the rasters as a template for the extent
    rasTemplate <- rasIn[[1]]

    # Zonation requires a 1-pixel wide border of NA values
    # Calculate the Zonation extent from the template raster extent
    zonationExtent <- extent(c(xmin(rasTemplate) - res(rasTemplate)[1], 
                               xmax(rasTemplate) + res(rasTemplate)[1],
                               ymin(rasTemplate) - res(rasTemplate)[1], 
                               ymax(rasTemplate) + res(rasTemplate)[1]))
    
    # Extend all rasters with NA value (-9999) using zonationExtent
    if(nlayers(rasIn)==1){
      rasOut <- extend(x=rasIn[[1]], y=zonationExtent, value=-9999)
    } else {
      rasOut <- extend(x=rasIn, y=zonationExtent, value=-9999)
    }
    # Save extended rasters to be inputs for Zonation
    rasOutFilename <- paste0(tempFolderPath,"\\",names(rasOut),".tif")
    writeRaster(rasOut, rasOutFilename, bylayer=TRUE, overwrite=TRUE)
  
    # Make Zonation input file of biodiversity features
    zonationSpp <- data.frame(1, 0, 1, 1, 1, rasOutFilename)
    zonationSppName <- paste(tempFolderPath, "BiodiversityFeatureList.spp", sep="/")
    write.table(zonationSpp, zonationSppName, row.names = FALSE, col.names=FALSE)
    # Make Zonation run file
    zonationOutName <- file.path(tempFolderPath, rasterFileName("OutputZonation", iteration, timestep, "txt"))
    zonationRun <- paste0("-r ", "\"", zonationSetName, "\" ", "\"", zonationSppName, "\" ", "\"", zonationOutName, "\" ", "0.0 0 1.0 0")
    zonationRunName <- paste(tempFolderPath, "ZonationRun.bat", sep="/")
    writeLines(zonationRun, zonationRunName)
            
    # Run Zonation
    system(paste0("\"", zonationDatasheet$Filename, "\" ", zonationRun))

    # Add row to prioritizationOut datasheet
    newRow <- data.frame(Iteration = iteration, Timestep = timestep, Filename = file.path(tempFolderPath, rasterFileName("OutputZonation", iteration, timestep, "rank.compressed.tif")))
    prioritizationOut <- addRow(prioritizationOut, newRow)
    
    envStepSimulation()

    } # timestep

} # iteration

# Save output data sheets to library -------------------------------------------------------
saveDatasheet(myScenario, prioritizationOut, "stconnect_CPOutputCumulative")

# End simulation ---------------------------------------------------------------------------
envEndSimulation()
