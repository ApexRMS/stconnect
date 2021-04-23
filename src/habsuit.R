# Workspace setup
# Check for installed packages and install missing ones
list.of.packages <- c("raster", "rsyncrosim")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(raster)
library(rsyncrosim)


e = ssimEnvironment()
source(file.path(e$PackageDirectory, "common.R"))

# Output frequency of habitat analyses ---------------------------------------------------

# Get the output options datasheet
outputOptionsDatasheet <- datasheet(ssimObject = GLOBAL_Scenario, name = "stconnect_HSOutputOptions")

# If datasheet is not empty, get the output frequency
if(is.na(outputOptionsDatasheet$SpatialOutputHSTimesteps)){
    stop("No habitat output frequency specified.")
} else {
    outputFreq <- outputOptionsDatasheet$SpatialOutputHSTimesteps
}


#datasheets
stateClassIn = datasheet(GLOBAL_Scenario,"stsim_StateClass")
names(stateClassIn) <- c("StateClassID", "StateLabelXID", "StateLabelYID", "ID", "Color")
habitatSuitabilityIn = GetDataSheetExpectData("stconnect_HSHabitatSuitability", GLOBAL_Scenario)
habitatSuitabilityIn <- merge(habitatSuitabilityIn,stateClassIn,by="StateClassID")
habitatPatchIn = GetDataSheetExpectData("stconnect_HSHabitatPatch", GLOBAL_Scenario)
habitatSuitabilityOut = datasheet(GLOBAL_Scenario, "stconnect_HSOutputHabitatSuitability")
habitatPatchOut = datasheet(GLOBAL_Scenario, "stconnect_HSOutputHabitatPatch")

#file paths
tempFolderPath = envTempFolder("HabitatSuitability")

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
            suitabilityValues <- habitatSuitabilityIn[which(habitatSuitabilityIn$SpeciesID == species), c("ID", "Value")]
            patchValues <- habitatPatchIn[which(habitatPatchIn$SpeciesID == species), c("HabitatSuitabilityThreshold", "MinimumHabitatPatchSize")]

            if (nrow(suitabilityValues) == 0 || nrow(patchValues) == 0) {
                next
            }

            suitabilityThreshold <- patchValues$HabitatSuitabilityThreshold
            patchSizeThreshold <- patchValues$MinimumHabitatPatchSize

            #Input stateclass raster
            stateMap <- datasheetRaster(GLOBAL_Scenario, datasheet = "stsim_OutputSpatialState", iteration = iteration, timestep = timestep)

            #Habitat suitability map
            suitabilityRaster <- reclassify(stateMap, rcl = suitabilityValues)

            #Habitat patch map
            habitatRaster <- Which(suitabilityRaster >= suitabilityThreshold)
            #convert from hectares to m
            conversionFromHa <- res(habitatRaster)[1]*res(habitatRaster)[2]*(1/10000)
            habitatClump <- clump(habitatRaster)
            habitatClumpID <- data.frame(freq(habitatClump))
            #Remove clump observations with frequency smaller than minimum habitat patch size (ha)
            habitatClumpID <- habitatClumpID[habitatClumpID$count < patchSizeThreshold/conversionFromHa,]
            habitatRaster[Which(habitatClump %in% habitatClumpID$value)] <- 0
            #Set NA's from habitat suitability
            habitatRaster[is.na(suitabilityRaster)]<-NA

            #Save rasters
            suitabilityName = file.path(tempFolderPath, CreateRasterFileName2("HabitatSuitability", speciesCode, iteration, timestep, "tif"))
            patchName = file.path(tempFolderPath, CreateRasterFileName2("HabitatPatch", speciesCode, iteration, timestep, "tif"))

            writeRaster(suitabilityRaster, suitabilityName, overwrite = TRUE)
            df = data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, Filename = suitabilityName)
            habitatSuitabilityOut = addRow(habitatSuitabilityOut, df)

            writeRaster(habitatRaster, patchName, overwrite = TRUE)
            df = data.frame(Iteration = iteration, Timestep = timestep, SpeciesID = species, Filename = patchName)
            habitatPatchOut = addRow(habitatPatchOut, df)

        }

        envStepSimulation()
    }
}

saveDatasheet(GLOBAL_Scenario, habitatSuitabilityOut, "stconnect_HSOutputHabitatSuitability")
saveDatasheet(GLOBAL_Scenario, habitatPatchOut, "stconnect_HSOutputHabitatPatch")

envEndSimulation()
