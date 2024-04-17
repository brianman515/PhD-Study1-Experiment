clear
clc

rng('shuffle');
list = readtable("files/DAST_List_F1A_20230321.csv", ...
    Delimiter=',');
DAST_Corpus = readtable("files/DAST_Corpus_filtered.csv",Delimiter=',');
%ID = num2str(input('ID of participant: '),'%04.f');
prompt = "Please input participant ID: \n";
ID = string(input(prompt,"s"));

conditions_snr = [1 2 3 4]; %1 = highest SNR; 4 = lowest SNR
conditions_mod = [1 0]; %1 = AV; 2 = A
TargetLevels = [10 14 18 22];
NoiseLevels = 7;
Nsentences = 30;
Ntraining = 9;
lists = 1:9;lists = randperm(length(lists));
df = cell(length(conditions_mod),length(conditions_snr));

ilist = 1;
for mod = 1:length(conditions_mod)
    for snr = 1:length(conditions_snr)
        temp_list = sortrows(DAST_Corpus(DAST_Corpus.List == lists(ilist),1:6));
        %temp_df = DAST_Corpus(ismember(DAST_Corpus.Sentence,temp_list.Sentence),2:6);
        temp_df = horzcat(array2table(repmat(string(ID),Nsentences,1),"VariableNames","ID"),temp_list);
        temp_df = temp_df(randperm(size(temp_df, 1)), :);
        temp_df.modality = repmat(conditions_mod(mod),Nsentences,1);temp_df.snr = repmat(conditions_snr(snr),Nsentences,1);
        temp_df.AudioFile = strcat(num2str(temp_df.Sentence,'%04.f'),'.wav');
        temp_df.MovieFile = strcat(num2str(temp_df.Sentence,'%04.f'),'.mp4');
        temp_df.beg_img = strcat(num2str(temp_df.Sentence,'%04.f'),'_beg.jpeg');
        temp_df.NoiseFile = repmat('SSN_S.wav',Nsentences,1);
    switch temp_df.snr(1)
        case 1
            temp_df.TargetLevel = repmat(TargetLevels(1),Nsentences,1);
            temp_df.NoiseLevel = repmat(NoiseLevels,Nsentences,1);
        case 2
            temp_df.TargetLevel = repmat(TargetLevels(2),Nsentences,1);
            temp_df.NoiseLevel = repmat(NoiseLevels,Nsentences,1);
        case 3
            temp_df.TargetLevel = repmat(TargetLevels(3),Nsentences,1);
            temp_df.NoiseLevel = repmat(NoiseLevels,Nsentences,1);
        case 4
            temp_df.TargetLevel = repmat(TargetLevels(4),Nsentences,1);
            temp_df.NoiseLevel = repmat(NoiseLevels,Nsentences,1);
    end
        temp_df.Keyword1_Corr = repmat(0,Nsentences,1);temp_df.Keyword2_Corr = repmat(0,Nsentences,1);temp_df.Keyword3_Corr = repmat(0,Nsentences,1);
        df{mod,snr} = temp_df;
        ilist = ilist + 1;
    end
end

%create Visual only df
V_list = sortrows(DAST_Corpus(DAST_Corpus.List == lists(ilist),1:6));
%V_sentence = DAST_Corpus(ismember(DAST_Corpus.Sentence,temp_list.Sentence),2:6);
V_df = horzcat(array2table(repmat(string(ID),Nsentences,1),"VariableNames","ID"),V_list);V_df = V_df(randperm(size(V_df, 1)), :);
V_df.modality = repmat(1,Nsentences,1);V_df.snr = repmat(0,Nsentences,1);
V_df.AudioFile = strcat(num2str(V_df.Sentence,'%04.f'),'.wav');
V_df.MovieFile = strcat(num2str(V_df.Sentence,'%04.f'),'.mp4');
V_df.beg_img = strcat(num2str(V_df.Sentence,'%04.f'),'_beg.jpeg');
V_df.NoiseFile = repmat('SSN_S.wav',Nsentences,1);
V_df.TargetLevel = repmat(90,Nsentences,1); %90 = Mute
V_df.NoiseLevel = repmat(NoiseLevels,Nsentences,1);
V_df.Keyword1_Corr = repmat(0,Nsentences,1);V_df.Keyword2_Corr = repmat(0,Nsentences,1);V_df.Keyword3_Corr = repmat(0,Nsentences,1);

%create training df
training_Corpus = readtable("files/DAST_Corpus_Information.csv",Delimiter=',');
training_df = [];
training_sentence = training_Corpus(1:Ntraining,1:4);
training_df.ID = repmat(string(ID),Ntraining,1);training_df.List = repmat(0,Ntraining,1);
training_df.Sentence = training_Corpus.Sentence(1:Ntraining);training_df.Offset = repmat(0,Ntraining,1);
training_df = struct2table(training_df);
training_df = join(training_df,training_sentence);
training_df.modality = [1 1 1 1 0 0 0 0 1]';training_df.snr = [1:4 1:4 0]';
training_df.AudioFile = strcat(num2str(training_df.Sentence,'%04.f'),'.wav');
training_df.MovieFile = strcat(num2str(training_df.Sentence,'%04.f'),'.mp4');
training_df.beg_img = strcat(num2str(training_df.Sentence,'%04.f'),'_beg.jpeg');
training_df.NoiseFile = repmat('SSN_S.wav',Ntraining,1);
training_df.TargetLevel = [repmat(TargetLevels',2,1); 99];
training_df.NoiseLevel = [repmat(NoiseLevels',Ntraining-1,1); NoiseLevels];
training_df.Keyword1_Corr = repmat(0,Ntraining,1);training_df.Keyword2_Corr = repmat(0,Ntraining,1);training_df.Keyword3_Corr = repmat(0,Ntraining,1);
training_df = training_df(:,[1 3 5 6 2 4 7:end]);

%combine the dfs
%list_order = ["AV_df"; "A_df"; "V_df"];
%list_order = list_order(randperm(size(list_order,1),3));
AV_df = vertcat(df{1,:});AV_df = AV_df(randperm(size(AV_df, 1)), :);
A_df = vertcat(df{2,:});A_df = A_df(randperm(size(A_df, 1)), :);
C = {AV_df,A_df};C = C(randperm(numel(C)));C{1,3} = V_df;
Conditions = vertcat(C{:});Conditions = vertcat(training_df,Conditions);
Conditions = Conditions(:,[1 2 4:6 8:15 3 7 16:18]); %rearrange columns such that words are at the end
Conditions.AudioFile = string(Conditions.AudioFile);Conditions.MovieFile = string(Conditions.MovieFile);
Conditions.beg_img = string(Conditions.beg_img);Conditions.NoiseFile = string(Conditions.NoiseFile);
Conditions.Sentence = string(Conditions.Sentence);

if exist(fullfile("files",strcat(ID,'_df.mat')),'file')
    warning("File already exists! Do not overwrite please.")
else
    save(fullfile("files",strcat(ID,'_df.mat')),"Conditions")
    writetable(Conditions,fullfile("results",strcat(ID,"_result.csv")),"Delimiter",",")
end
