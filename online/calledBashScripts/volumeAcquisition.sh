#!/bin/bash

# Specify subjectID (folder)
subject=$1

# Specify online run number
id_run=$2

# Specify network 
network=$3

# path to rt-exported dicom data (should not change)
inputDir=$4

# Specify current dicom image which has to be preprocessed
newfile=$5 

# Specify dicom image t-1 for FD calculation
oldfile=$6

# flag if this is the first dicom image of a session
firstDicom=$7


sleep 0.1 

# 1.  dcm2nifti: convert dicom to nifti and save output immediately in corresponding folder
echo "..... dcm2nii"
cp $inputDir/test/"$subject"/"$newfile".dcm $inputDir/test/dummy2/"$newfile".dcm 
dcm2nii -v N -f Y -i N -p N -d N -e N $inputDir/test/dummy2/"$newfile".dcm 1> /dev/null
cp $inputDir/test/dummy2/"$newfile".nii.gz $inputDir/"$subject"/sessions/online"$id_run"/nifti/
        
# 2. online motion correction using McFlirt (6DOF) to EPIref
echo "..... McFlirt"
mcflirt -in $inputDir/"$subject"/sessions/online"$id_run"/nifti/"$newfile".nii.gz -reffile $inputDir/"$subject"/reference/nifti/001*.nii.gz -out $inputDir/"$subject"/sessions/online"$id_run"/reg/"$newfile"_reg -spline_final -plots #plots gives .par output

# collect 6 dimension motion parameters
cat $inputDir/"$subject"/sessions/online"$id_run"/reg/"$newfile"_reg.par >> $inputDir/"$subject"/sessions/online"$id_run"/motion/abs_MOTION_6dim.txt
rm $inputDir/"$subject"/sessions/online"$id_run"/reg/"$newfile"_reg.par

# 3. calculate frame-to-frame motion
if [ "$firstDicom" == 1 ];
    then 
    dummy=(0 0 0 0 0 0)
    echo ${dummy[@]} >> $inputDir/"$subject"/sessions/online"$id_run"/motion/rel_MOTION_6dim.txt; #write first row as zeros
else
    echo "..... frame-to-frame motion" 
    mcflirt -in $inputDir/"$subject"/sessions/online"$id_run"/nifti/"$newfile".nii.gz -reffile $inputDir/"$subject"/sessions/online"$id_run"/nifti/"$oldfile".nii.gz -out $inputDir/"$subject"/sessions/online"$id_run"/motion/tmp_rel_MOTION_6dim -plots
    cat $inputDir/"$subject"/sessions/online"$id_run"/motion/tmp_rel_MOTION_6dim.par >> $inputDir/"$subject"/sessions/online"$id_run"/motion/rel_MOTION_6dim.txt
    rm $inputDir/"$subject"/sessions/online"$id_run"/motion/tmp_rel_MOTION_6dim.nii.gz
    rm $inputDir/"$subject"/sessions/online"$id_run"/motion/tmp_rel_MOTION_6dim.par;
fi
                
# 4. apply 5mm spatial smoothing kernel
echo "..... 5mm Gaussian smoothing"
fslmaths $inputDir/"$subject"/sessions/online"$id_run"/reg/"$newfile"_reg.nii.gz -kernel gauss 2.1233226 -fmean $inputDir/"$subject"/sessions/online"$id_run"/reg/"$newfile"_reg_5mm.nii.gz

# 5. extract network means from motion corrected file (_reg)
echo "..... fslmeants timecourse separately"
roiList=`cat $inputDir/"$subject"/network/roiList.txt`

for roi in ${roiList[@]}
do
	fslmeants -i $inputDir/"$subject"/sessions/online"$id_run"/reg/"$newfile"_reg_5mm.nii.gz -m $inputDir/"$subject"/network/${roi} >> $inputDir/"$subject"/sessions/online"$id_run"/BOLD/temp_network.txt
done

# 6. Write temp output file in big file
dummy2=`cat $inputDir/"$subject"/sessions/online"$id_run"/BOLD/temp_network.txt`
echo ${dummy2} >> $inputDir/"$subject"/sessions/online"$id_run"/BOLD/NETWORKS.txt   
# important: remove temp_network as otherwise it keeps concatenating
rm $inputDir/"$subject"/sessions/online"$id_run"/BOLD/temp_network.txt



