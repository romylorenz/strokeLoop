#!/bin/bash

# This scripts takes the 3D EPI functional reference image of the subject and registers it to the 
# subject's structural image using boundary-based registration. Pre-specified network masks (in MNI space; 
# multiple masks are expected in a 4D nifti file) are then registered from MNI to the subject's functional space. 
# FSLview is used to visualise network registration for inspection.  
# Requires FSL 5.0.9

# Specify subjectID (folder)
subject=subjectXYZ

# Specify network masks which we need to register - network masks are expected to be 4D nifti files
network=YeoC9C10

# Specify online run number (2 digits)
id_run=08

# Specifiy image number (3 digits)
id_image=001

# path to rt-exported dicom data (should not change)
inputDir=/Users/...

# networkDir
networkDir=/Users/.../Real_time_ROIs

# FSL dir
FSLDir=/usr/local/fsl

#############################################
######## START prep EPI reference ###########
#############################################
echo -- prep EPI reference: ${subject}

# time this script
start=$SECONDS

# 1. Define reference image based on parameters defined above
EPIref=001_0000${id_run}_000${id_image}

# 2. dcm2nii
echo "..... dcm2nii"
cp ${inputDir}/test/${subject}/${EPIref}.dcm ${inputDir}/test/dummy2/ #only this session's files arrive here
dcm2nii -v N -f Y -i N -p N -d N -e N ${inputDir}/test/dummy2/${EPIref}.dcm
mv ${inputDir}/test/dummy2/${EPIref}.nii.gz ${inputDir}/${subject}/reference/nifti/ 

# 3. BBR registration (functional to structural image) -  this is speeded up by first downsampling MPRAGE from 1mm to 2mm
echo "..... BBR func2struc registration"
# get MPRAGE from 1mm into 2mm space 
flirt -in ${inputDir}/${subject}/MPRAGE/MPRAGE_ax_brain.nii.gz -ref ${inputDir}/${subject}/MPRAGE/MPRAGE_ax_brain.nii.gz -applyisoxfm 2 -interp nearestneighbour -out ${inputDir}/${subject}/MPRAGE/MPRAGE_ax_brain_2mm.nii.gz -omat ${inputDir}/${subject}/MPRAGE/struc122.mat
flirt -in ${inputDir}/${subject}/MPRAGE/MPRAGE_ax.nii.gz -ref ${inputDir}/${subject}/MPRAGE/MPRAGE_ax.nii.gz -applyisoxfm 2 -interp nearestneighbour -out ${inputDir}/${subject}/MPRAGE/MPRAGE_ax_2mm.nii.gz
convert_xfm -inverse -omat ${inputDir}/${subject}/MPRAGE/struc221.mat ${inputDir}/${subject}/MPRAGE/struc122.mat
# run BBR
epi_reg --epi=${inputDir}/${subject}/reference/nifti/${EPIref}.nii.gz --t1=${inputDir}/${subject}/MPRAGE/MPRAGE_ax_2mm.nii.gz --t1brain=${inputDir}/${subject}/MPRAGE/MPRAGE_ax_brain_2mm.nii.gz --out=${inputDir}/${subject}/reference/reg/func2struc
convert_xfm -inverse -omat ${inputDir}/${subject}/reference/reg/struc2func.mat ${inputDir}/${subject}/reference/reg/func2struc.mat

# 4.FLIRT func2MNI (concat struc2MNI and func2struc in order to get func2MNI)
echo "..... func2MNI registration"
convert_xfm -omat ${inputDir}/${subject}/reference/reg/func2struc1.mat -concat ${inputDir}/${subject}/MPRAGE/struc221.mat ${inputDir}/${subject}/reference/reg/func2struc.mat
convert_xfm -omat ${inputDir}/${subject}/reference/reg/func2MNI.mat -concat ${inputDir}/${subject}/MPRAGE/struc2MNI.mat ${inputDir}/${subject}/reference/reg/func2struc1.mat
convert_xfm -inverse -omat ${inputDir}/${subject}/reference/reg/MNI2func.mat ${inputDir}/${subject}/reference/reg/func2MNI.mat

# 5. Register our MNI networks to subject's functional space
echo "..... network registration (MNI2func)"
flirt -in ${networkDir}/${network}.nii.gz -ref ${inputDir}/${subject}/reference/nifti/${EPIref}.nii.gz -applyxfm -init ${inputDir}/${subject}/reference/reg/MNI2func.mat -out ${inputDir}/${subject}/network/${network}_subject.nii.gz -paddingsize 0.0 -interp nearestneighbour

# 6. Register brain mask (in structural space) to subject's functional space (brain mask is outputted by brain extraction in script 01_prepDir_prepMPRAGE.sh)
echo "..... brain mask registration (struc2func)"
flirt -in ${inputDir}/${subject}/MPRAGE/*_mask.nii.gz -ref ${inputDir}/${subject}/reference/nifti/${EPIref}.nii.gz -applyxfm -init ${inputDir}/${subject}/reference/reg/struc2func.mat -out ${inputDir}/${subject}/reference/nifti/mask.nii.gz -paddingsize 0.0 -interp nearestneighbour

# 7. Split 4D nifit network file and save out roiList as text file
echo "..... split ROIs"
fslsplit ${inputDir}/${subject}/network/${network}_subject.nii.gz ${inputDir}/${subject}/network/roi -t
basename -a ${inputDir}/${subject}/network/roi* > ${inputDir}/${subject}/network/roiList.txt
cat ${inputDir}/${subject}/network/roiList.txt

# stop timing
elapsed=$(($SECONDS - $start))
echo "!!! script runtime: " ${elapsed} "seconds"

# 8. Visual checking network registration
echo "..... show network registration"
fslview ${inputDir}/${subject}/reference/nifti/${EPIref}.nii.gz ${inputDir}/${subject}/network/${network}_subject.nii.gz -l Red

