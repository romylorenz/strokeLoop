#!/bin/bash

# Specify subjectID (folder)
subject=$1

# Specify online run number
id_run=$2

# Specify network 
network=$3

# path to rt-exported dicom data (should not change)
inputDir=$4

###########################################
# Start EPI dicom import simulation
#bash simulate_EPI_import.sh > /dev/null &
##########################################

#############################################
######## START ONLINE EPI PIPELINE ##########
#############################################
echo -- online EPI preproc pipeline: "$subject"
echo ----  online"$id_run"

# Create subject folder
mkdir -p $inputDir/"$subject"/sessions/online"$id_run"/
mkdir -p $inputDir/"$subject"/sessions/online"$id_run"/nifti
mkdir -p $inputDir/"$subject"/sessions/online"$id_run"/reg
mkdir -p $inputDir/"$subject"/sessions/online"$id_run"/BOLD
mkdir -p $inputDir/"$subject"/sessions/online"$id_run"/motion
mkdir -p $inputDir/"$subject"/sessions/online"$id_run"/BayesianOpt
mkdir -p $inputDir/"$subject"/sessions/online"$id_run"/RT

#delete all .dcm files in dummy folder - security step
rm ${inputDir}/test/dummy2/*