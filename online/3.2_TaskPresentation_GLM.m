%% Real-time fMRI task presentation and GLM loop

% All tasks were implemented in Matlab using Psychtoolbox-3 (not part of code here) 
% Each run consisted of 16 task block iterations; each iteration consisted of a 
% task block lasting 34 s followed by 10 s rest block (white fixation cross on black background). 
% Preceding each task block, participants received a brief instruction (5 s) about the task they 
% would need to perform in the upcoming block followed by a short 3 s rest period (black background).

% After each task block, we ran incremental GLMs in Matlab (in the same script) on the pre-processed 
% time courses of each target network (read as text file derived from 3.1). Incremental GLM refers to the design 
% matrix growing with each new task block, i.e., the number of timepoints as well as the number of regressors 
% increasing with the progression of the real-time experiment. The GLM consisted of task regressors of interest 
% (one regressor for each task block), task regressors of no interest (e.g., 5 s instruction period) as well as 
% confound regressors (seven motion and linear trend regressor) and an intercept term. Task regressors were modelled 
% by convolving a boxcar kernel with a canonical double-gamma hemodynamic response function (HRF). For computing 
% the FPN>DMN dissociation target measure, after each task block, we computed the difference between the estimates 
% of all task regressors of interest (i.e., beta coefficients) for the FPN and DMN (i.e., FPN > DMN). 
% The resulting contrast values were then entered into the Bayesian optimisation algorithm (saved as text file 
% that is read by 3.3).

% An initial burn-in phase of four randomly selected tasks was employed, i.e., the first GLM was only computed 
% at the end of the fourth block after which the closed-loop experiment commenced and tasks were seleced based 
% on the result of the Bayesian optimisation (read as text file derived from 3.3).
%
% To remove outliers, scrubbing (i.e., data replacement by interpolation) was performed on network time courses 
% with the cut-off set to ± 4 SD. Removal of low-frequency linear drift was achieved by adding a linear 
% trend predictor to the general linear model (GLM). To further correct for motion, confound regressors 
% were added to the GLM consisting of six head motion parameters and a binary regressor flagging motion spikes 
% (defined as TRs for which the framewise displacement exceeded 3).

clear all;close all; clc;

%% Subject info
session='online06';
subjectID='subjectXYZ';

%% Scan info
burnIn_stimuli=4; % how many stimuli we will need for initializing GP regression
burnIn_TRs=10; % how many TRs to skip in the beginning to allow for T1 equilibration effects
numBLOCKs=16; % number of BLOCKs
nROIs=2; % number of ROIs in text document
length_TRs=2; %in seconds
hrf=spm_hrf(length_TRs); %SPM function
FD_thresh=3; %in mm - define motion outlier threshold
old_networkSize=0; %always 0

%% Network and motion directory - shared with 3.1 Real-time fMRI preprocessing loop
% indicate where network timecourses and motion parameters can be loaded in
% from

%% Task condition directory - shared with 3.3 Real-time Bayesian optimization loop
stimDir=['/Users/.../stimCommands']; 
inputFile='input.txt';%% text file created by 3.3 Bayesian optimisation script 

%% PARADIGM TIMING PARAMETERS
TimeTask=34  % task duration (in s)
TimeRest=10; % rest duration (in s)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PSYCHTOOLBOX SETUP BLACK SCREEN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ... depending on task setup

%% Start experiment
BLOCK=1;
textSize=Screen('TextSize', window ,50);
DrawFormattedText(window, 'Get ready ...', 'center', 'center', [250 250 250]);
Screen('Flip', window);

%% Wait for TR trigger to start experiment
[keyisdown,secs,keycode] = PsychHID('KbCheck',id_TRTrigger);
countdown=0;
fprintf('*** waiting for TR trigger *** \n')
while countdown<=burnIn_TRs % this is determined by burnIn_TRs
    fprintf('*** countdown: %d \n', countdown)
    
    while(~keycode(scankey)) % wait for 't' trigering from the MRI
        [keyisdown,secs,keycode] = PsychHID('KbCheck',id_TRTrigger);
        WaitSecs(0.001); % delay to prevent CPU hogging
    end
    
    countdown=countdown+1;
    
    while(keycode(scankey)) % first wait until all keys are released
        [keyisdown,secs,keycode] =  PsychHID('KbCheck',id_TRTrigger);
        WaitSecs(0.001);% delay to prevent CPU hogging
    end
    
    if countdown==1
        experiment_startTime = GetSecs; % experiment STARTS
    end
    
    if burnIn_TRs>0 && countdown==1 % experiment starts with REST period
        TimeStamp{BLOCK,3}=datestr(datetime,'HH:MM:SS:FFF'); % exact date and seconds (onset of each BLOCK)
        Screen('Flip', window); % back to black
    end
end
TimeStamp{BLOCK,1}=datestr(datetime,'HH:MM:SS:FFF'); % exact date and seconds (onset of each BLOCK)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% BLOCK  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for BLOCK=1:numBLOCKs
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if BLOCK ~=1 % every BLOCK will be initiated with new TR
        fprintf('*** waiting for TR trigger *** \n')
        [keyisdown,secs,keycode] =  PsychHID('KbCheck',id_TRTrigger);
        
        while(~keycode(scankey))       % wait for 't' trigering from the MRI
            [keyisdown,secs,keycode] =  PsychHID('KbCheck',id_TRTrigger);
            WaitSecs(0.001); % delay to prevent CPU hogging
        end
    end
    TimeStamp{BLOCK,1}=datestr(datetime,'HH:MM:SS:FFF'); % exact date and seconds (onset of each BLOCK)
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf('################### BLOCK: %d  ################### \n',BLOCK)
    fprintf('######### Task_number: %d  ##### Demand_level : %d  ######## \n',Task_number, Demand_level)
    fprintf('################### %s ################### \n',cogniSet{Task_number,Demand_level});
    
    stimParams(BLOCK,1)=Task_number;
    stimParams(BLOCK,2)=Demand_level;   
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Instruction slide BLOCK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    instruction_startTime=GetSecs;
    % show instruction slide to subject
    % ...
    instruction_stopTime=GetSecs; 
    Screen('Flip', window); %back to black
    WaitSecs(3);
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% TASK BLOCK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    task_startTime=GetSecs; %time task start
    % show task condition to subject
    % ...
    task_stopTime=GetSecs;%time task end
    
    % create output structure here
    taskResults(BLOCK,1)=BLOCK;
    taskResults(BLOCK,2)=Task_number;
    taskResults(BLOCK,3)=Demand_level;
    taskResults(BLOCK,4)=instruction_startTime-experiment_startTime;
    taskResults(BLOCK,5)=instruction_stopTime-experiment_startTime;
    taskResults(BLOCK,6)=task_startTime-experiment_startTime;
    taskResults(BLOCK,7)=task_stopTime-experiment_startTime;
   
    % make sure that stimDir is empty
    if exist([stimDir '/' inputFile]) ~=0
        delete([stimDir '/' inputFile]);
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Rest BLOCK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf('*** rest \n');
    Screen('FillRect',window,[0 0 0],[]);
    Screen('TextSize', window, 250);
    DrawFormattedText(window, '+', 'center', 'center', [255,255,255]);
    Screen('Flip', window, [], 0);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% incremental GLM %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    rest_startTime=GetSecs;
    
    % if tasks falls in burn-in period - no GLM is computed; we straight
    % proceed to next task
    if BLOCK<burnIn_stimuli
        WaitSecs(round(TimeRest-(GetSecs-rest_startTime),2)-0.8); 
        
        if ~(BLOCK==numBLOCKs)
            Task_number=Task_number_LIST(1+BLOCK);
            Demand_level=Demand_level_LIST(1+BLOCK);
        end
        
    % from 4.task (=burn-in) on, we compute GLM
    elseif BLOCK>=burnIn_stimuli
        tic
        WaitSecs(round(TimeRest-(GetSecs-rest_startTime),2)-0.815);
        toc
        
        tic
        fprintf('*************** computing iGLM ***************\n');
        
        %% Computing GLM %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
      	%%%%%%%%%%%%%%%%%%% load in network timecourses %%%%%%%%%%%%%%%%%%%
        [FID]=fopen([DIR],'r');
        while FID ==-1 % this prevents an error when loading in the file
            [FID]=fopen([DIR],'r');
            pause(0.0001);
        end
        
        numCols=nROIs;
        formatSpec =  '%f';
        sizeA = [numCols Inf];
        networks=(fscanf(FID,formatSpec,sizeA))'; % put them into format of text file
        fclose(FID);
        ss=size(networks,1);
        networkSize=size(networks,1);

        %%% double check I have new observations...
        while networkSize<old_networkSize
            fprintf('*** catching error whether I really have new observations \n');
            [FID]=fopen([DIR],'r');
            while FID ==-1 % this prevents an error when loading in the file
                [FID]=fopen([DIR],'r');
                pause(0.0001);
            end
            numCols=nROIs;
            formatSpec =  '%f';
            sizeA = [numCols Inf];
            networks=(fscanf(FID,formatSpec,sizeA))'; % put them into format of text file
            fclose(FID);
            ss=size(networks,1);
            networkSize=size(networks,1);
        end;

        %%%%%%%%%%%%%%%%%%%% load in motion parameters %%%%%%%%%%%%%%%%%%%%
        [FID]=fopen([motion_DIR],'r');
        while FID ==-1 % this prevents an error when loading in the file
            [FID]=fopen([DIR],'r');
            pause(0.0001);
        end
        numCols=6;
        formatSpec =  '%f';
        sizeA = [numCols Inf];
        motion=(fscanf(FID,formatSpec,sizeA))'; % put them into format of text file
        fclose(FID);
        aa=size(motion,1);

        %%%%%%%%%%%%%%%%%%%% load in framewise-displacement %%%%%%%%%%%%%%%
        [FID]=fopen([FD_DIR],'r');
        while FID ==-1 % this prevents an error when loading in the file
            [FID]=fopen([DIR],'r');
            pause(0.0001);
        end
        numCols=1;
        formatSpec =  '%f';
        sizeA = [numCols Inf];
        FD=(fscanf(FID,formatSpec,sizeA))'; % put them into format of text file
        fclose(FID);
        bb=size(FD,1);

        %%%%%%%%%%%%%%% catch error of unequal size %%%%%%%%%%%%%%%%%%%%%%%
        dd=min([ss,aa,bb]); % get minimum Length: network - motion - FD
        motion=motion(1:dd,:); % cut to minimum Length
        networks=networks(1:dd,:); 
        FD=FD(1:dd,:);
        
        fprintf('*** length networks: %d - length motion: %d - length FD: %d \n',ss,aa,bb);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%% OUTLIER DETECTION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % identify outliers - based on 4xSD
        std_tc=std(networks);
        mean_tc=mean(networks);
        upperthresh=mean_tc+(4*std_tc);
        lowerthresh=mean_tc-(4*std_tc);
        id_outliers_upper=find(networks(:,1)>upperthresh(1));
        id_outliers_lower=find(networks(:,1)<lowerthresh(1));

        % Do scrubbing
        id_outliers=[id_outliers_upper; id_outliers_lower];
        clean_net_timecourses=networks;

        if isempty(id_outliers)
            fprintf(' >>> no STD outliers identified <<< \n')
        else
            fprintf(' >>> STD OUTLIERS identified: %d <<< \n', length(id_outliers))
            for nOutlier=1:length(id_outliers)
                if id_outliers(nOutlier)==1 | id_outliers(nOutlier)==size(networks,1)
                     %skip outlier detection
                else 
                    tmpAverage=(networks(id_outliers(nOutlier)-1,:)+networks(id_outliers(nOutlier)+1,:))./2;
                    clean_net_timecourses(id_outliers(nOutlier),:)=tmpAverage;
                end
            end
        end

        double_clean_net_timecourses=clean_net_timecourses; 

        %%%%%%%%%%%%%%% get binarised  FD outlier regressor %%%%%%%%%%%%%%%
        id_FDout=find(FD>FD_thresh);
        if length(id_FDout)>=1
            fprintf('>>> creating FD regressor with %d outliers << \n', length(id_FDout));
            binFD=zeros(length(FD),1);
            binFD(id_FDout)=1;
        end

        %%%%%%%%%%%%% build regressors (=explanatory variables, EVs) %%%%%%
        % build task regressors
        timing_taskBlocks=zeros(BLOCK,2);
        timing_taskBlocks(:,1)=taskResults(:,6);  % start time of the task
        timing_taskBlocks(:,2)=taskResults(:,7);  % end time of the task
        TR_timing_taskBlock=round(timing_taskBlocks./length_TRs);
        EV_task=zeros(size(networks,1),BLOCK);
        for nnblock=1:BLOCK
            EV_task([TR_timing_taskBlock(nnblock,1):TR_timing_taskBlock(nnblock,2)],nnblock)=1;
        end
        
        % build instruction slide regressor
        timing_instruct=zeros(BLOCK,2);
        timing_instruct(:,1)=taskResults(:,4);
        timing_instruct(:,2)=taskResults(:,5);
        TR_timing_instruct=round(timing_instruct./length_TRs);
        EV_instruct=zeros(size(networks,1),1);
        for nnblock=1:BLOCK
            if TR_timing_instruct(nnblock,1)==0
               TR_timing_instruct(nnblock,1)=1
            end
            EV_instruct([TR_timing_instruct(nnblock,1):TR_timing_instruct(nnblock,2)],1)=1;
        end
        
        % Make sure size of EVs and time courses are the same then add EVs together
        if dd<size(EV_task,1)
            EV_task=EV_task(1:length(networks),:);  % cut the length of EVs to timecourse of ROI
            EV_instruct=EV_instruct(1:length(networks),:);  % cut the length of instruction EVs to timecourse of ROI
        elseif dd>size(EV_task,1)
            dd=size(EV_task,1)
        end
        EV_task_instruct=[EV_task EV_instruct];
        
        %convolve regressors with HRF
        for nnblock=1:size(EV_task_instruct,2)
            conv_EV_task_instruct(:,nnblock)=conv(EV_task_instruct(:,nnblock),hrf);
        end 
        cut_conv_EV_task_instruct=conv_EV_task_instruct(1:length(networks),:); %cut to original length
        
        % demean task design
        taskDesign=[cut_conv_EV_task_instruct];
        dm_taskDesign=bsxfun(@minus,taskDesign,mean(taskDesign));
        
        % create and demean temporal derivatives
        deriv_task=[zeros(1, size(cut_conv_EV_task_instruct,2)) ;(diff(cut_conv_EV_task_instruct))];
        dm_deriv_task=bsxfun(@minus,deriv_task,mean(deriv_task));
        
        % demean motion
        dm_motion=bsxfun(@minus,motion,mean(motion));
        
        % cut to dd - just in case we may have a problem with this later
        taskDesign=taskDesign(1:dd,:);
        deriv_task=deriv_task(1:dd,:);
        motion=motion(1:dd,:);        
        
        % in case we have FD outliers, add this regressor
        if length(id_FDout)>=1
            fprintf('>>> adding binFD to design matrix << \n', length(id_FDout));
            XX=[taskDesign deriv_task motion [1:1:dd]' ones(dd,1) binFD]; % add binFD to end of design matrix
            clear binFD;
        else 
            XX=[taskDesign deriv_task motion [1:1:dd]' ones(dd,1)];
        end
       
        %%%%%%%%%%%%%%%%%%%%%%%%% GLM %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        for roi=1:nROIs
            [B,BINT,R,RINT,STATS]=regress(double_clean_net_timecourses(1:dd,roi),XX);  %coefficients,  95%CI of B, residuals ,residual interval, stats (R2, F, P)
            betas_task(:,roi)=B(1:BLOCK) %takes the betas for the tasks in design matrix
            clear B BINT R RINT STATS ;
        end
        betas_diff=betas_task(:,1)-betas_task(:,2); %FPN-DMN
       
        %%%%%%%%%%%%%%%%%%% save output for Bayesian optimisation loop %%%%
        saveascii(stimParams, [bayesianDIR '/stimParams.txt'],0);
        saveascii(betas_diff, [bayesianDIR '/betas_diff.txt'],4);
        saveascii(betas_task, [bayesianDIR '/betas_task.txt'],4);

        %%%%%%%%%%%%%%%%%%% NEW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        old_networkSize=networkSize;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%% waiting until we receive next point back from 3.3. Bayesian optimisation script %%%%%%
        tic
        while ~ exist([stimDir '/' inputFile])
            fprintf('***** waiting for Bayesian input ****** \n')
            pause(0.001);
        end
        
        [FID]=fopen([stimDir '/' inputFile],'r');
        while FID ==-1
            [FID]=fopen([stimDir '/' inputFile],'r');
            pause(0.001);
        end
        input=fscanf(FID,'%d',[1,inf]);
        fclose(FID);
        fprintf('***** INPUT received ****** \n')
    
        Task_number=input(1);
        Demand_level=input(2);

        clear aa bb dd ss *conv* XX *taskDesign timing* EV* networks TR_timing* dm* motion betas_task motion networks id_FDout FD;
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
Screen('CloseAll');
