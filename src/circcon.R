# Workspace setup -------------------------------------------------------------------------------------
# Check for installed packages and install missing ones
packagesToLoad <- c("raster", "rsyncrosim", "dplyr")
# Identify packages that are not already installed
packagesToInstall <- packagesToLoad[!(packagesToLoad %in% installed.packages()[,"Package"])]
# Install missing packages
if(length(packagesToInstall)) install.packages(packagesToInstall)
# Load packages
lapply(packagesToLoad, library, character.only = TRUE)


# Connect to ST-Connect library -----------------------------------------------------------------------
# Path to package
packagePath <- ssimEnvironment()$PackageDirectory
# Active project
myProject <- project()
# Active scenario
myScenario <- scenario()
# Create SyncroSim temporary folder
tempFolderPath <- runtimeTempFolder("CircuitConnectivity")
# Create output folder
outputFolderPath <- runtimeOutputFolder(myScenario, "stconnect_CCOutputCumulativeCurrent")
# Temporary Hack: save a small file to the output folder so that it doesn't get deleted when SyncroSim cleans the library and automatically deletes empty folders 
write.table("file to save folder", file.path(outputFolderPath,"saveFolder.txt"))

# Source common R functions for error messaging
source(file.path(packagePath, "common.R"))

# Read in datasheets
# Library datasheets
juliaDatasheet <- datasheetExpectData(myScenario, "stconnect_CCJuliaConfig")

# Project datasheets
speciesSet <- datasheetExpectData(myProject, "stconnect_Species")

# Scenario datasheets
# Input datasheets
runSettings <- datasheetExpectData(myScenario, "stsim_RunControl")
outputOptions <- datasheetExpectData(myScenario, "stconnect_CCOutputOptions")
stateClass <- datasheet(myScenario,"stsim_StateClass")
resistanceIn <- datasheetExpectData(myScenario, "stconnect_CCResistance")
# Eventually add this to output options
rescaleCurrMap <- TRUE
   
# Output datasheets
resistanceOut <- datasheet(myScenario, "stconnect_CCOutputResistance")
circuitOut <- datasheet(myScenario, "stconnect_CCOutputCumulativeCurrent")
effectivePermeabilityOut <- datasheet(myScenario, "stconnect_CCOutputMetric")

# Manipulate datasheets and prep for simulation --------------------------------------------
# Add state class id values to resistance LULC datasheet to be used when reclassing state class rasters
resistanceIn <- resistanceIn %>%
  left_join(stateClass, by = c("StateClassID" = "Name"))

# Set of timesteps to analyse
timestepSet <- seq(runSettings$MinimumTimestep, runSettings$MaximumTimestep, by=outputOptions$SpatialOutputCCTimesteps)

# Total iterations
totalIterations <- runSettings$MaximumIteration - runSettings$MinimumIteration + 1
# Total timesteps
totalTimesteps <- runSettings$MaximumTimestep - runSettings$MinimumTimestep + 1


# Run simulation ---------------------------------------------------------------------------
# Report on simulation progress
progressBar(type="begin", totalSteps=as.integer(totalIterations*totalTimesteps))

# Loop over all iterations, timesteps, and species
for (iteration in runSettings$MinimumIteration:runSettings$MaximumIteration) {
  
  for (timestep in timestepSet) {
    
    # Report on simulation progress
    progressBar(type="report", iteration=iteration, timestep=timestep)

    #Read in state class and age rasters for this iteration and timestep
    stateclassMap <- datasheetRaster(myScenario, datasheet = "stsim_OutputSpatialState", iteration = iteration, timestep = timestep)

    for (speciesRow in 1:nrow(speciesSet)) {
      
      # Species name
      species <- speciesSet[speciesRow, "Name"]
      # Species code
      speciesCode <- speciesSet[speciesRow, "Code"]
      
      # Species resistance values LULC
      resistanceValues <- resistanceIn %>%
        filter(SpeciesID == species) %>%
        select("ID", "Value")

      # Check if values exist for this species, if not move to next species 
      if (nrow(resistanceValues) == 0) {
          next
      }

      # Species resistance raster
      # Reclassify state class raster
      resistanceRaster <- reclassify(stateclassMap, rcl = resistanceValues)

      # Create focal regions
      # Create focal region raster for N-S by adding top and bottom rows
      extentNS<-extent(xmin(resistanceRaster),xmax(resistanceRaster),ymin(resistanceRaster)-res(resistanceRaster)[1],ymax(resistanceRaster)+res(resistanceRaster)[1])
      focalRegionNS<-raster(extentNS,nrow=nrow(resistanceRaster)+2,ncol=ncol(resistanceRaster))
      focalRegionNS[1,]<-1
      focalRegionNS[nrow(focalRegionNS),]<-2
      
      # Create focal region raster for E-W by adding left and right columns
      extentEW<-extent(xmin(resistanceRaster)-res(resistanceRaster)[2],xmax(resistanceRaster)+res(resistanceRaster)[2],ymin(resistanceRaster),ymax(resistanceRaster))
      focalRegionEW<-raster(extentEW,nrow=nrow(resistanceRaster),ncol=ncol(resistanceRaster)+2)
      focalRegionEW[,1]<-1
      focalRegionEW[,ncol(focalRegionEW)]<-2
      
      # Extend resistance rasters to match NS and EW extents
      resistanceRasterNS<-extend(resistanceRaster, extentNS,value=1)
      resistanceRasterNS[is.na(resistanceRasterNS)]<-100
      resistanceRasterEW<-extend(resistanceRaster, extentEW,value=1)
      resistanceRasterEW[is.na(resistanceRasterEW)]<-100
      
      # Save focal region and extended resistance rasters to temporary folder as Circuitscape inputs
      # Focal region rasters
      focalRegionNSName = file.path(tempFolderPath, "NSfocalRegion.asc")
      focalRegionEWName = file.path(tempFolderPath, "EWfocalRegion.asc")
      writeRaster(focalRegionNS, focalRegionNSName, overwrite = TRUE)
      writeRaster(focalRegionEW, focalRegionEWName, overwrite = TRUE)
      
      # Extended resistance rasters
      resistanceRasterNSName = file.path(tempFolderPath, rasterFileNameSpecies("NSResistance", species, iteration, timestep, "asc"))
      resistanceRasterEWName = file.path(tempFolderPath, rasterFileNameSpecies("EWResistance", species, iteration, timestep, "asc"))
      writeRaster(resistanceRasterNS, resistanceRasterNSName, overwrite=TRUE)
      writeRaster(resistanceRasterEW, resistanceRasterEWName, overwrite=TRUE)
      
      # Make .ini files and save to output folder
      # Note that these files specify the path for Circuitscape outputs to be written to temp folder
      NS_ini<-c("[circuitscape options]", 
                "data_type = raster",
                "scenario = pairwise",
                "write_cum_cur_map_only = true",
                "write_cur_maps = true",
                paste0("point_file = ", file.path(tempFolderPath, "NSfocalRegion.asc")),
                paste0("habitat_file = ", resistanceRasterNSName),
                paste0("output_file = ", file.path(tempFolderPath,"NS.out")))
      writeLines(NS_ini,file.path(outputFolderPath,"NS.ini"))
      
      EW_ini<-c("[circuitscape options]", 
                "data_type = raster",
                "scenario = pairwise",
                "write_cum_cur_map_only = true",
                "write_cur_maps = true",
                paste0("point_file = ", file.path(tempFolderPath, "EWfocalRegion.asc")),
                paste0("habitat_file = ", resistanceRasterEWName),
                paste0("output_file = ", file.path(tempFolderPath,"EW.out")))
      writeLines(EW_ini,file.path(outputFolderPath,"EW.ini"))
      
      # Make Julia scripts and save to output folder
      NS_run_jl <- file(file.path(outputFolderPath, "NSscript.jl"))
      writeLines(c("using Circuitscape", paste0("compute(", "\"", file.path(outputFolderPath, "NS.ini"),"\")")), NS_run_jl)
      close(NS_run_jl)

      EW_run_jl <- file(file.path(outputFolderPath, "EWscript.jl"))
      writeLines(c("using Circuitscape", paste0("compute(", "\"", file.path(outputFolderPath, "EW.ini"),"\")")), EW_run_jl)
      close(EW_run_jl)
      
      # Make the N-S and E-W Circuitscape run commands and save to output folder
      NS_run <- paste(juliaDatasheet$Filename, paste0("\"",file.path(outputFolderPath,"NSscript.jl"),"\""))
      EW_run <- paste(juliaDatasheet$Filename, paste0("\"",file.path(outputFolderPath,"EWscript.jl"),"\""))
      
      # Run the commands
      system(NS_run)
      # Check to make sure the results were saved
      # If not then print the Julia script
      if(file.exists(file.path(tempFolderPath,"NS_cum_curmap.asc")) == FALSE){
        stop(
          paste("Circuitscape failed to save results. Here is the failed Julia script:", 
                "using Circuitscape", 
                paste0("compute(", "\"", file.path(outputFolderPath, "NS.ini"),"\")"), 
                sep="\n")
          )
      }
      system(EW_run)
      if(file.exists(file.path(tempFolderPath,"EW_cum_curmap.asc")) == FALSE){
        stop(
          paste("Circuitscape failed to save results. Here is the failed Julia script:", 
                "using Circuitscape", 
                paste0("compute(", "\"", file.path(outputFolderPath, "EW.ini"),"\")"), 
                sep="/n")
        )
      }
      
      # Read in NS and EW cum current maps, crop, and combine
      currMapNS <- crop(raster(file.path(tempFolderPath,"NS_cum_curmap.asc")), resistanceRaster)
      currMapEW <- crop(raster(file.path(tempFolderPath,"EW_cum_curmap.asc")), resistanceRaster)
      currMapOMNI <- currMapEW+currMapNS
      currMapOMNI[is.na(resistanceRaster)] <- NA
      
      # Read in NS and EW effective resistance, take inverse, take mean
      effectivePermeabilityNS <- 1/read.table(file.path(tempFolderPath, "NS_Resistances_3columns.out"))$V3
      effectivePermeabilityEW <- 1/read.table(file.path(tempFolderPath, "EW_Resistances_3columns.out"))$V3
      effectivePermeability <- mean(c(effectivePermeabilityNS, effectivePermeabilityEW))

      # Add row to effectivePermabilityOut datasheet
      newRow <- data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, EffectivePermeability = effectivePermeability)
      effectivePermeabilityOut <- addRow(effectivePermeabilityOut, newRow)
      
      # Save rasters to output folder
      # Tag raster names with iteration, timestep, and species code
      # Resistance
      resistanceName <- file.path(tempFolderPath, rasterFileNameSpecies("Resistance", speciesCode, iteration, timestep, "tif"))
      writeRaster(resistanceRaster, resistanceName, overwrite = TRUE)
      # Add row to resistanceOut datasheet
      newRow <- data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, Filename = resistanceName)
      resistanceOut <- addRow(resistanceOut, newRow)
      
      # Current
      # If output options datasheet column SpatialOutputCCLog is TRUE, log cummulative current map
      if(outputOptions$SpatialOutputCCLog==TRUE){
        currMapOMNI<-log(currMapOMNI)
      } 
      
      # Eventually add this to output options
      if(rescaleCurrMap==TRUE){
        currMapOMNI <- (currMapOMNI-cellStats(currMapOMNI,"min"))/(cellStats(currMapOMNI,"max")-cellStats(currMapOMNI,"min"))
      }
      currMapOMNIName <- file.path(tempFolderPath, rasterFileNameSpecies("OMNI_cum_curmap", speciesCode, iteration, timestep, "tif"))
      writeRaster(currMapOMNI, currMapOMNIName, overwrite=TRUE)
      # Add row to circuitOut datasheet
      newRow <- data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, Filename = currMapOMNIName)
      circuitOut <- addRow(circuitOut, newRow)
      
    } # speciesRow
    # Report on simulation progress
    progressBar(type="step")

  } # timestep
  
} # iteration

# Save output data sheets to library -------------------------------------------------------
saveDatasheet(myScenario, resistanceOut, "stconnect_CCOutputResistance")
saveDatasheet(myScenario, circuitOut, "stconnect_CCOutputCumulativeCurrent")
saveDatasheet(myScenario, effectivePermeabilityOut, "stconnect_CCOutputMetric")

# End simulation ---------------------------------------------------------------------------
progressBar(type="end")
