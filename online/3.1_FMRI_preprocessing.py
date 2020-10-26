# Real-time fMRI preprocessing loop
#
# For online runs, a Python script watches the folder where the MR scanner exports the EPI dicom files to and 
# calls respective bash scripts to initiate preprocessing of each EPI image using FSL (Jenkinson et al., 2012).  
# Incoming EPI images were motion corrected (Jenkinson et al., 2002) in real-time with the previously offline obtained 
# functional image acting as reference. In addition, images were spatially smoothed using a 5 mm FWHM Gaussian kernel. 
# For each TR, means of the two brain networks were extracted.
#
# Requires FSL 5.0.6

import os
import numpy as np
import subprocess
import time
import csv
import numpy
import pickle
import scipy.io
from datetime import datetime
from StringIO import StringIO
from datetime import datetime
os.chdir("/Users/.../motionFD/")
from FD import *

###########################################################################################################################
subject = 'subjectXYZ'
id_run = '05'
network='YeoC9C10' #network masks

FD_thresh=1 # our threshold for frame-wise displacement
audio='Off' #turns on audio if subject moves too heavy
###########################################################################################################################

# settings that don't change
codeDir='/Users/.../calledBashScripts' #path to called FSL code
inputDir= '/Users/.../rt-data' # path to data
iter_ = 1 # keeps track of which time step we are on (to avoid falling behind)
counter_=1

# initial setup (create folders etc.):
os.chdir(codeDir)
subprocess.call(['./initializeRun.sh ' + subject + ' ' + id_run + ' ' + network + ' ' + inputDir ], shell=True)

# location of ORIGINAL subject-specific files:
os.chdir(inputDir + '/test/'+ subject)
############################################################################################################################
##################### REAL-TIME FMRI PIPELINE  #############################################################################
############################################################################################################################
# begin while loop:
while True:
	time.sleep(.1)

	# this is specific to the format of the dicom files from the Siemens scanner
	if iter_ < 10:
		iter_string='000'+str(iter_)
	elif iter_ < 100:
		iter_string='00'+str(iter_)
	elif iter_<1000:
		iter_string='0'+str(iter_)
	else:
		iter_string=str(iter_)

	newfile = '001_0000' + str(id_run) + '_00' + iter_string
	newObs = '001_0000' + str(id_run) + '_00' + iter_string + '.dcm' # this is just used to have a cleaner code

	# tag the first dicom of each new session because of registration specifics
	if iter_ == 1:
		firstDicom = 1 #this is to flag first dicom of each session
		oldfile=newfile #as no old file exists we need to just input the same file - won't be used
	else: 
		firstDicom = 0

################################################################################
	if newObs in os.listdir(os.getcwd()):
		start=datetime.now()
		
		################################################################################
		######################## FSL preprocessing #####################################
		
		# next EPI has arrived, start preprocessing it:
		print('TR = ' + str(iter_))
		print(newObs)
		os.chdir(codeDir)
		# call bash script
		subprocess.call(['./volumeAcquisition.sh ' + subject + ' ' + id_run + ' ' + network + ' ' + inputDir + ' ' + newfile + ' ' + oldfile + ' ' + str(firstDicom) ], shell=True)

		################################################################################
		################## calculate frame-wise displacement ###########################

		if iter_!=1:
			FD_power=calculate_FD_P(inputDir + '/' + subject + '/sessions/' + 'online' + id_run + '/motion/rel_MOTION_6dim.txt')
			np.savetxt(inputDir + '/' + subject + '/sessions/' + 'online' + id_run + '/motion/FD.txt', FD_power,fmt='%10.5f', delimiter='\t')
			print('..... FD: ' + str(np.round(FD_power[-1],decimals=4)) + ' mm')

			if FD_power[-1]>=FD_thresh:
				print('!!!!!!!!!!!!! WARNING: Too heavy subject movement !!!!!!!!!!!!!')
				if audio=='On':
					os.system('say "high movement" &') #use the & to keep Python running
		################################################################################
		######################## initiate next TR ######################################

		iter_ += 1
		oldObs = newObs
		oldfile = newfile
		counter_=1 
		os.chdir(inputDir + '/test/'+ subject)
		print datetime.now()-start

	else:
		if firstDicom==1: # scan has not started yet - this prevents of exiting the loop
			print('Waiting for scan to start ...')
			os.chdir(inputDir + '/test/'+ subject)

		else: 
			print('Nothing new ...') # latest observation hasn't arrived yet
			counter_+=1 # start a counter so that we can automatically stop acquisition when no more dicoms are received

			if counter_>150:
				break # this automatically stops script when no more dicoms are received
			else: 
				os.chdir(inputDir + '/test/'+ subject)
		
############ NOTE ########################################################################################################
# if permission denied to execute bash files from python, do the following:
# 1. cd [DIRECTORY]
# 2. chmod 777 * --> change the read, write, execute permissions for all files in the directory
