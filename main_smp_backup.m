clear
clear soundmexpro
clc
if 1 ~= soundmexpro('exit')
    error(['error calling ''exit''' error_loc(dbstack)]);
end

EyeTrack = 1;
Continue = 0; %set to 1 if just crashed and want to start from crash point

%% read table
Test_ID = input("Please enter ID of test participant: \n","s");
df_loc = fullfile(pwd,"files",strcat(Test_ID,"_df",".mat"));
load(df_loc);
%load('calibration.mat')
disp(["loaded: " df_loc]);
nTrain = 10;
tot_trials = size(df,1) - 1;

%% setup    
sca;
close all;
PsychStartup;
InitializePsychSound;
Screen('Preference', 'SkipSyncTests', 2); %Must be removed outside of development
PsychDefaultSetup(2);
AssertOpenGL;

if Continue == 1
    answer = input("Are you continuing an experiment halfway? [y/n]","s");
    if answer == "y" || "yes"
        load("temp_triali.mat");
        continue_idx = triali;
    else
        error("Please set Continue variable to 0.")
    end
end

%% Screen Initialisation - should be moved to start of app or beginning of test
% Get the screen numbers. 
screens = Screen('Screens');
%Screen('Preference','ConserveVRAM',64); %May be needed for weaker systems

%Select screen. If external exists chooses external screen
screenNumber = 1; %max(screens);

%get grey background
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
grey = white / 2;

% Open an on screen window using PsychImaging and color it grey.
[win, windowRect] = PsychImaging('OpenWindow', screenNumber, grey);
[screenXpixels, screenYpixels] = Screen('WindowSize', win);
[xCenter, yCenter] = RectCenter(windowRect);
Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

%Read Grey Screen Image
imgloc = fullfile(pwd,'images','GreyBackground_Screening_filled.jpg');
[greyImage, ~, alpha] = imread(imgloc);
[s1, s2, s3] = size(greyImage);
imageTexture = Screen('MakeTexture', win, greyImage);
ifi = Screen('GetFlipInterval', win);

%% SoundMexPro - driver setup
%confirguration file
cfgfile = [pwd '\t_smpcfg.mat'];
if ~exist(cfgfile, 'file')
    return
end
load(cfgfile);

smp_disp('initializing SoundMexPro');
[success, lictype] = soundmexpro('init', ...    % command name
    'driver', smpcfg.driver , ...               % enter a name here to load a driver by it's name
    'samplerate', 48000,...                     % samplerate to use (default is 44100)
    'numbufs', 10, ...                          % number of software buffers used to avoid xruns (dropouts, default is 10)
    'output', smpcfg.output, ...                % list of output channels to use 
    'input', smpcfg.input, ...                  % list of input channels to use
    'track', 4 ...                              % number of virtual tracks
    );

if 1 ~= success
    error(['error calling ''init''' error_loc(dbstack)]);
end
smp_disp(['You are running SoundMexPro with licence type: ' lictype{1}]);

%check driver
[success, drivername] = soundmexpro('getactivedriver');
if (~success)
    error(['error calling ''getactivedriver''' error_loc(dbstack)]);
end

%check channels
[success, OutChannels, InChannels] = soundmexpro('getactivechannels');
if (~success)
    error(['error calling ''getactivechannels''' error_loc(dbstack)]);
end

smp_disp('The following output and input channels are initialized:');
OutChannels
InChannels

%% SoundMexPro - track mapping

[success, trackmap] = soundmexpro('trackmap');
if (~success)
    error(['error calling ''trackmap''' error_loc(dbstack)]);
end
[success, trackmap] = soundmexpro('trackmap', ...
   'track', [0 0 1 2] ...        % new mapping
    );
if (~success)
    error(['error calling ''trackmap''' error_loc(dbstack)]);
end
smp_disp(' ');
smp_disp('User defined track mapping:');
for i = 1 : length(trackmap)
    smp_disp(['Virtual track no. ' num2str(i-1) ' is currently mapped to output channel no. ' num2str(trackmap(i))]);
end
%track names 
[success, tracknames] = soundmexpro('trackname', 'name', {'Speech', 'Noise', 'trigBiosemi', 'trigTobii'});
if (~success)
    error(['error calling ''trackname''' error_loc(dbstack)]);
end
smp_disp(['Defined tracknames:']);
[success, tracknames] = soundmexpro('trackname');
if (~success)
    error(['error calling ''trackname''' error_loc(dbstack)]);
end
if 1 ~= soundmexpro('show')
    error(['error calling ''show''' error_loc(dbstack)]);
end
if 1 ~= soundmexpro('showtracks', 'wavedata', 1)    % command name
    error(['error calling ''showtracks''' error_loc(dbstack)]);
end
tracknames
%% stimtrack
trigger = []; triglength = .1; OutputFs = 48000;
trigsamples = triglength*48000;
trigger(1:trigsamples) = ones(1, trigsamples);
startstop = 0.025;
trigger = [zeros(1, round((startstop+0.025)*OutputFs)), trigger, zeros(1, round((startstop+0.025)*OutputFs))];
trigger = trigger.*1.2;

%% Ramping parameters
hannLen = 50e-3*48e3;
hannWin = hann(2*50e-3*48e3);
%% Eyetracker setup
if EyeTrack
    tobii = EyeTrackingOperations();
    found_eyetrackers = tobii.find_all_eyetrackers()
    my_eyetracker = found_eyetrackers(1)
    disp(["Address: ", my_eyetracker.Address])
    disp(["Model: ", my_eyetracker.Model])
    disp(["Name (It's OK if this is empty): ", my_eyetracker.Name])
    disp(["Serial number: ", my_eyetracker.SerialNumber])
end
pupil_data = [];
mkdir(fullfile("pupildata",Test_ID));
%% Random screens before test, can remove later when implemented in app
Screen('DrawTexture', win, imageTexture);
vbl = Screen('Flip', win, [], 1);
DrawFormattedText(win,['You are about to be presented with a series of videos. \n\n Please pay attention as you will be asked to recall events afterwards. \n\n The test will begin shorty...'], 'center', 'center');
Screen('Flip',win,[],1);
KbStrokeWait;

for triali=1:size(df,1)
    if Continue == 1 
        triali = continue_idx;
        continue_idx = continue_idx + 1;
    end

    if df.modality(triali) == 1 %Audiovisual
        sentenceid = df.sentence_id(triali);
        speech = char(df.AudioFile(triali));
        noise = char(df.NoiseFile(triali));
        video = char(df.MovieFile(triali));
        volumeSpeech = df.TargetLevel(triali);
        volumeNoise = df.NoiseLevel(triali);
        
        moviefile = fullfile(pwd,'video', video);
        %preload movie
        [movie, duration, fps] = Screen('OpenMovie', win, moviefile);
        %speech files and noise length
        [y, fs] = audioread(fullfile(pwd,'audio','Speech',speech));
        y = [zeros(fs*2,1); y; zeros(fs*2,1)];
        [y1, ~] = audioread(fullfile(pwd,'audio','Noise',noise));
        y1 = y1(1:length(y));
        trigger_stim = [trigger zeros(1,length(y) - length(trigger)*3) trigger trigger]';

        %ramping
        y1(1:hannLen) = hannWin(1:hannLen).*y1(1:hannLen);
        y1(end-hannLen+1:end) = hannWin(hannLen+1:end).*y1(end-hannLen+1:end);

        %preload audio
        soundmexpro('loadmem','data',y,'track',0);
        soundmexpro('loadmem','data',y1,'track',1);
        %preload trigger
        soundmexpro('loadmem','data',trigger_stim,'track',[2 3]);

        % set speech tracks volume
        if 1~= soundmexpro('trackvolume', ...    % command name
                'track', 0, ...              % tracks to set
                'value', 10^(-volumeSpeech/20) ...         % value
                )
            error(['error calling ''trackvolume''' error_loc(dbstack)]);
        end
        % set noise tracks volumes
        if 1~= soundmexpro('trackvolume', ...    % command name
                'track', 1, ...              % tracks to set
                'value', 10^(-volumeNoise/20) ...         % value
                )
            error(['error calling ''trackvolume''' error_loc(dbstack)]);
        end
        if 1 ~= soundmexpro('updatetracks', 'wavedata', 1)    % command name
            error(['error calling ''updatetracks''' error_loc(dbstack)]);
        end

        %% play
        % Wait until user releases keys on keyboard:
        
        WaitSecs(2);
        
        % Get the vertical refresh rate of the monitor
        ifi = Screen('GetFlipInterval', win);
        
        % Retreive the maximum priority number and set max priority
        topPriorityLevel = MaxPriority(win);
        Priority(topPriorityLevel);
        
        flipSecs = 50; %50 fps
        waitframes = round(flipSecs / ifi);
        
        smp_disp(['Now presenting trial number: ' num2str(triali)]);
        smp_disp(['Now presenting sentence number: ' num2str(sentenceid)]);

        if exist('gaze_data',"var")
            clear gaze_data
        end

        my_eyetracker.get_gaze_data();
        pause(1);
        result = my_eyetracker.get_gaze_data();
        if isa(result,'StreamError')
            fprintf('Error: %s\n',string(result.Error.value));
            fprintf('Source: %s\n',string(result.Source.value));
            fprintf('SystemTimeStamp: %d\n',result.SystemTimeStamp);
            fprintf('Message: %s\n',result.Message);

        elseif isa(result,'GazeData')
            % Collect data
            parfeval(@pause,1,length(y)/fs)
        end

        [droppedframes] = Screen('PlayMovie', movie, 1);
        % Playback loop: Runs until end of movie or keypress:
        if 1~= soundmexpro('start')
            error(['error calling ''start''' error_loc(dbstack)]);
        end
        breakflag = 0;
        while breakflag == 0
            % Wait for next movie frame, retrieve texture handle to it
            tex = Screen('GetMovieImage', win, movie);
            % Valid texture returned? A negative value means end of movie reached:
            if tex<=0
                breakflag = 1;
               break;
            end
            % Draw the new texture immediately to screen:
            Screen('DrawTexture', win, tex);
            % Update display:
            [VBLTimestamp StimulusOnsetTime FlipTimestamp Missed Beampos] = Screen('Flip', win, 0);
            % Release texture:
            Screen('Close', tex);
        end
            
            %upload gaze data
            gaze_data = my_eyetracker.get_gaze_data();
            my_eyetracker.stop_gaze_data();

            smp_disp('Playback has finished, press space to continue...')
            % Stop playback: 
            Screen('PlayMovie', movie, 0);
            % Close movie:
            Screen('CloseMovie', movie);
        %Disable below if you want to keep phase static at end    
        Screen('DrawTexture', win, imageTexture);
        Screen('flip', win,[], 1);
        save(fullfile("pupildata",Test_ID,strcat(Test_ID,"_",string(triali),"_pupil.mat")),"gaze_data");
        KbStrokeWait;
        smp_disp('Starting next playback...')
        FlushEvents();
        
    elseif df.modality(triali) == 2 % Audio-only
        sentenceid = df.sentence_id(triali);
        speech = char(df.AudioFile(triali));
        noise = char(df.NoiseFile(triali));
        video = char(df.MovieFile(triali));
        volumeSpeech = df.TargetLevel(triali);
        volumeNoise = df.NoiseLevel(triali);
        img = df.beg_img(triali);
        
        %img
        beg_img_loc= fullfile(pwd,'images', img);
        [beg_img, ~, alpha] = imread(beg_img_loc);
        beg_tex = Screen('MakeTexture', win, beg_img);
        
        %speech
        [y, fs] = audioread(fullfile(pwd,'audio','Speech', speech));
        y = [zeros(fs*2,1); y; zeros(fs*2,1)];
        [y1, ~] = audioread(fullfile(pwd,'audio','Noise',noise));
        y1 = y1(1:length(y));
        trigger_stim = [trigger zeros(1,length(y) - length(trigger)*3) trigger trigger]';

        %ramping
        y1(1:hannLen) = hannWin(1:hannLen).*y1(1:hannLen);
        y1(end-hannLen+1:end) = hannWin(hannLen+1:end).*y1(end-hannLen+1:end);
        
        %preload audio
        soundmexpro('loadmem','data',y,'track',0);
        soundmexpro('loadmem','data',y1,'track',1);
        %preload trigger
        soundmexpro('loadmem','data',trigger_stim,'track',[2 3]);
        
        % set speech tracks volume
        if 1~= soundmexpro('trackvolume', ...    % command name
                'track', 0, ...              % tracks to set
                'value', 10^(-volumeSpeech/20) ...         % value
                )
            error(['error calling ''trackvolume''' error_loc(dbstack)]);
        end
        % set noise tracks volumes
        if 1~= soundmexpro('trackvolume', ...    % command name
                'track', 1, ...              % tracks to set
                'value', 10^(-volumeNoise/20) ...         % value
                )
            error(['error calling ''trackvolume''' error_loc(dbstack)]);
        end
        if 1 ~= soundmexpro('updatetracks', 'wavedata', 1)    % command name
            error(['error calling ''updatetracks''' error_loc(dbstack)]);
        end
        %DrawFormattedText(win,['You are about to be presented with a video. \n\n Please pay attention as you will be asked to recall events afterwards. \n\n When you are ready, press any key to play'], 'center', 'center');
        Screen('DrawTexture', win, beg_tex, [], [], 0);
        %% play
        % Wait until user releases keys on keyboard:
        
        WaitSecs(2);
        % Get the vertical refresh rate of the monitor
        ifi = Screen('GetFlipInterval', win);
        
        % Retreive the maximum priority number and set max priority
        topPriorityLevel = MaxPriority(win);
        Priority(topPriorityLevel);
        
        flipSecs = 50; %50 fps
        waitframes = round(flipSecs / ifi);
        
        smp_disp(['Now presenting trial number: ' num2str(triali)]);
        smp_disp(['Now presenting sentence number: ' num2str(sentenceid)]);

        if exist('gaze_data',"var")
            clear gaze_data
        end

        my_eyetracker.get_gaze_data();
        pause(1);
        result = my_eyetracker.get_gaze_data();
        if isa(result,'StreamError')
            fprintf('Error: %s\n',string(result.Error.value));
            fprintf('Source: %s\n',string(result.Source.value));
            fprintf('SystemTimeStamp: %d\n',result.SystemTimeStamp);
            fprintf('Message: %s\n',result.Message);

        elseif isa(result,'GazeData')
            % Collect data
            parfeval(@pause,1,length(y)/fs)
        end

        if 1~= soundmexpro('start')
            error(['error calling ''start''' error_loc(dbstack)]);
        end
        Screen('flip', win,[], 1); 
        breakflag = 0;
        soundmexpro('wait','track',1)
        smp_disp('Playback has finished, press space to continue...')
        breakflag = 1;

        %upload gaze data
        gaze_data = my_eyetracker.get_gaze_data();
        my_eyetracker.stop_gaze_data();
  
        Screen('DrawTexture', win, imageTexture);
        Screen('flip', win,[], 1);
        save(fullfile("pupildata",Test_ID,strcat(Test_ID,"_",string(triali),"_pupil.mat")),"gaze_data");
        KbStrokeWait;
        smp_disp('Starting next playback...')
        FlushEvents();
    end
    save("temp_triali.mat","triali");

    if triali == nTrain
        DrawFormattedText(win,['The trial phase has ended. The actual text begins now. \n\n Press ANY KEY to continue...'], 'center', 'center');
        Screen('Flip',win,[],1);
        KbStrokeWait;
    end

    if triali == tot_trials/2 + nTrain/2
        DrawFormattedText(win,['Switching modalities... \n\n Press ANY KEY to continue...'], 'center', 'center');
        Screen('Flip',win,[],1);
        KbStrokeWait;
    end

    if triali == 100 && Continue == 1
        disp("ENDED! You may close the experiment now")
        return
    end
end
FlushEvents();
sca