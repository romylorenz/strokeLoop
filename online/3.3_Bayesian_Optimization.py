# Real-time Bayesian optimization

# Bayesian optimisation consists of a two-stage procedure that repeats iteratively in a closed loop.
# The first stage is the data modeling stage, in which the algorithm uses all available FPN>DMN difference 
# values up to that iteration (read as text file derived from 3.2) to predict the subject’s brain response 
# across the entire task space using Gaussian process (GP) regression (Rasmussen and Williams, 2006; Brochu 
# et al., 2010; Shahriari et al., 2016). For GP, we used a zero mean function and the squared exponential kernel 
# (Rasmussen and Williams, 2006), and relied on a Python implementation from: [http://github.com/SheffieldML/GPy].
# The second stage is the guided search stage, in which an acquisition function is used to propose the task the subject 
# will need to perform in the next iteration (saved as text file that is read by 3.2). Here we used the upper-confidence 
# bound (GP-UCB) acquisition function (Srinivas et al., 2010) that favours the selection of points with high predicted mean 
# value (i.e., optimal tasks), but equally prefers points with high variance (i.e., tasks worth exploring).

import numpy, os
import time
import GPy #For GP regression, we use a Python implementation from: [http://github.com/SheffieldML/GPy].
import pylab as plt
from datetime import datetime
os.chdir("/Users/.../BayesianOptimization")
from GP_fMRIdesign import * #runs GP regression
from AcquisitionFunctions import * #computes AcquistionFunction
plt.ion() # puts in interactive mode

###########################################################################################################################
subject ='subjectXYZ'
id_run = '05'
dataFile='betas_diff.txt' # data file to 
inputFile='input.txt' # input file for stimulation
burnIn = 4 # burn-in refers to the number of task conditions to be sampled before Bayesian optimization is started (i.e., "closing the loop")

# define experiment parameter space
task_d={'11':'auditory comprehension-lev1' , '12':'auditory comprehension-lev2' ,  '13':'auditory comprehension-lev3','31':'semantic judgement-lev1', '32':'semantic judgement-lev2', '33':'semantic judgement-lev3','21':'naming-lev1', '22':'naming-lev2', '23':'naming-lev3', '41':'calculation-lev1','42':'calculation-lev2','43':'calculation-lev3','71':'go-nogo-lev1', '72':'go-nogo-lev2', '73':'go-nogo-lev3','51':'encoding-lev1','52':'encoding-lev2','53':'encoding-lev3', '61':'verbal learning-lev1','62':'verbal learning-lev2','63':'verbal learning-lev3'}
###########################################################################################################################

# settings that don't change
inputDir= '.../BayesianOpt'
stimDir='.../stimCommands'
roi=0 # Python indexed
old_fileLen=0
counter_=0
iter_=1

# access the directory in which the betas_diff are saved
os.chdir(inputDir)
############################################################################################################################
########### REAL-TIME BAYESIAN OPTIMIATION #################################################################################
############################################################################################################################

while True:# this is an endless loop
	time.sleep(.1)

	# if file exists enter loop and load in text file
	if os.path.isfile(dataFile)==True:
		
		# Dat are our beta difference values, i.e., FPN>DMN for each task condition
		Dat=numpy.loadtxt(dataFile,ndmin=2)
		# Stim refers to our task conditions in 2D space
		Stim=numpy.loadtxt('stimParams.txt',ndmin=2)

		fileLen=len(numpy.atleast_1d(Dat))

		#if we have new observations, we enter this loop again
		if fileLen>old_fileLen:

			#check if we are still in the burn-in phase or not
			if fileLen>=burnIn:
				print('**** Run Bayesian Optimization ****')
				
				#just some format wrangling
				Y = numpy.zeros((Dat.shape[0], 1))
				Y[:,0] = Dat[:,roi]

				# first component 9 (i.e., FPN) then component 10 (i.e., DMN)
				X=numpy.zeros((Dat.shape[0], 2))
				Stim_0id=Stim-1 # as Python is zero-indexed, we do this step here
				X[:,0]=Stim_0id[:,0] #component 9
				X[:,1]=Stim_0id[:,1] #component 10
			
				# compute GP regression (GP learner is a class from GP_fMRIdesign.py)
				# KernParam and sigmaNoise are hyper-paramters of the GP that were tuned based on offline pilot data
				m = GPlearner(X=X, Y=Y, KernParam =[4.65097742,2.58414647,4.72089739], sigmaNoise=0.60338111, plot=False)
				
				# compute GP-UCB acquistion function and return maximum of acquistion function which defined the task condition we sample next
				acquisition=m.SuggestNew(xRange = range(7), yRange=range(3), acqRule = "UCB", fPlus='Pred',returnGrid=True, iter_=iter_, dim=2)
				newTheta=numpy.copy(acquisition[0]) #acquisition[0] corresponds to maximum of acquistion function
				newTheta_1id=newTheta+1 # as MATLAB is not zero-indexed, we add the 1 again in
				str_newTheta_1id=str(numpy.int(newTheta_1id[0])) + str(numpy.int(newTheta_1id[1]))
				
				for k, v in task_d.iteritems(): 
					if str_newTheta_1id==k:
						str_newTask=v

				input_newTheta=numpy.zeros((1, 2))
				input_newTheta[0,0]=newTheta_1id[0]
				input_newTheta[0,1]=newTheta_1id[1]

				# save out the new task condition into a text file, to read by MATLAB script that controls tasks
				os.chdir(stimDir)
				numpy.savetxt(inputFile,input_newTheta,fmt='%i', delimiter='\t')

				# go back to inputDir
				os.chdir(inputDir)
				print ("!!!!!!!!!!!!!!!! Suggested task: %s " % (str_newTask))
				print ("!! points in Python ---  Task: %d ||| Level: %d" % ((newTheta[0]),(newTheta[1])))

				# plot results iteratively (new plot for each iteration)
				fig=plt.figure()
				ax1=fig.add_subplot(131)
				plot_limits=[[0,0],[3,7]]
				imgplot = plt.imshow(acquisition[2],origin='lower',alpha=0.9) # plot predictions
				plt.scatter(X[:,1],X[:,0], c='black', s=70,alpha=0.4,edgecolors='none')
				plt.xlabel('Difficulty Level')
				plt.ylabel('Task')
				plt.xticks(numpy.arange(0, 3, 1.0))
				plt.yticks(numpy.arange(0, 7, 1.0))
				plt.yticks([0,1,2,3,4,5,6],['aud comp','naming','sem judg','calc','encod','verb learn','go nogo'])
				ax1.title.set_text('Predictive Mean')

				ax2=fig.add_subplot(132)
				plot_limits=[[0,0],[3,7]]
				imgplot = plt.imshow(acquisition[3],origin='lower',alpha=0.9) # plot predictions
				plt.scatter(X[:,1],X[:,0], c='black', s=70,alpha=0.4,edgecolors='none')
				plt.xlabel('Difficulty Level')
				plt.ylabel('Task')
				plt.xticks(numpy.arange(0, 3, 1.0))
				plt.yticks(numpy.arange(0, 7, 1.0))
				#plt.yticks([0,1,2,3,4,5,6],['aud comp','sem judg','naming','calc','encod','verb learn','go nogo'])
				ax2.title.set_text('Uncertainty')

				ax3=fig.add_subplot(133)
				plot_limits=[[0,0],[3,7]]
				imgplot = plt.imshow(acquisition[1],origin='lower',alpha=0.9) # plot predictions
				plt.scatter(acquisition[0][1],acquisition[0][0], c='black', s=90,alpha=1,edgecolors='none')
				plt.xlabel('Difficulty Level')
				plt.ylabel('Task')
				plt.xticks(numpy.arange(0, 3, 1.0))
				plt.yticks(numpy.arange(0, 7, 1.0))
				#plt.yticks([0,1,2,3,4,5,6],['aud comp','sem judg','naming','calc','encod','verb learn','go nogo'])
				ax3.title.set_text('Acquisition Function')

				plt.savefig('BayesianModel.png')
				plt.pause(0.05)


				old_fileLen=fileLen # make sure to that we do not do this over and over again and just update for each new observations
				iter_+=1 # make sure that we keep track the number of iterations for GP-UCB acquisition function

		else:
			print('Waiting for file update .....') 
					
	else:
		print('Waiting for file .....') 


