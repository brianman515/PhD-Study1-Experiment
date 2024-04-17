clear
clc

prompt = "Please input participant ID: \n";
Test_ID = input(prompt,"s");
rng('shuffle');
DAST_path = fullfile(pwd,'files','DAST-sentences.xlsx');
DAST = readtable(DAST_path);

%% Parameters
tot_trials = 240;
nTrain = 8;
numtrials_modality = tot_trials/2;
num_snrs = 4;
numtrialspersnr = numtrials_modality/num_snrs;

studioAmerica = 0;
studioFaroe = 1;

if studioAmerica
    targetVolumes = [8 12 16 20];
    noiseVolumes = 6;
else
    targetVolumes = [10 14 18 22];
    noiseVolumes = 7;
end

%% Randomisation
orig = zeros(tot_trials,4);
orig(:,1) = 1; ID = orig(:,1);%Subject ID

%randomise sentences
sentence_list = linspace(1,1200,1200)';
sentence_list = sentence_list(randperm(length(sentence_list)));
sentence_id = sentence_list(1:tot_trials);

%randomise snr
orig_snr = ones(numtrials_modality,1);

%Input snr possibilities
cases = linspace(1,num_snrs,num_snrs);
curr_start = 1;

for trial = 1:length(cases)
    orig_snr(curr_start:curr_start+numtrialspersnr-1) = cases(trial);
    curr_start = curr_start + numtrialspersnr;
end

% curr_start = 1;
% curr_start_snr = 1;
% for modality = 1:2
%     snr = orig_snr(randperm(length(orig_snr)));
%     for trial = 1:length(cases)
%         orig(curr_start:curr_start+numtrialspersnr-1,3) = snr(curr_start_snr:curr_start_snr+numtrialspersnr-1);
%         curr_start = curr_start + numtrialspersnr;
%     end
%     curr_start_snr = 1;
% end
% snr = orig(:,3);

snr1 = orig_snr(randperm(length(orig_snr)));
snr2 = orig_snr(randperm(length(orig_snr)));
snr = vertcat(snr1,snr2);

% randomise modality
a = rand(1,1);
if a <= 0.5
    orig(1:end/2,2) = 1;
    orig(end/2+1:end,2) = 2;
else
    orig(1:end/2,2) = 2;
    orig(end/2+1:end,2) = 1;
end
modality = orig(:,2);
df = table(ID,modality,sentence_id,snr);

for ii = 1:tot_trials
    file_id_temp = num2str(df.sentence_id(ii),'%04.f');
    AudioFile = [file_id_temp '.wav'];
    MovieFile = [file_id_temp '.mp4'];
    beg_img = [file_id_temp '_beg.jpeg'];
    
    df.AudioFile(ii) = string(AudioFile);
    df.MovieFile(ii) = string(MovieFile);
    df.beg_img(ii) = string(beg_img);
    df.NoiseFile(ii) = "SSN_S.wav";
    
    switch df.snr(ii)
        case 1 % 0db SNR
            df.TargetLevel(ii) = targetVolumes(1);
        case 2 % -4dB SNR
            df.TargetLevel(ii) = targetVolumes(2);
        case 3 % -8dB SNR
            df.TargetLevel(ii) = targetVolumes(3);
        case 4 % -12dB SNR
            df.TargetLevel(ii) = targetVolumes(4);
        case 5 % -16dB SNR
            df.TargetLevel(ii) = targetVolumes(5);
    end
    df.NoiseLevel(ii) = noiseVolumes;
    
    df.Sentence(ii) = string(DAST.Sentence(DAST.Number == df.sentence_id(ii)));
    temp_keywords = strsplit(string(DAST.Keywords(DAST.Number == df.sentence_id(ii))),',');
    df.KeyWords1(ii) = temp_keywords(1);
    df.KeyWords2(ii) = temp_keywords(2);
    df.KeyWords3(ii) = temp_keywords(3);
    df.ID = string(df.ID);
    df.ID(ii) = Test_ID;

end

%df train
df_train = df(1:nTrain,:);
train_sentences = linspace(1,nTrain,nTrain);
train_snr = linspace(1,length(cases),length(cases));
train_snr = [train_snr train_snr]';
df_train.snr = train_snr;
df_train.modality = [repmat(1,nTrain/2,1); repmat(2,nTrain/2,1)];
for ii = 1:nTrain
    file_id_temp = num2str(train_sentences(ii),'%04.f');
    df_train.sentence_id(ii) = train_sentences(ii);
    AudioFile = [file_id_temp '.wav'];
    MovieFile = [file_id_temp '.mp4'];
    beg_img = [file_id_temp '_beg.jpeg'];
    
    df_train.AudioFile(ii) = string(AudioFile);
    df_train.MovieFile(ii) = string(MovieFile);
    df_train.beg_img(ii) = string(beg_img);
    df_train.NoiseFile(ii) = "SSN_S.wav";
    
    switch df_train.snr(ii)
        case 1 % 0db SNR
            df_train.TargetLevel(ii) = targetVolumes(1);
        case 2 % -4dB SNR
            df_train.TargetLevel(ii) = targetVolumes(2);
        case 3 % -8dB SNR
            df_train.TargetLevel(ii) = targetVolumes(3);
        case 4 % -12dB SNR
            df_train.TargetLevel(ii) = targetVolumes(4);
        case 5 % -16dB SNR
            df_train.TargetLevel(ii) = targetVolumes(5);
    end
    df_train.NoiseLevel(ii) = noiseVolumes;
    
    df_train.Sentence(ii) = string(DAST.Sentence(DAST.Number == df_train.sentence_id(ii)));
    temp_keywords = strsplit(string(DAST.Keywords(DAST.Number == df_train.sentence_id(ii))),',');
    df_train.KeyWords1(ii) = temp_keywords(1);
    df_train.KeyWords2(ii) = temp_keywords(2);
    df_train.KeyWords3(ii) = temp_keywords(3);
    df_train.ID = string(df_train.ID);
    df_train.ID(ii) = Test_ID;
end

df = vertcat(df_train,df);

filename = fullfile(pwd,"files",strcat(Test_ID,"_df",".mat"));
save(filename,"df");

df_result = df;
df_result.KeyWord_Corr1 = zeros(tot_trials + nTrain,1);
df_result.KeyWord_Corr2 = zeros(tot_trials + nTrain,1);
df_result.KeyWord_Corr3 = zeros(tot_trials + nTrain,1);
writetable(df_result,fullfile("results",strcat(Test_ID,"_result.csv")),"Delimiter",",");
