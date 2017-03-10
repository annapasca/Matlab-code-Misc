% launch brainstorm, with no gui (but only if is not already running)
clear

if ~brainstorm('status')
    brainstorm %nogui
end


%% SET EXPORT FOLDER FOR REPORTS
export_main_folder='D:/SCRIPT e REPORTS/REPORTS_MEGHEM_take2';
export_folder1='ERF_ver2'

if ~exist([export_main_folder, '/' export_folder1])
    mkdir([export_main_folder, '/' export_folder1]) % create folder if it does not exist
end;


%% SET PROTOCOL
ProtocolName = 'Meghem_analisi_3';

% get the protocol index, knowing the name
iProtocol = bst_get('Protocol', ProtocolName);

% set the current protocol
gui_brainstorm('SetCurrentProtocol', iProtocol);

% check info
ProtocolInfo=bst_get('ProtocolInfo')

% get the subject list
my_subjects = bst_get('ProtocolSubjects')


%% ADD SPECIFIC TAG TO ALL FILES CREATED
my_tag='_ver2';

%% SELECT  TRIALS
%
my_sFiles_string={'First_Corr_'};

% make the first selection with bst process
my_sFiles_ini = bst_process('CallProcess', 'process_select_files_data', [], [], ...
    'subjectname', 'All', ...
    'includeintra',  0,...
    'tag',         my_sFiles_string{1});


my_sel_sFiles=sel_files_bst({ my_sFiles_ini(:).FileName }, 'average');


%% SEPARATE FILES FOR SUBJECT
SubjectNames={my_subjects.Subject(2:end).Name}; % NOTE! the 2-end, to exclude the intra trials

Subj_grouped=group_by_str_bst(my_sel_sFiles, SubjectNames);


%% SEPARATE FILES BY CONDITION
Conditions={'Fast18','Slow18'}
Subj_Condition={}

for iSubj=1:length(Subj_grouped)
    Subj_Condition{iSubj}=group_by_str_bst(Subj_grouped{iSubj}, Conditions); % IMPORTANT: notice I enter in the cell {}
end;

%% SEPARATE FILES BY RUN
runs={'_01_','_02_', '_03_'}
Subj_Condition_run={};

for iSubj=1:length(Subj_grouped)
    for iCond=1:length(Conditions);
        Subj_Condition_run{iSubj}{iCond}=group_by_str_bst(Subj_Condition{iSubj}{iCond}, runs); % IMPORTANT: notice I enter in the cell {}
    end;
end;

%%% CORRECTION FOR SUBJECT MH005
% Subject 05, has run _01_, _03_ and _04
Subj_Condition_run{5}{1}{2}=Subj_Condition_run{5}{1}{3} % put run 3 in cell 2 (for Condition 1, Fast)
Subj_Condition_run{5}{2}{2}=Subj_Condition_run{5}{2}{3} % put run 3 in cell 2 (for Condition 2, Slow)

other_run=sel_files_bst(my_sel_sFiles, '(MH005/)([\w]+)(_04_)'); % \w match for all alphanumeric characters
other_run_Cond=group_by_str_bst(other_run, Conditions)

Subj_Condition_run{5}{1}{3}=other_run_Cond{1}; % retrieve condition 1 (Fast) of third run
Subj_Condition_run{5}{2}{3}=other_run_Cond{2}; % retrive condition 2 (Slow) of third run


%%
%% RETRIEVE SOURCE FILES


for iSubj=1:length(SubjectNames)
    for iCond=1:length(Conditions)
        
        files_info={}; % initialize a cell to store info of files entered in the average
        
        for irun=1:length(runs)
            
            curr_files=Subj_Condition_run{iSubj}{iCond}{irun};
            
            %% RETRIEVE SOURCE (LINK) FILES
            % retrieve condition path
            curr_study=bst_get('StudyWithCondition', bst_fileparts(curr_files{1}));
            
            % exclude with the following steps the empty filenames, in the
            % ResultFile, otherwise cannot use intersect
            no_empty_DataFile_ind=find(~cellfun(@isempty, {curr_study.Result.DataFile}));
            no_empty_Resultfile=curr_study.Result(no_empty_DataFile_ind);
            
            % find intersection between curr-files (the data to be processed)
            % and the non-empty Resultfile names
            [a ind_curr_files ind_no_empty_Resultfile]=intersect(curr_files, {no_empty_Resultfile.DataFile});
            
            % retrieve link_files
            link_files={no_empty_Resultfile(ind_no_empty_Resultfile).FileName};
            
           
            % Start a new report
            bst_report('Start', link_files);
            
                  % Process: Scouts time series:
            Res = bst_process('CallProcess', 'process_extract_scout', link_files, [], ...
                'timewindow',     [-2, 3.7], ...
                'scouts',         {'Destrieux', {'G_temporal_middle R', 'G_temporal_middle L', 'G_front_middle L',...
                'G_front_middle R', 'G_pariet_inf-Angular L', 'G_pariet_inf-Angular R',...
                'G_pariet_inf-Supramar L', 'G_pariet_inf-Supramar R', 'G_parietal_sup L',...
                'G_parietal_sup R', 'S_intrapariet_and_P_trans L', 'S_intrapariet_and_P_trans R'}}, ...
                'scoutfunc',      1, ...  % Mean
                'isflip',         0, ...
                'isnorm',         0, ...
                'concatenate',    1, ...
                'save',           1, ...
                'addrowcomment',  1, ...
                'addfilecomment', 1);
            
            % Save and export report
            ReportFile = bst_report('Save', Res);
            bst_report('Export', ReportFile,  [export_main_folder, '/', export_folder1]);
            
            
            % Process: Add tag to comment.
            Res = bst_process('CallProcess', 'process_add_tag', Res, [], ...
                'tag',  [runs{irun}, my_sFiles_string{1}, Conditions{iCond}, my_tag ]  , ...
                'output', 1);  % Add to comment
            
            % Process: Add tag to name.
            Res = bst_process('CallProcess', 'process_add_tag', Res, [], ...
                'tag',  [runs{irun}, my_sFiles_string{1}, Conditions{iCond}, my_tag ]   , ...
                'output', 2);  % Add to name
            
            % create the struct at the first loop.
            % update the struct at all the other loops.
            if (irun==1)
                run_files=Res;
            else
                run_files(irun)=Res;
            end;
            
            % create cell with link_files
            files_info{irun}=link_files;
            
            % Save and export report
            ReportFile = bst_report('Save', Res);
            bst_report('Export', ReportFile,  [export_main_folder, '/', export_folder1]);
            
        end;
            
            
            %% STEP 1) RUN AVERAGE
            % Process: Average: Everything
            Res = bst_process('CallProcess', 'process_average', run_files, [], ...
                'avgtype',   2, ...  % By subject
                'avg_func',  1, ...  % Arithmetic average:  mean(x)
                'weighted',  1, ...
                'matchrows', 1, ...
                'iszerobad', 1);
            
      
            
            % Process: Add tag to name.
            Res = bst_process('CallProcess', 'process_add_tag', Res, [], ...
                'tag',   [my_sFiles_string{1}, Conditions{iCond}, my_tag]  , ...
                'output', 2);  % Add to name
            
            % Process: Add tag to comment.
            Res = bst_process('CallProcess', 'process_add_tag', Res, [], ...
                'tag',  [ my_sFiles_string{1}, Conditions{iCond}, my_tag]   , ...
                'output', 1);  % Add to comment
            
            % Process: Z-score transformation: []
            Res = bst_process('CallProcess', 'process_baseline_norm', Res, [], ...
                'baseline',   [-0.2, 0], ...
                'source_abs', 0, ...
                'method',     'zscore', ...  % Z-score transformation:    x_std = (x - &mu;) / &sigma;
                'overwrite',  0);
            
            % add file info to the file
            FileName = file_fullpath(Res(1).FileName);
            FileMat.Add_info=files_info;
            % Save file
            bst_save(FileName, FileMat, 'v6', 1);
            
            
            % Save and export report
            ReportFile = bst_report('Save', Res);
            bst_report('Export', ReportFile,  [export_main_folder, '/', export_folder1]);
            

        end
    end












