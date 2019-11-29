library(raster)
library(rsyncrosim)

e = ssimEnvironment()
source(file.path(e$ModuleDirectory, "common.R"))
#directory where Circuitscape is installed
CS_exe<-"\"C:/Program Files/Circuitscape/cs_run.exe\"" # Don't forget the "Program Files" problem

#datasheets
resistanceIn = datasheet(GLOBAL_Scenario, "stconnect_HSOutputResistance")
circuitOut = datasheet(GLOBAL_Scenario, "stconnect_CCOutputCumulativeCurrent", empty=T)

#file paths
tempFolderPath = envTempFolder("CircuitConnectivity")

#Create ouput folder
outputFolderPath <- envOutputFolder(GLOBAL_Scenario, "stconnect_CCOutputCumulativeCurrent")
#Temporary Hack: save a small file to the output folder so that it doesn't get deleted when SyncroSim cleans the library and automatically deletes empty folders 
write.table("file to save folder", file.path(outputFolderPath,"saveFolder.txt"))

#Load all resistance rasters
resistanceRasterAll <- datasheetRaster(GLOBAL_Scenario, datasheet = "stconnect_HSOutputResistance")

#Input resistance raster template
resistanceRasterName <- gsub(" ", "\\.",paste0("Resistance.", GLOBAL_Species$Name[1], ".it", GLOBAL_MinIteration, ".ts", GLOBAL_MinTimestep))
resistanceRaster <- resistanceRasterAll[[resistanceRasterName]]

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

#Simulation
envBeginSimulation(GLOBAL_TotalIterations * GLOBAL_TotalTimesteps)

for (iteration in GLOBAL_MinIteration:GLOBAL_MaxIteration) {
  
  for (timestep in GLOBAL_MinTimestep:GLOBAL_MaxTimestep) {
    
    envReportProgress(iteration, timestep)
    
    for (sprow in 1:nrow(GLOBAL_Species)) {
      
      species = GLOBAL_Species[sprow, "Name"]

      #Input resistance raster
      resistanceRasterName <- gsub(" ", "\\.",paste0("Resistance.", species, ".it", iteration, ".ts", timestep))
      resistanceRaster <- resistanceRasterAll[[resistanceRasterName]]
      #extend resistanceRaster NS
      resistanceRasterNS<-extend(resistanceRaster,extentNS,values=1)
      #temp for Hawaii TestArea example
      resistanceRasterNS[,1]<-1
      
      #extend resistanceRaster EW
      resistanceRasterEW<-extend(resistanceRaster,extentEW,value=1)
      #temp for Hawaii TestArea example
      resistanceRasterEW[nrow(resistanceRasterEW),]<-1
      
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
      currMapOMNI01<-(currMapOMNI-cellStats(currMapOMNI,"min"))/(cellStats(currMapOMNI,"max")-cellStats(currMapOMNI,"min"))
      
      #Save Omni-directional current density raster
      currMapOMNIName <- file.path(tempFolderPath, CreateRasterFileName2("OMNI_cum_curmap", species, iteration, timestep, "tif"))
      writeRaster(currMapOMNI01, currMapOMNIName)
      
      #Write output file
      data <- data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, Filename = currMapOMNIName)
      circuitOut <- addRow(circuitOut, data)
      
    }
    
    envStepSimulation()
  }
}

saveDatasheet(GLOBAL_Scenario, circuitOut, "stconnect_CCOutputCumulativeCurrent")

envEndSimulation()
