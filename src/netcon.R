library(raster)
library(rsyncrosim)
library(igraph)
#install.packages("devtools")
#library("devtools")
#install_github("achubaty/grainscape")
library(grainscape)

e = ssimEnvironment()

source(file.path(e$ModuleDirectory, "common.R"))

#datasheets
dispersalIn = GetDataSheetExpectData("stconnect_NCDispersal", GLOBAL_Scenario)
networkConnectivityOut = datasheet(GLOBAL_Scenario, "stconnect_NCOutputSummary")
btwnOut = datasheet(GLOBAL_Scenario, "stconnect_NCOutputBetweenness")

#file paths
tempFolderPath = envTempFolder("NetworkConnectivity")

#Read in all habitat patch rasters
habitatRasterAll <- datasheetRaster(GLOBAL_Scenario, datasheet = "stconnect_HSOutputHabitatPatch")
#Read in all reistance rasters
resistanceRasterAll <- datasheetRaster(GLOBAL_Scenario, datasheet = "stconnect_HSOutputResistance")

#Simulation
envBeginSimulation(GLOBAL_TotalIterations * GLOBAL_TotalTimesteps)

for (iteration in GLOBAL_MinIteration:GLOBAL_MaxIteration) {
  
  for (timestep in GLOBAL_MinTimestep:GLOBAL_MaxTimestep) {
    
    envReportProgress(iteration, timestep)
    
    for (sprow in 1:nrow(GLOBAL_Species)) {
      
      species = GLOBAL_Species[sprow, "Name"]
      
      #Input habitat patch raster
      habitatRasterName <- gsub(" ", "\\.",paste0("HabitatPatch.", species, ".it", iteration, ".ts", timestep))
      habitatRaster <- habitatRasterAll[[habitatRasterName]]
      #Input resistance raster
      resistanceRasterName <- gsub(" ", "\\.",paste0("Resistance.", species, ".it", iteration, ".ts", timestep))
      resistanceRaster <- resistanceRasterAll[[resistanceRasterName]]
      #Species dispersal values
      dispersalValues <- dispersalIn[which(dispersalIn$SpeciesID == species), ]
      
      #extract mpg
      mpg <- MPG(cost = resistanceRaster, patch = habitatRaster)
      
      #calculate overall EC
      dist_mat <- shortest.paths(mpg$mpg, weights = edge_attr(mpg$mpg, 'lcpPerimWeight'))
      
      #Gap
      #matrix of dispersal kernel
      kernel_mat <- exp(-dist_mat / dispersalValues$MaximumGapCrossingDistance)
      
      #matrix of product node attributes
      attribute_mat1 <- as.vector(as.numeric(vertex_attr(mpg$mpg, 'patchArea')))
      attribute_mat <- attribute_mat1 %*% t(attribute_mat1)
      
      #matrix of PCvalues
      PC_mat <- kernel_mat * attribute_mat
      rm(attribute_mat)
      
      PCnum <- sum(PC_mat)
      ECGap <- sqrt(PCnum)
      
      #Natal
      #matrix of dispersal kernel
      kernel_mat <- exp(-dist_mat / dispersalValues$MaximumNatalDispersalDistance)
      rm(dist_mat)
      
      #matrix of product node attributes
      attribute_mat1 <- as.vector(as.numeric(vertex_attr(mpg$mpg, 'patchArea')))
      attribute_mat <- attribute_mat1 %*% t(attribute_mat1)
      
      #matrix of PCvalues
      PC_mat <- kernel_mat * attribute_mat
      rm(attribute_mat)
      
      PCnum <- sum(PC_mat)
      ECNatal <- sqrt(PCnum)
      
      data = data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, EquivalentConnectivityGap = ECGap, EquivalentConnectivityNatal = ECNatal)
      networkConnectivityOut = addRow(networkConnectivityOut, data)

      
      #Betweenness
      btwn <- data.frame(patchId = as.numeric(vertex_attr(mpg$mpg, 'patchId')), btwn = betweenness(mpg$mpg, weights = edge_attr(mpg$mpg, 'lcpPerimWeight'), directed = FALSE))
      #make a look-up table between patch id and betweenness value
      btwn_lookup <- cbind(patchId = btwn$patchId, btwn = 1 / (max(btwn$btwn) - min(btwn$btwn)) * (btwn$btwn - min(btwn$btwn)))
      #replace patch ids with betweeness values
      btwnRaster <- reclassify(mpg$patchId, btwn_lookup)
      
      #Save rasters
      btwnName = file.path(tempFolderPath, CreateRasterFileName2("Betweenness", species, iteration, timestep, "tif"))
      writeRaster(btwnRaster, btwnName, overwrite = TRUE)
      df = data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, Filename = btwnName)
      btwnOut = addRow(btwnOut, df)
      }
    
    envStepSimulation()
  }
}

saveDatasheet(GLOBAL_Scenario, networkConnectivityOut, "stconnect_NCOutputSummary")
saveDatasheet(GLOBAL_Scenario, btwnOut, "stconnect_NCOutputBetweenness")

envEndSimulation()
