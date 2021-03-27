# Workspace setup
# Check for installed packages and install missing ones
list.of.packages <- c("raster", "rsyncrosim", "tidyverse")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(raster)
library(rsyncrosim)
library(tidyverse)

e = ssimEnvironment()
source(file.path(e$PackageDirectory, "common.R"))

# Parameters
# These will eventually be moved to the UI
# Temporal resolution of analysis in years, e.g. analye every 10 years
temporalRes <- 1
#directory where Circuitscape is installed
CS_exe<-"\"C:/Program Files/Circuitscape/cs_run.exe\"" # Don't forget the "Program Files" problem

#file paths
tempFolderPath = envTempFolder("CircuitConnectivity")

#datasheets
stateClassIn = datasheet(GLOBAL_Scenario,"stsim_StateClass")
resistanceIn = GetDataSheetExpectData("stconnect_CCResistance", GLOBAL_Scenario)
resistanceIn <- merge(resistanceIn, stateClassIn, by.x="StateClassID", by.y="Name")
resistanceOut = datasheet(GLOBAL_Scenario, "stconnect_CCOutputResistance")
circuitOut = datasheet(GLOBAL_Scenario, "stconnect_CCOutputCumulativeCurrent", empty=T)

#file paths
tempFolderPath = envTempFolder("CircuitConnectivity")

#Create ouput folder
outputFolderPath <- envOutputFolder(GLOBAL_Scenario, "stconnect_CCOutputCumulativeCurrent")
#Temporary Hack: save a small file to the output folder so that it doesn't get deleted when SyncroSim cleans the library and automatically deletes empty folders 
write.table("file to save folder", file.path(outputFolderPath,"saveFolder.txt"))

# Set of timesteps to analyse
timestepSet <- seq(GLOBAL_MinTimestep, GLOBAL_MaxTimestep, by=temporalRes)

#Simulation
envBeginSimulation(GLOBAL_TotalIterations * GLOBAL_TotalTimesteps)

for (iteration in GLOBAL_MinIteration:GLOBAL_MaxIteration) {
  
  for (timestep in timestepSet) {
    
    envReportProgress(iteration, timestep)
    
    for (sprow in 1:nrow(GLOBAL_Species)) {
      
      species = GLOBAL_Species[sprow, "Name"]
      speciesCode = GLOBAL_Species[sprow, "Code"]
      resistanceValues <- resistanceIn[which(resistanceIn$SpeciesID == species), c("ID", "Value")]
      
      if (nrow(resistanceValues) == 0) {
        next
      }
      
      #Input stateclass raster
      stateMap <- datasheetRaster(GLOBAL_Scenario, datasheet = "stsim_OutputSpatialState", iteration = iteration, timestep = timestep)
      
      #Resistance map
      resistanceRaster <- reclassify(stateMap, rcl = resistanceValues)

      #Save rasters
      resistanceName = file.path(tempFolderPath, CreateRasterFileName2("Resistance", speciesCode, iteration, timestep, "tif"))
      writeRaster(resistanceRaster, resistanceName, overwrite = TRUE)
      df = data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, Filename = resistanceName)
      resistanceOut = addRow(resistanceOut, df)

      #create focal region raster for N-S by adding top and bottom rows
      extentNS<-extent(xmin(resistanceRaster),xmax(resistanceRaster),ymin(resistanceRaster)-res(resistanceRaster)[1],ymax(resistanceRaster)+res(resistanceRaster)[1])
      focalRegionNS<-raster(extentNS,nrow=nrow(resistanceRaster)+2,ncol=ncol(resistanceRaster))
      focalRegionNS[1,]<-1
      focalRegionNS[nrow(focalRegionNS),]<-2
      
      #create focal region raster for E-W by adding left and right columns
      extentEW<-extent(xmin(resistanceRaster)-res(resistanceRaster)[2],xmax(resistanceRaster)+res(resistanceRaster)[2],ymin(resistanceRaster),ymax(resistanceRaster))
      focalRegionEW<-raster(extentEW,nrow=nrow(resistanceRaster),ncol=ncol(resistanceRaster)+2)
      focalRegionEW[,1]<-1
      focalRegionEW[,ncol(focalRegionEW)]<-2
      
      #Save rasters
      focalRegionNSName = file.path(tempFolderPath, "NSfocalRegion.asc")
      focalRegionEWName = file.path(tempFolderPath, "EWfocalRegion.asc")
      writeRaster(focalRegionNS, focalRegionNSName, overwrite = TRUE)
      writeRaster(focalRegionEW, focalRegionEWName, overwrite = TRUE)
      
      #extend resistanceRaster NS
      resistanceRasterNS<-extend(resistanceRaster,extentNS,value=1)
      resistanceRasterNS[is.na(resistanceRasterNS)]<-100
      
      #extend resistanceRaster EW
      resistanceRasterEW<-extend(resistanceRaster,extentEW,value=1)
      resistanceRasterEW[is.na(resistanceRasterEW)]<-100
      
      #Save rasters to temp folder
      resistanceRasterNSName = file.path(tempFolderPath, CreateRasterFileName2("NSResistance", species, iteration, timestep, "asc"))
      resistanceRasterEWName = file.path(tempFolderPath, CreateRasterFileName2("EWResistance", species, iteration, timestep, "asc"))
      writeRaster(resistanceRasterNS, resistanceRasterNSName, overwrite=TRUE)
      writeRaster(resistanceRasterEW, resistanceRasterEWName, overwrite=TRUE)
      
      #make a N-S .ini file to output folder
      NS_ini<-c("[circuitscape options]", 
                "data_type = raster",
                "scenario = pairwise",
                "write_cur_maps = TRUE",
                paste0("point_file = ", file.path(tempFolderPath, "NSfocalRegion.asc")),
                paste0("habitat_file = ", resistanceRasterNSName),
                paste0("output_file = ", file.path(outputFolderPath,"NS.out")))
      writeLines(NS_ini,file.path(outputFolderPath,"NS.ini"))
      
      #make a E-W .ini file and save
      EW_ini<-c("[circuitscape options]", 
                "data_type = raster",
                "scenario = pairwise",
                "write_cur_maps = TRUE",
                paste0("point_file = ", file.path(tempFolderPath, "EWfocalRegion.asc")),
                paste0("habitat_file = ", resistanceRasterEWName),
                paste0("output_file = ", file.path(outputFolderPath,"EW.out")))
      writeLines(EW_ini,file.path(outputFolderPath,"EW.ini"))
      
      #make the N-S and E-W CS run cmds
      NS_run <- paste(CS_exe, paste0("\"",file.path(outputFolderPath,"NS.ini"),"\""))
      EW_run <- paste(CS_exe, paste0("\"",file.path(outputFolderPath,"EW.ini"),"\""))
      
      #run the commands
      system(NS_run)
      system(EW_run)
      
      currMapNS<-crop(raster(file.path(outputFolderPath,"NS_cum_curmap.asc")),resistanceRaster)
      currMapEW<-crop(raster(file.path(outputFolderPath,"EW_cum_curmap.asc")),resistanceRaster)
      currMapOMNI<-currMapEW+currMapNS
      currMapOMNI[is.na(resistanceRaster)]<-NA
      
      #      currMapOMNI01<-(currMapOMNI-cellStats(currMapOMNI,"min"))/(cellStats(currMapOMNI,"max")-cellStats(currMapOMNI,"min"))
      
      
      currMapOMNI_log<-log(currMapOMNI)
      currMapOMNI_log01<-(currMapOMNI_log-cellStats(currMapOMNI_log,"min"))/(cellStats(currMapOMNI_log,"max")-cellStats(currMapOMNI_log,"min"))
      
      #Save Omni-directional current density raster
      currMapOMNIName <- file.path(tempFolderPath, CreateRasterFileName2("OMNI_cum_curmap", speciesCode, iteration, timestep, "tif"))
      writeRaster(currMapOMNI_log01, currMapOMNIName, overwrite=TRUE)
      
      #Write output file
      data <- data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, Filename = currMapOMNIName)
      circuitOut <- addRow(circuitOut, data)
    }
    
    envStepSimulation()
  }
}

saveDatasheet(GLOBAL_Scenario, resistanceOut, "stconnect_CCOutputResistance")
saveDatasheet(GLOBAL_Scenario, circuitOut, "stconnect_CCOutputCumulativeCurrent")

envEndSimulation()
