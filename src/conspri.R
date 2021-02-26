library(raster)
library(rsyncrosim)

e = ssimEnvironment()
source(file.path(e$PackageDirectory, "common.R"))

#datasheets
runSettingsIn = GetDataSheetExpectData("stconnect_CPRunSetting", GLOBAL_Scenario)
prioritizationOut = datasheet(GLOBAL_Scenario, "stconnect_CPOutputCumulative")

#file paths
tempFolderPath = envTempFolder("ConservationPrioritization")
zonationPath<-"C:/Program Files/zonation 4.0.0rc1_compact/bin/zig4.exe"

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

# Temporal resolution of analysis in years
# e.g. analyse every 10 years
temporalRes <- 9
# Set of timesteps to analyse
timestepSet <- seq(GLOBAL_MinTimestep, GLOBAL_MaxTimestep, by=temporalRes)

#Simulation
envBeginSimulation(GLOBAL_TotalIterations * GLOBAL_TotalTimesteps)

for (iteration in GLOBAL_MinIteration:GLOBAL_MaxIteration) {
  
  for (timestep in timestepSet) {
    
    envReportProgress(iteration, timestep)
    
    carbonStockasters <- stack(datasheetRaster(GLOBAL_Scenario, datasheet = "stsimsf_OutputSpatialStockGroup", iteration = iteration, timestep = timestep))
    # Keep only Total Ecosystem Carbon
    result <- data.frame("Ecosystem.Carbon"=rep(NA, length(names(carbonStockasters))))
    for(i in 1:length(names(carbonStockasters))){
      result$Ecosystem.Carbon[i]<-grepl("stkg_884", names(carbonStockasters)[i], fixed=TRUE)
    }
    carbonStockasters <- dropLayer(carbonStockasters, which(result==FALSE))
    rasIn<-stack(carbonStockasters,
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
    system(paste0("\"",zonationPath, "\" ", zonationScenario))

    df = data.frame(Iteration = iteration, Timestep = timestep, Filename = file.path(tempFolderPath, CreateRasterFileName("OutputZonation", iteration, timestep, "rank.compressed.tif")))
    prioritizationOut<-addRow(prioritizationOut, df)
    
    envStepSimulation()
  }
}
    
saveDatasheet(GLOBAL_Scenario, prioritizationOut, "stconnect_CPOutputCumulative")

