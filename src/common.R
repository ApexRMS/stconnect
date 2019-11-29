library(rsyncrosim)

CreateRasterFileName <- function(prefix, iteration, timestep, extension) {
    return(sprintf("%s.it%s.ts%s.%s", prefix, iteration, timestep, extension))
}

CreateRasterFileName2 <- function(prefix, species, iteration, timestep, extension) {
    return(sprintf("%s.%s.it%s.ts%s.%s", prefix, species, iteration, timestep, extension))
}

GetDataSheetExpectData <- function(name, ssimObj) {
    ds = datasheet(ssimObj, name)
    if (nrow(ds) == 0) { stop(paste0("No data for: ", name)) }
    return(ds)
}

GetSingleValueExpectData <- function(df, name) {
    v = df[, name]
    if (is.na(v)) { stop(paste0("Missing data for: ", name)) }
    return(v)
}

GetRowBySpecies <- function(df, species) {

    r = subset(r, SpeciesID == species)

    if (nrow(r) > 1) {
        stop(sprintf("Not expecting multiple rows for species: %s", species))
    }

    if (nrow(r) == 1) {
        return(r)
    }
    else {
        return(NULL)
    }
}

GetRowBySpeciesAndStateClass <- function(df, species, stateClass) {

    r = subset(r, SpeciesID == species & StateClassID == stateClass)

    if (nrow(r) > 1) {
        stop(sprintf("Not expecting multiple rows for species and state class: %s -> %s", species, stateClass))
    }

    if (nrow(r) == 1) {
        return(r)
    }
    else {
        return(NULL)
    }
}

GetRowByIterationAndTimestep <- function(df, iteration, timestep) {

    r = subset(df,
        Iteration == iteration & !is.na(Iteration) &
        Timestep == timestep & !is.na(Timestep))

    if (nrow(r) > 1) {
        stop(sprintf("Not expecting multiple rows for Iteration = %s, Timestep = %s: ", iteration, timestep))
    }

    if (nrow(r) == 1) {
        return(r)
    }
    else {
        return(NULL)
    }
}

e = ssimEnvironment()
GLOBAL_Session = session()
GLOBAL_Library = ssimLibrary(session = GLOBAL_Session)
GLOBAL_Project = project(GLOBAL_Library, project = as.integer(e$ProjectId))
GLOBAL_Scenario = scenario(GLOBAL_Library, scenario = as.integer(e$ScenarioId))
GLOBAL_Species = GetDataSheetExpectData("ConnCons_Species", GLOBAL_Project)
GLOBAL_RunControl = GetDataSheetExpectData("STSim_RunControl", GLOBAL_Scenario)
GLOBAL_MaxIteration = GetSingleValueExpectData(GLOBAL_RunControl, "MaximumIteration")
GLOBAL_MinIteration = GetSingleValueExpectData(GLOBAL_RunControl, "MinimumIteration")
GLOBAL_MinTimestep = GetSingleValueExpectData(GLOBAL_RunControl, "MinimumTimestep")
GLOBAL_MaxTimestep = GetSingleValueExpectData(GLOBAL_RunControl, "MaximumTimestep")
GLOBAL_TotalIterations = (GLOBAL_MaxIteration - GLOBAL_MinIteration + 1)
GLOBAL_TotalTimesteps = (GLOBAL_MaxTimestep - GLOBAL_MinTimestep + 1)