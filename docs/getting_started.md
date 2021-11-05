---
layout: default
title: Getting started
---

# Getting started with **ST-Connect**

## Quickstart Tutorial

This quickstart tutorial will introduce you to basics of working with ST-Connect. The steps include:
<br>
* Installing ST-Connect
* Creating a new ST-Connect Library
* Configuring the ST-Connect Library
* Viewing model inputs
* Running the model
* Analyzing the results

## **Step 1: Install ST-Connect**
**ST-Connect** is a Package within the [SyncroSim](https://syncrosim.com/){:target="_blank"} simulation modeling framework; as such, running **ST-Connect** requires that the **SyncroSim** software be installed on your computer. To install **ST-Connect**, follow the instructions under [How to Install](https://apexrms.github.io/stconnect/){:target="_blank"}.


## **Step 2: Create a new ST-Connect Library**
Having installed the **ST-Connect** Package, you are now ready to create your first SyncroSim Library. A Library is a file (with extension *.ssim*) that contains all of your model inputs and outputs. Note that the format of each Library is specific to the Package for which it was initially created. To create a new Library, choose **New Library...** from the **File** menu.
<br>
<img align="middle" style="padding: 3px" width="700" src="assets/images/screencap-1.PNG">
<br>
In this window:
<br>
* Select the row for the ***stconnect - Connectivity planning for future climate and land-use change***. Note that as you select a row, the list of **Templates** available and suggested **File name** for that base package are updated.
* Select the ***Simple Conn. Model*** Template as shown above.
* Optionally type in a new **File name** for the Library (or accept the default); you can also change the **Folder** containing the file using the **Browse...** button.
<br>
When you are ready to create the Library file, click **OK**. A new Library will be created and loaded into the Library Explorer.

## **Step 3: Configure library settings**
For the model to run, SyncroSim needs to locate the locations of your R, Julia, and Zonation (if applicable) executables. The default file location of the Julia executable is blank. Select the Folder icon, navigate to the proper location on your local computer, then click **Open**.
<br>
<img align="middle" style="padding: 3px" width="700" src="assets/images/screencap-2.png">
<br>

## **Step 4: Review the model inputs**
The contents of your newly created Library are now displayed in the Library Explorer. Model inputs in SyncroSim are organized into Scenarios, where each Scenario consists of a suite of values, one for each of the Model's required inputs.

> **Note:**
> Because you chose the ***Simple Conn. Model*** Template when you created your Library, your Library already contains two pre-configured Scenarios with model inputs. These inputs were filled in and distributed as a sample with the package to help you get started quickly, and represent hypothetical management Scenarios: one a Baseline Scenario, and another 4X Less Urbanization Scenario.

<img align="middle" style="padding: 3px" width="400" src="assets/images/screencap-3.PNG">
<br>
As shown in the image above, the Library you have just opened contains two Scenarios, each with a unique ID. The first of these scenarios (with ID=350, as shown above in square brackets) is named ***Baseline Scenario***; this scenario contains a suite of model inputs corresponding to a hypothetical baseline harvest plan. The second scenario (with ID=358 and named ***4X Less Urbanization Scenario***) contains model inputs corresponding to an alternative plan where urbanization targets are 4 times less than those of the Baseline Scenario.
<br>
To view the details of the first of these Scenarios:
<br>
* Select the scenario named ***Baseline Scenario*** in the Library Explorer.
* Right-click and choose **Properties** from the context menu to view the details of the Scenario.

This opens the Scenario Properties window.
<br>
<img align="middle" style="padding: 3px" width="800" src="assets/images/screencap-4.png">
<br>
The first tab in this window, called **General**, contains three datasheets. The first, **Summary**, displays some generic information for the Scenario. The second, **Pipeline**, allows the user to select the run order of the inputs in the model. Finally, the **Datafeeds** datasheet displays a list of all data sources inputted into the model. 
<br>
<img align="middle" style="padding: 3px" width="750" src="assets/images/screencap-5.png">
<br>
The second tab in the window, **Run Control**, contains parameters for running a model simulation. In this example, the Scenario will run for 20 years, starting in the year 2011, and repeated for 3 Monte Carlo iterations. By default the **Landscape Change** and **Circuit Connectivity** analyses are run every 10 years.
<br>
<img align="middle" style="padding: 3px" width="500" src="assets/images/screencap-6.PNG">
<br>
Click on the **Landscape Change** and **Circuit Connectivity** tabs to familiarize yourself with this Scenario's inputs.
<br>
<img align="middle" style="padding: 3px" width="900" src="assets/images/screencap-7.PNG">
<br>

## **Step 5: Run the model**
Right-click on the ***Baseline Scenario*** in the **Scenario Manager** window and select **Run** from the context menu. If prompted to save your project, click **Yes**. This run will take some time (about 30 minutes). If the run is successful, you will see a Status of **Done** in the **Run Monitor** window, at which point you can close the **Run Monitor** window; otherwise, click on the **Run Log** link to see a report of any problems. Make any necessary changes to your Scenario, then re-run the Scenario.
<br>
<img align="middle" style="padding: 3px" width="500" src="assets/images/screencap-8.png">
<br>
Run the **4X Less Urbanization Scenario** next by repeating the steps above.

## **Step 6: Analyze the results**
To view results for your run, move to the **Charts** tab at the bottom left of the **Scenario Manager** screen and double-click on **Summary** to open it.
<br>
<img align="middle" style="padding: 3px" width="400" src="assets/images/screencap-9.png">
<br>
You can now view and compare the results of running your two Scenarios through the model from the ST-Connect Package.
<br>
<img align="middle" style="padding: 3px" width="900" src="assets/images/screencap-10.png">
<br>
Next, select the **Maps** tab from the bottom of the **Scenario Manager** window (i.e. beside the **Charts** tab). Double click on **All Variables** to see how **Landscape Change** and **Circuit Connectivity** have changed over the simulation.
<br>
<img align="middle" style="padding: 3px" width="900" src="assets/images/screencap-11.png">
<br>
You can also select the **Export** tab at the bottom of the **Scenario Manager** window. Double click on **State Classes** to generate a file with the model state class classifications. By default, an Excel file should open automatically (look for it on your Windows Task Bar) showing the projected state class by iteration and timestep.

> **Note:**
> You can add and remove Results Scenarios from the list of scenarios being analyzed by selecting a Scenario in the Library Explorer and then choosing either **Add to Results** or **Remove from Results** from the Scenario menu. **Scenarios** currently selected for analysis are highlighted in **bold** in the Library Explorer.