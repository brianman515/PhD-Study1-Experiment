% Filter white noise using the coefficients of the LTASS

clear all
close all
clc

dir_speech = fullfile(pwd,'audio','Speech','Female 1','List 1'); 
dir_masker = fullfile(pwd,'audio','Noise'); 
dir_masker_destination = fullfile(pwd,'audio','Noise'); % enter pathway here to output folder for new maskers

wavs = dir(fullfile(dir_speech, '0003.wav')); 
masker = dir(fullfile(dir_masker, 'Unmodulated.wav')); % white noise audio .wav file

[sig_speech, fss] = audioread(fullfile(dir_speech, wavs.name)); 
[sig_noise, ~] = audioread(fullfile(dir_masker, masker.name)); 
%resample to 48kHz to match speech
audiowrite(fullfile(pwd,'audio','Noise','resampled.wav'),sig_noise,fss);
[sig_noise, fsm] = audioread(fullfile(pwd,'audio','Noise','resampled.wav'));
sig_noise = sig_noise(1:length(sig_speech));
        
% If the sampling rates of the two audio files are not the same, stop program
if fsm ~= fss 
    fprintf('sampling rates are not the same!')
    return 
end

% edit length of sig_noise TO EQUAL LENGTH OF sig_speech
% I assume that Unmodulated.wav is longest here
if length(sig_noise) >= length(sig_speech)
    sig_noise = sig_noise(1:length(sig_speech));
else
    fprintf('Noise file has to be longer!')
end

rms_speech = rms(sig_speech);
sig_speech = sig_speech/rms_speech;
nlpc = 1024; %bin
n = 52; %order of filter

% Lpc coefficients and create filter from it. Then filter white noise 
[a1,g1] = lpc(sig_speech,n); % get estimated LPC coefficients of long term average speech spectrum
[H1,F1] = freqz(g1,a1,nlpc,fss); % frequency response of lpc filter
SSN = filter(g1,a1,sig_noise); % filter white noise with LPC coefficients to create SSN

rms_Noise = rms(sig_noise);
rms_SSN = rms(SSN);
SSN = SSN*rms_Noise/rms_SSN; %rms normalisation

% LPC Coefficients for LTASS
[a2,g2] = lpc(SSN,n);
[H2,F2] = freqz(g2,a2,nlpc,fss); % frequency response of filter

% SAVE SSN .WAV FILE
wav_name = strsplit(wavs.name,'.');
SSN_name = [wav_name{1},'_SSN.wav'];
audiowrite(fullfile(dir_masker_destination,SSN_name),SSN,fss);

%%
% PLOT LTASS VERSUS LTAS OF SSN
p1 = plot(F1/1000,mag2db(abs([H1,H2])),'linewidth',3);

p1(1).Color = 'r';
p1(2).Color = 'b';
ax = gca; 
ax.XLim = ([0.02 20]); % define x-axis limits from 20 Hz to 20 kHz
grid on; 
grid minor;
xlabel('Frequency (kHz)');
ylabel('dB');
title('LTASS');
ax.FontSize = 8;
ax.FontWeight = 'bold';
legend({'LTASS old','LTAS SSN'});