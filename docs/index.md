---
layout: default
title: Home
description: "Landing page for the Package"
permalink: /
---

# **ST-Connect** SyncroSim Package
<img align="right" style="padding: 13px" width="180" src="assets/images/logo/stconnect-sticker.png">
[![GitHub release](https://img.shields.io/github/v/release/ApexRMS/stconnect.svg?style=for-the-badge&color=d68a06)](https://GitHub.com/ApexRMS/stconnect/releases/)    <a href="https://github.com/ApexRMS/stconnect"><img align="middle" style="padding: 1px" width="30" src="assets/images/logo/github-trans2.png">
<br>
## Connectivity planning for future climate and land-use change
### *ST-Connect* is an open-source [SyncroSim](https://syncrosim.com/download/){:target="_blank"} Base Package for forecasting landscape connectivity.


**ST-Connect** uses a pipeline approach to chain together spatially-explicit models of landscape change and habitat connectivity. A simple **ST-Connect** model consists of two components. [ST-Sim](http://docs.stsim.net/){:target="_blank"} forecasts landscape dynamics, projecting changes in both vegetation and land use. [Circuitscape](https://circuitscape.org/){:target="_blank"} predicts connectivity in heterogenous landscapes, using algorithms from electronic circuit theory.
<br>
<img align="middle" style="padding: 3px" width="350" src="assets/images/pipeline-1.PNG">
<br>
**ST-Connect**'s accessible framework has helped support natural resource management projects such as a conservation prioritization project focusing on key wildlife species in Quebec [(Rayfield, Larocque, Martins et al., 2021)](https://quebio.ca/en/connectivity_report){:target="_blank"}. **ST-Connect** is a package that plugs into the [SyncroSim](https://syncrosim.com/){:target="_blank"} modeling framework. It can also be run from the R programming language using the [rsyncrosim](https://syncrosim.com/r-package/){:target="_blank"} R package and from the Python programming language using the [pysyncrosim](https://pysyncrosim.readthedocs.io/en/latest/){:target="_blank"} Python package.

## Requirements

This package requires the following software:<br>
The <a href="https://syncrosim.com/download/" target="_blank">latest version</a> of Syncrosim.
<br>
R [version 4.0.4](https://www.r-project.org/){:target="_blank"} or higher.
<br>
[Circuitscape 5](https://circuitscape.org/downloads/){:target="_blank"}.
<br>
Zonation [version 4.0.0](https://github.com/cbig/zonation-core/releases){:target="_blank"} (optional).

## How to Install

For installation instructions, see the **Install ST-Connect** section on the [Getting Started](https://apexrms.github.io/stconnect/getting_started.html) page.

## Getting Started

For more information on **ST-Connect**, including a Quickstart Tutorial, see the [Getting Started](https://apexrms.github.io/stconnect/getting_started.html) page.

## Links

Browse source code at
[http://github.com/ApexRMS/stconnect/](http://github.com/ApexRMS/stconnect/){:target="_blank"}
<br>
Report a bug at
[http://github.com/ApexRMS/stconnect/issues](http://github.com/ApexRMS/stconnect/issues){:target="_blank"}

## Developers

Bronwyn Rayfield (Author, maintainer) <a href="https://orcid.org/0000-0003-1768-1300" target="_blank"><img align="middle" style="padding: 0.5px" width="17" src="assets/images/ORCID.png"></a>
<br>
Alex Embrey (Author)
<br>
Colin Daniel (Author)
<br>
Valentin Lucet (Author)
<br>
Andrew Gonzalez (Author) <a href="https://orcid.org/0000-0001-6075-8081" target="_blank"><img align="middle" style="padding: 0.5px" width="17" src="assets/images/ORCID.png"></a>
<br>
Kyle Martins (Author)
