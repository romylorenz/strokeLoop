# strokeLoop
Neuroadaptive Bayesian optimization for rapidly mapping residual network function in stroke 

The paper describing the full study is published open-access in Brain: [https://doi.org/10.1093/brain/awab109]

## Notes:
This repository contains *bash*, *Python* and *Matlab* code for implementing neuroadaptive Bayesian optimisation. Offline and online processing of fMRI data was carried out with FSL (Jenkinson et al., 2012). The repository contains three folders: (1) masks, (2) offline and (3) online. In the following, we detail the content of the folders and the purpose of the respective scripts in these folders. 

## (1) Mask:
Masks of the bilateral target brain networks were based on a meta-analysis reported in (Yeo et al., 2014). The frontoparietal (FPN, i.e., Component 09) covered the superior parietal cortex, intraparietal sulcus, lateral prefrontal cortex, anterior insula and the posterior medial frontal cortex. The default mode network (DMN, i.e., Component 10) spanned the posterior cingulate cortex, precuneus, inferior parietal cortex, temporal cortex and medial prefrontal cortex. Thresholded (z > 2) and binarized maps of the two brain networks were used as mask. Masks are provided in a 4D-nifti file.

## (2) Offline:
Prior to the online run, a high-resolution gradient-echo T1-weighted structural anatomical volume (voxel size: 1.00 × 1.00 × 1.00 mm, flip angle: 9°, TR/TE: 2300/2.98 ms, 160 ascending slices, inversion time: 900 ms) and one EPI volume were acquired. The first fMRI processing steps occurred offline prior to the real-time fMRI scan. Those comprised brain extraction using BET (Smith, 2002) of the structural image followed by a rigid-body registration of the functional to the downsampled structural image (2 mm) using boundary-based registration (Greve and Fischl, 2009) and subsequent affine registration to standard brain atlas (MNI) (Jenkinson and Smith, 2001; Jenkinson et al., 2012). In patients with large lesions, BET was performed iteratively with various options (e.g., centre-of-gravity, fractional intensity threshold, vertical gradient in fractional intensity threshold) to allow the best brain extraction; results were inspected visually by experimenter. The resulting transformation matrix was used to register the FPN and DMN from MNI to the functional space of the respective subject. 

## (3) Online:
Three computational loops are run **in parallel** that share data by saving to and loading in text files.

### (3.1) Real-time fMRI preprocessing loop
For online runs, a **Python** script watches the folder where the MR scanner exports the EPI dicom files to and  calls respective bash scripts to initiate preprocessing of each EPI image using FSL (Jenkinson et al., 2012).  Incoming EPI images were motion corrected (Jenkinson et al., 2002) in real-time with the previously offline obtained functional image acting as reference. In addition, images were spatially smoothed using a 5 mm FWHM Gaussian kernel. For each TR, means of the two brain networks were extracted (*saved as text file that is read by 3.2*).

### (3.2) Real-time fMRI task presentation and GLM loop
All tasks were implemented in **Matlab** using Psychtoolbox-3. Each run consisted of 16 task block iterations; each iteration consisted of a task block lasting 34 s followed by 10 s rest block (white fixation cross on black background). Preceding each task block, participants received a brief instruction (5 s) about the task they would need to perform in the upcoming block followed by a short 3 s rest period (black background).

After each task block, we ran incremental GLMs in Matlab (in the same script) on the pre-processed time courses of each target network (*read as text file derived from 3.1*). Incremental GLM refers to the design matrix growing with each new task block, i.e., the number of timepoints as well as the number of regressors increasing with the progression of the real-time experiment. The GLM consisted of task regressors of interest (one regressor for each task block), task regressors of no interest (e.g., 5 s instruction period) as well as confound regressors (seven motion and linear trend regressor) and an intercept term. Task regressors were modelled by convolving a boxcar kernel with a canonical double-gamma hemodynamic response function (HRF). For computing the FPN>DMN dissociation target measure, after each task block, we computed the difference between the estimates of all task regressors of interest (i.e., beta coefficients) for the FPN and DMN (i.e., FPN > DMN). The resulting contrast values were then entered into the Bayesian optimisation algorithm (*saved as text file that is read by 3.3*). 

An initial burn-in phase of four randomly selected tasks was employed, i.e., the first GLM was only computed at the end of the fourth block after which the closed-loop experiment commenced and tasks were seleced based on the result of the Bayesian optimisation (*read as text file derived from 3.3*). 

To remove outliers, scrubbing (i.e., data replacement by interpolation) was performed on network time courses with the cut-off set to ± 4 SD. Removal of low-frequency linear drift was achieved by adding a linear trend predictor to the general linear model (GLM). To further correct for motion, confound regressors were added to the GLM consisting of six head motion parameters and a binary regressor flagging motion spikes (defined as TRs for which the framewise displacement exceeded 3).

### (3.3) Real-time Bayesian optimization loop
Bayesian optimisation is implemented in **Python**. It consists of a two-stage procedure that repeats iteratively in a closed loop. 

The first stage is the data modeling stage, in which the algorithm uses all available FPN>DMN difference values up to that iteration (*read as text file derived from 3.2*) to predict the subject’s brain response across the entire task space using Gaussian process (GP) regression (Rasmussen and Williams, 2006; Brochu et al., 2010; Shahriari et al., 2016). For GP, we used a zero mean function and the squared exponential kernel (Rasmussen and Williams, 2006), and relied on a Python implementation from: [http://github.com/SheffieldML/GPy]. 

The second stage is the guided search stage, in which an acquisition function is used to propose the task the subject will need to perform in the next iteration (*saved as text file that is read by 3.2*). Here we used the upper-confidence bound (GP-UCB) acquisition function (Srinivas et al., 2010) that favours the selection of points with high predicted mean value (i.e., optimal tasks), but equally prefers points with high variance (i.e., tasks worth exploring).

## References:
Brochu E, Cora VM, de Freitas N. A Tutorial on Bayesian Optimization of Expensive Cost Functions, with Application to Active User Modeling and Hierarchical Reinforcement Learning. 2010

Greve DN, Fischl B. Accurate and robust brain image alignment using boundary-based registration. NeuroImage 2009; 48: 63–72.

Jenkinson M, Bannister P, Brady M, Smith S. Improved optimization for the robust and accurate linear registration and motion correction of brain images. NeuroImage 2002; 17: 825–41.

Jenkinson M, Beckmann CF, Behrens TEJ, Woolrich MW, Smith SM. FSL. NeuroImage 2012; 62: 782–90.

Jenkinson M, Smith S. A global optimisation method for robust affine registration of brain images. Med Image Anal 2001; 5: 143–56.

Rasmussen CE, Williams CKI. Gaussian Processes for Machine Learning. Cambridge, Mass: MIT Press; 2006

Shahriari B, Swersky K, Wang Z, Adams RP, Freitas N de. Taking the Human Out of the Loop: A Review of Bayesian Optimization. Proc IEEE 2016; 104: 148–75.

Smith SM. Fast robust automated brain extraction. Hum Brain Mapp 2002; 17: 143–55.

Srinivas N, Krause A, Seeger M, Kakade SM. Gaussian Process Optimization in the Bandit Setting: No Regret and Experimental Design. In: Proceedings of the 27th International Conference on Machine Learning. 2010. p. 1015–22

Yeo BTT, Krienen FM, Eickhoff SB, Yaakub SN, Fox PT, Buckner RL, et al. Functional Specialization and Flexibility in Human Association Cortex. Cereb Cortex 2014: bhu217.
