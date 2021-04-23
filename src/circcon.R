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

# Output frequency of circuit connectivity analyses ---------------------------------------------------

# Get the output options datasheet
outputOptionsDatasheet <- datasheet(ssimObject = GLOBAL_Scenario, name = "stconnect_CCOutputOptions")

# If datasheet is not empty, get the output frequency
if(is.na(outputOptionsDatasheet$SpatialOutputCCTimesteps)){
  stop("No circuit connectivity output frequency specified.")
} else {
  outputFreq <- outputOptionsDatasheet$SpatialOutputCCTimesteps
}


# Julia Info -------------------------------------------------------------

# Get the spades datasheet 
juliaDatasheet <- datasheet(ssimObject = GLOBAL_Scenario, name = "stconnect_CCJuliaConfig")

# If datasheet is not empty, get the path
if(nrow(juliaDatasheet) == 0){
  stop("No Julia executable specified.")
} else {
  if (is.na(juliaDatasheet$Filename)){
    stop("No Julia executable specified.")
  } else {
    juliaExePath <- juliaDatasheet$Filename
  }
}


#file paths
tempFolderPath = envTempFolder("CircuitConnectivity")
#temporary folder to save outputs that is very short
#this is a short-term fix because the Julia version of Circuitscape does not handle long file paths
tempFolderPath1 = "C:"

#datasheets
stateClassIn = datasheet(GLOBAL_Scenario,"stsim_StateClass")
resistanceLULCIn = GetDataSheetExpectData("stconnect_CCLULCResistance", GLOBAL_Scenario)
resistanceLULCIn <- merge(resistanceLULCIn, stateClassIn, by.x="StateClassID", by.y="Name")
resistanceAgeIn = GetDataSheetExpectData("stconnect_CCAgeResistance", GLOBAL_Scenario)
resistanceOut = datasheet(GLOBAL_Scenario, "stconnect_CCOutputResistance")
circuitOut = datasheet(GLOBAL_Scenario, "stconnect_CCOutputCumulativeCurrent", empty=T)

#file paths
tempFolderPath = envTempFolder("CircuitConnectivity")

#Create ouput folder
outputFolderPath <- envOutputFolder(GLOBAL_Scenario, "stconnect_CCOutputCumulativeCurrent")
#Temporary Hack: save a small file to the output folder so that it doesn't get deleted when SyncroSim cleans the library and automatically deletes empty folders 
write.table("file to save folder", file.path(outputFolderPath,"saveFolder.txt"))

# Set of timesteps to analyse
timestepSet <- seq(GLOBAL_MinTimestep, GLOBAL_MaxTimestep, by=outputFreq)

#Simulation
envBeginSimulation(GLOBAL_TotalIterations * GLOBAL_TotalTimesteps)

for (iteration in GLOBAL_MinIteration:GLOBAL_MaxIteration) {
  
  for (timestep in timestepSet) {
    
    envReportProgress(iteration, timestep)
    
    for (sprow in 1:nrow(GLOBAL_Species)) {
      
      species = GLOBAL_Species[sprow, "Name"]
      speciesCode = GLOBAL_Species[sprow, "Code"]
      resistanceLULCValues <- resistanceLULCIn[which(resistanceLULCIn$SpeciesID == species), c("ID", "Value")]
      resistanceAgeValues <- resistanceAgeIn[which(resistanceAgeIn$SpeciesID == species), c("AgeMin", "AgeMax", "Value")]
      
      if (nrow(resistanceLULCValues) == 0) {
        next
      }
      if (nrow(resistanceAgeValues) == 0) {
        next
      }
      
      #Input stateclass raster
      stateMap <- datasheetRaster(GLOBAL_Scenario, datasheet = "stsim_OutputSpatialState", iteration = iteration, timestep = timestep)
      ageMap <- datasheetRaster(GLOBAL_Scenario, datasheet = "stsim_OutputSpatialAge", iteration = iteration, timestep = timestep)
      
      #Resistance map
      resistanceLULCRaster <- reclassify(stateMap, rcl = resistanceLULCValues)
      resistanceAgeRaster <- reclassify(ageMap, rcl = resistanceAgeValues, right=TRUE, include.lowest=TRUE)
      resistanceRaster <- resistanceLULCRaster * resistanceAgeRaster
      
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
                "write_cum_cur_map_only = true",
                "write_cur_maps = true",
                paste0("point_file = ", file.path(tempFolderPath, "NSfocalRegion.asc")),
                paste0("habitat_file = ", resistanceRasterNSName),
                paste0("output_file = ", file.path(tempFolderPath1,"NS.out")))
      writeLines(NS_ini,file.path(outputFolderPath,"NS.ini"))
      
      #make a E-W .ini file and save
      EW_ini<-c("[circuitscape options]", 
                "data_type = raster",
                "scenario = pairwise",
                "write_cum_cur_map_only = true",
                "write_cur_maps = true",
                paste0("point_file = ", file.path(tempFolderPath, "EWfocalRegion.asc")),
                paste0("habitat_file = ", resistanceRasterEWName),
                paste0("output_file = ", file.path(tempFolderPath1,"EW.out")))
      writeLines(EW_ini,file.path(outputFolderPath,"EW.ini"))
      
      #make Julia scripts
      NS_run_jl <- file(file.path(outputFolderPath, "NSscript.jl"))
      writeLines(c("using Circuitscape", paste0("compute(", "\"", file.path(outputFolderPath, "NS.ini"),"\")")), NS_run_jl)
      close(NS_run_jl)
      
      EW_run_jl <- file(file.path(outputFolderPath, "EWscript.jl"))
      writeLines(c("using Circuitscape", paste0("compute(", "\"", file.path(outputFolderPath, "EW.ini"),"\")")), EW_run_jl)
      close(EW_run_jl)
      
      #make the N-S and E-W CS run cmds
      #NS_run <- paste(CS_exe, paste0("\"",file.path(outputFolderPath,"NS.ini"),"\""))
      #EW_run <- paste(CS_exe, paste0("\"",file.path(outputFolderPath,"EW.ini"),"\""))
      NS_run <- paste(juliaExePath, paste0("\"",file.path(outputFolderPath,"NSscript.jl"),"\""))
      EW_run <- paste(juliaExePath, paste0("\"",file.path(outputFolderPath,"EWscript.jl"),"\""))
      
      #run the commands
      system(NS_run)
      system(EW_run)
      
      # Read in NS and EW cum current maps and combine
      currMapNS<-crop(raster(file.path(tempFolderPath1,"NS_cum_curmap.asc")),resistanceRaster)
      currMapEW<-crop(raster(file.path(tempFolderPath1,"EW_cum_curmap.asc")),resistanceRaster)
      currMapOMNI<-currMapEW+currMapNS
      currMapOMNI[is.na(resistanceRaster)]<-NA
      
      
      # If output options datasheet column SpatialOutputCCRaw is TURE, save raw outputs
      if(outputOptionsDatasheet$SpatialOutputCCRaw==TRUE){
        currMapOMNI01<-(currMapOMNI-cellStats(currMapOMNI,"min"))/(cellStats(currMapOMNI,"max")-cellStats(currMapOMNI,"min"))
        #Save raw omni-directional current density raster
        currMapOMNIName <- file.path(tempFolderPath, CreateRasterFileName2("OMNI_cum_curmap", speciesCode, iteration, timestep, "tif"))
        writeRaster(currMapOMNI01, currMapOMNIName, overwrite=TRUE)
      } 

      # If output options datasheet column SpatialOutputCCLog is TURE, save log outputs
      if(outputOptionsDatasheet$SpatialOutputCCLog==TRUE){
        currMapOMNI_log<-log(currMapOMNI)
        currMapOMNI_log01<-(currMapOMNI_log-cellStats(currMapOMNI_log,"min"))/(cellStats(currMapOMNI_log,"max")-cellStats(currMapOMNI_log,"min"))
        #Save log Omni-directional current density raster
        currMapOMNIName <- file.path(tempFolderPath, CreateRasterFileName2("OMNI_cum_curmap", speciesCode, iteration, timestep, "tif"))
        writeRaster(currMapOMNI_log01, currMapOMNIName, overwrite=TRUE)
      } 

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
