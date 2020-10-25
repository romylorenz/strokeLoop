### Bayesian optimisation for rt-fMRI experiment design

import numpy, os
import GPy #For GP regression, we use a Python implementation from: [http://github.com/SheffieldML/GPy]. 
import pylab as plt
os.chdir("/Users/.../BayesianOptimization/")
from AcquisitionFunctions import *
plt.ion()

class GPlearner():
	"""
	Bayesian optimisation for rt-fMRI experiment design

	"""
	def __init__(self, X=None, Y=None, KernParam=None, sigmaNoise=None, plot=True):
		"""
		Initialise class of GP learner

		Notes: a RBF kernel is used with a single parameter for all dimensions 

		INPUT:
			- X: numpy array of coefficients for predictors 
			- Y: 1-dimensional response (ie measurements of unknown objective function)
			- KernParam: variance[0] and lengthscale[1] for RBF kernel (ie should be 2x1 numpy array)
			- sigmaNoise: observation noise (assumed white iid)
			- plot: boolean, should contours be plotted?

		all parameter can be omited and supplied later

		"""

		self.X = X
		self.Y = Y
		self.p = X.shape[1]
		self.KernParam = KernParam
		self.sigmaNoise = sigmaNoise
		self.plot = plot
		self.burnIn()

	def burnIn(self, X=None, Y=None, KernParam=None, sigmaNoise=None):
		#print "Running burn in on: " + str(self.X.shape[0]) + " observations"

		# allocate inputs (if provided):
		#if X!=None:
			#self.X = X
		#if Y!=None:
			#self.Y = Y
		#if KernParam!=None:
			#self.KernParam = KernParam
		#if sigmaNoise!=None:
			#self.sigmaNoise = sigmaNoise

		# define kernel:
		self.GPkernel = GPy.kern.RBF(input_dim = self.p, variance=self.KernParam[0], lengthscale=self.KernParam[1:self.p+1], ARD=True)

		# fit GP:
		self.GP = GPy.models.GPRegression(self.X,self.Y,self.GPkernel)
		# set white noise parameter:
		self.GP.Gaussian_noise.param_array[0] = self.sigmaNoise
		self.GP.parameters_changed() # let the GP object know the parameters have changed
		if self.plot:
			self.GP.plot()

	def Update(self, newX, newY):
		"""
		Update GP learner based on new observations, newX, and response, newY
		
		"""
		# this is incredible inefficient atm but there doesnt seem to be a mechanism for updating GPs in GPy atm..
		self.X = numpy.vstack((self.X, newX))
		self.Y = numpy.vstack((self.Y, newY))
		self.GP = GPy.models.GPRegression(self.X,self.Y,self.GPkernel)
		self.GP.Gaussian_noise.param_array[0] = self.sigmaNoise
		self.GP.parameters_changed() # let the GP object know the parameters have changed

	def SuggestNew(self, xRange, yRange, acqRule = "PI", fPlus='Pred', returnGrid=False, epsilon=0, iter_=None, dim=None): 
		"""
		
		Suggest new point on the grid at which to observe objective next

		INPUT:
			- xRange: range of values on x axis (first dimension)
			- yRange: range of values on y axis (second dimension)
			- acqRule: acquisition rule. Can be one of eitehr "EI" for expected improvement or "PI" for probability of improvement#
			- epsilon is for PI and EI
			- iter is number of iterations

		"""

		n1 = len(xRange)
		n2 = len(yRange)
		
		# Definition of incumbent depends on noise level:
			# 1) we use observed maximum in noise-free environments
		if fPlus=="Obs":
			fPlus = self.Y.max() # observed maximum and NOT predicted maximum (X=coordinates, Y=observed values)

			# 2) in noisy environments, instead of using the best observation, we use the distribution at the sample points,
			#   and define as the incumbent the point with the highest expected value (Brochu et al. 2010)
		elif fPlus=="Pred":
			fPlus = self.GP.predict(self.X)[0].max()


		if acqRule not in ["EI", "PI", "UCB"]:
			print "unrecognized acquistion rule... please try again"

		AcqGrid = numpy.zeros((n1,n2))
		PredGrid = numpy.zeros((n1,n2))
		VarGrid=numpy.zeros((n1,n2))

		for i in range(n1):
			for j in range(n2):
				muNew = self.GP.predict( numpy.array([[ xRange[i] ,yRange[j] ]]))[0][0][0]
				varNew = self.GP.predict( numpy.array([[ xRange[i] ,yRange[j] ]]))[1][0][0] 
				# changed on 4.2.2016 - self.GP.predict outputs posterior variance, so we need to change it to std by sqrt(var)
				stdNew=numpy.sqrt(varNew)
				fMax  = fPlus
				if acqRule=="EI":
					AcqGrid[i,j] = EIacquisition(muNew, stdNew, fMax, epsilon)
				elif acqRule=="PI":
					AcqGrid[i,j] = PIacquisition(muNew, stdNew, fMax, epsilon)
				elif acqRule=="UCB":
					AcqGrid[i,j] = UCBacquisition(muNew, stdNew, iter_, dim)
				
				PredGrid[i,j]=muNew
				VarGrid[i,j]=varNew

		# output of proposed point is in rows and columns (0-indexed)
		ProposedPoint = numpy.unravel_index(AcqGrid.argmax(), AcqGrid.shape)
		
		if returnGrid:
			return ProposedPoint, AcqGrid, PredGrid,VarGrid
		else:
			return ProposedPoint

	def retuneParams(self, bounded=False, LS_lower=None, LS_upper=None,Var_lower=None,Var_upper=None,Noise_lower=None, Noise_upper=None):
		"""
			tune parameters using type-2 ML
			bounded: implements some bounds on the lengthscale parameters
		"""
		if bounded:
			print('bounded')
			self.GP.rbf.lengthscale.constrain_bounded(LS_lower, LS_upper)
			self.GP.rbf.variance.constrain_bounded(Var_lower, Var_upper)
			self.GP.Gaussian_noise.variance.constrain_bounded(Noise_lower, Noise_upper) # constrain white noise variance
			
		else: 
			print('not bounded')

		self.GP.optimize()


