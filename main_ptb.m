clear
clear soundmexpro
clc
if 1 ~= soundmexpro('exit')
    error(['error calling ''exit''' error_loc(dbstack)]);
end
%% read table
df = readtable('Conditions.csv');
df = convertvars(df,{'Speaker','List','beg_img'...
   'AudioFile','NoiseFile','MovieFile','Word_1',...
   'Word_2','Word_3'},'categorical');
% df.Speaker = categorical(df.Speaker);
% df.List = categorical(df.List);
% df.beg_img = categorical(df.beg_img);
% df.AudioFile = categorical(df.AudioFile);
% df.NoiseFile = categorical(df.NoiseFile);
% df.MovieFile = categorical(df.MovieFile);
%% setup
sca;
close all;
PsychStartup;
InitializePsychSound;
Screen('Preference', 'SkipSyncTests', 1); %Must be removed outside of development
PsychDefaultSetup(2);
AssertOpenGL;

%% Screen Initialisation - should be moved to start of app or beginning of test
% Get the screen numbers. 
screens = Screen('Screens');
%Screen('Preference','ConserveVRAM',64); %May be needed for weaker systems

%Select screen. If external exists chooses external screen
screenNumber = max(screens);

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
%% Checking and loading audio devices (maybe it can be run at startup?) 
% try PsychPortAudio('GetOpenDeviceCount'); % check for open audio devices...
%     PsychPortAudio('Close'); % ...if any, close them
% end
% %Get audioport
% dev = PsychPortAudio('GetDevices');
% dev2lookFor = 'Analog (3+4) (RME Fireface UCX)'; api2lookFor = 'Windows DirectSound';
% for devi = 1:length(dev)
%     if strcmp(dev(devi).DeviceName, dev2lookFor) && strcmp(dev(devi).HostAudioAPIName, api2lookFor) && dev(devi).NrOutputChannels > 1
%         devIx = dev(devi).DeviceIndex; 
%         break
%     end
% end

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
tracknames
%% stimtrack
trigger = []; triglength = .3; OutputFs = 48000;
trigsamples = triglength*48000;
trigger(1:trigsamples) = ones(1, trigsamples);
startstop = 0.025;
trigger = [zeros(1, round((startstop+0.025)*OutputFs)), trigger, zeros(1, round((startstop+0.025)*OutputFs))];
trigger = trigger.*1.2;
%% Random screens before test, can remove later when implemented in app
%Screen('DrawTexture', win, imageTexture, [], [], 0);
%Screen('Flip', win, [], 1);
Screen('DrawTexture', win, imageTexture);
vbl = Screen('Flip', win, [], 1);
DrawFormattedText(win,['You are about to be presented with a series of videos. \n\n Please pay attention as you will be asked to recall events afterwards. \n\n The test will begin shorty...'], 'center', 'center');
Screen('Flip',win,[],1);
KbStrokeWait;
vol = 1;

%%play
for triali=1:size(df,1)
    if df.Condition(triali) == 1 %Audiovisual
        speaker = char(df.Speaker(triali));
        list = char(df.List(triali));
        speech = char(df.AudioFile(triali));
        noise = char(df.NoiseFile(triali));
        video = char(df.MovieFile(triali));
        volumeSpeech = df.TargetLevel(triali);
        volumeNoise = df.NoiseLevel(triali);
        
        moviefile = fullfile(pwd,'video', speaker, list, video);
        %preload movie
        [movie, duration, fps] = Screen('OpenMovie', win, moviefile);
        %speech
        [y, fs] = audioread(fullfile(pwd,'audio','Speech', speaker, list,...
            speech));
        y = [zeros(fs*2,1); y; zeros(fs*2,1)];
        [y1, ~] = audioread(fullfile(pwd,'audio','Noise',noise));
        y1 = y1(1:length(y));
        soundmexpro('loadmem','data',(y+y1),'track', 0);
        %y = y * volumeSpeech;
        %y1 = y1 * volumeNoise;
        
        %DrawFormattedText(win,['You are about to be presented with a video. \n\n Please pay attention as you will be asked to recall events afterwards. \n\n When you are ready, press any key to play'], 'center', 'center');
        %Screen('DrawTexture', win, imageTexture, [], [], 0);
        %vbl = Screen('Flip', win, [], 1);
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
        
        %Screen('flip', win, [], 1);
        %PsychPortAudio('Start', pamaster, [], [], 0, [], 1);
        %Screen('Flip', win, [], 1);
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
            Screen('Flip', win, 0);
            % Release texture:
            Screen('Close', tex);
        end
            smp_disp('Playback has finished, press space to continue...')
            % Stop playback:
            Screen('PlayMovie', movie, 0);
            % Close movie:
            Screen('CloseMovie', movie);
            % Stop Audio when end of file is reached
            %PsychPortAudio('Stop', pamaster, 1);
            %PsychPortAudio('Close');
        %Disable below if you want to keep phase static at end    
        %Screen('TextSize',win,24); %Text Size   
        %DrawFormattedText(win,'*Tester now listens to response and presses a key to continue when ready*', 'center', 'center');
        Screen('DrawTexture', win, imageTexture);
        Screen('flip', win,[], 1); 
        KbStrokeWait;
        smp_disp('Starting next playback...')
        FlushEvents();
        
    elseif df.Condition(triali) == 2 %Audio-only
        speaker = char(df.Speaker(triali));
        list = char(df.List(triali));
        speech = char(df.AudioFile(triali));
        noise = char(df.NoiseFile(triali));
        img = char(df.beg_img(triali));
        volumeSpeech = df.TargetLevel(triali);
        volumeNoise = df.NoiseLevel(triali);
        
        %img
        blurredloc= fullfile(pwd,'images', speaker, list, img);
        [blurred, ~, alpha] = imread(blurredloc);
        blurred_tex = Screen('MakeTexture', win, blurred);
        
        %speech
        [y, fs] = audioread(fullfile(pwd,'audio','Speech', speaker, list,...
            speech));
        y = [zeros(fs*2,1); y; zeros(fs*2,1)];
        %noise - resample from 44.1kHz to 48kHz to match speech, then trim len to speech
        [y1, ~] = audioread(fullfile(pwd,'audio','Noise',noise));
        %audiowrite(fullfile(pwd,'audio','Noise','resampled.wav'),y1,fs);
        %[y1, ~] = audioread(fullfile(pwd,'audio','Noise','resampled.wav'));
        y1 = y1(1:length(y));
        soundmexpro('loadmem','data',(y+y1),'track', 0);
%         pamaster = PsychPortAudio('Open', devIx, 1, 2, fs, 2, [], []);
%         PsychPortAudio('FillBuffer', pamaster, [y';y1']);
%         PsychPortAudio('Volume', pamaster, vol);
        
        %DrawFormattedText(win,['You are about to be presented with a video. \n\n Please pay attention as you will be asked to recall events afterwards. \n\n When you are ready, press any key to play'], 'center', 'center');
        Screen('DrawTexture', win, blurred_tex, [], [], 0);
        %% play
        % Wait until user releases keys on keyboard:
        %KbStrokeWait;
        
        WaitSecs(2);
        vbl = Screen('flip', win, [], 1);
        %PsychPortAudio('Start', pamaster, [], [], 0, [], 1);
        breakflag = 0;
        if 1~= soundmexpro('start')
            error(['error calling ''start''' error_loc(dbstack)]);
        end
        smp_disp('Playback has finished, press space to continue...')
        breakflag = 1;
        %PsychPortAudio('Close');
        %Disable below if you want to keep phase static at end    
        %Screen('TextSize',win,24); %Text Size   
        %DrawFormattedText(win,'Please repeat the sentence. Press any key when done.', 'center', 'center'); 
        %Screen('DrawTexture', win, imageTexture, [], [], 0);
        %Screen('Flip',win,[],1);
        KbStrokeWait;
        smp_disp('Starting next playback...')
        FlushEvents();
    end
        
end
FlushEvents();
%PsychPortAudio('Close');
sca