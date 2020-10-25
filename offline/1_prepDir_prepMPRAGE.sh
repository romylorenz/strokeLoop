#!/bin/bash

# This script does brain extraction of the structural image and registers it to MNI space. 
# FSLview is used to visualise brain extraction results for inspection.
# BET parameters could be modified depending on results of brain extraction.
# Requires FSL 5.0.9

# Specify subjectID (folder)
subject=subjectXYZ

# MPRAGE run number (2 digits)
id_MPRAGE=02

########## BET paramneters ##################
#############################################
cog=(79 115 137) #centre of gravity
f=0.5 #fractional intensity threshold (0->1); default=0.5; smaller values give larger brain outline estimates
g=0 #vertical gradient in fractional intensity threshold (-1->1); default=0; positive values give larger brain outline at bottom, smaller at top
#############################################
#############################################

# path to rt-exported dicom data (should not change)
inputDir=/Users/...

# FSL dir
FSLDir=/usr/local/fsl

######################################################################
############### Creating all necessary directories #####################
######################################################################
echo -- creating directories for: ${subject}

mkdir -p ${inputDir}/${subject}
mkdir -p ${inputDir}/${subject}/MPRAGE

mkdir -p ${inputDir}/${subject}/reference
mkdir -p ${inputDir}/${subject}/reference/nifti
mkdir -p ${inputDir}/${subject}/reference/reg

mkdir -p ${inputDir}/${subject}/network
mkdir -p ${inputDir}/${subject}/sessions

chmod 777 ${inputDir}/${subject}/*
chmod 777 ${inputDir}/${subject}/reference/*

#delete all .dcm files in dummy folder - security step
rm ${inputDir}/test/dummy2/*

#############################################
########## START MPRGAGE PIPELINE ###########
#############################################
echo -- MPRAGE pipeline: ${subject}

# time this script
start=$SECONDS

# 1. Convert dicoms into nifti and save in MPRAGE directory
echo "..... dcm2nii"
# p - protocol in filename = MPRAGE
cp ${inputDir}/test/${subject}/001_0000${id_MPRAGE}_*.dcm ${inputDir}/test/dummy2/ #only this session's files arrive here
dcm2nii -v N -d N -i N -f N -p Y -d N -e N ${inputDir}/test/dummy2/001_0000${id_MPRAGE}_*.dcm
mv ${inputDir}/test/dummy2/MPRAGE*.nii.gz ${inputDir}/${subject}/MPRAGE/MPRAGE.nii.gz # rename 

# 2. Axial Reorientation
echo "..... axial reorientation"
fslswapdim ${inputDir}/${subject}/MPRAGE/MPRAGE.nii.gz RL PA IS ${inputDir}/${subject}/MPRAGE/MPRAGE_ax.nii.gz

# 3. Brain extraction
echo "..... bet"
bet ${inputDir}/${subject}/MPRAGE/MPRAGE_ax.nii.gz ${inputDir}/${subject}/MPRAGE/MPRAGE_ax_brain.nii.gz -c ${cog[@]} -f ${f} -g ${g} -m

# 4. FLIRT struc2MNI (12 DOF)
echo "..... struc2MNI registration"
flirt -in ${inputDir}/${subject}/MPRAGE/MPRAGE_ax_brain.nii.gz -ref ${FSLDir}/data/standard/MNI152_T1_2mm_brain.nii.gz -out ${inputDir}/${subject}/MPRAGE/struc2MNI -omat ${inputDir}/${subject}/MPRAGE/struc2MNI.mat -cost corratio -dof 12 -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -interp trilinear
convert_xfm -inverse -omat ${inputDir}/${subject}/MPRAGE/MNI2struc.mat ${inputDir}/${subject}/MPRAGE/struc2MNI.mat

# stop timing
elapsed=$(($SECONDS - $start))
echo "!!! script runtime: " ${elapsed} "seconds"

# 5. Visual checking BET result
echo "..... check output"
fslview $inputDir/${subject}/MPRAGE/MPRAGE_ax.nii.gz $inputDir/${subject}/MPRAGE/MPRAGE_ax_brain.nii.gz -l Green