% Filter white noise using the coefficients of the long-term speech
% envelope (LTSE) of the speech corpus ==> to create SSN
% In time domain: apply the envelope extracted from the speech signal to
% the SSN signal ==> to create SMN.
% Long-term average spectrum (LTAS) of SSN matches that of the speech
% corpus. SMN is the same as SSN in the spectral domain, but modulated in
% the time domain.

clear all
close all
clc

dir_speech = fullfile(pwd,'audio','Speech','Female 1','List 1'); 
dir_masker = fullfile(pwd,'audio','Noise'); 
dir_masker_destination = fullfile(pwd,'audio','Noise'); % enter pathway here to output folder for new maskers

wavs = dir(fullfile(dir_speech, '0003.wav')); 
masker = dir(fullfile(dir_masker, 'resampled.wav')); % white noise audio .wav file

[sig_speech, fss] = audioread(fullfile(dir_speech, wavs.name)); 
[sig_noise, fsm] = audioread(fullfile(dir_masker, masker.name)); 

% If the sampling rates of the two audio files are not the same, stop program
if fsm ~= fss 
    fprintf('sampling rates are not the same!')
    return 
end

% edit length of sig_noise TO EQUAL LENGTH OF sig_speech
% Add 'else' line if length(sig_noise) < length(sig_speech)
% I assume that Unmodulated.wav is longest here
if length(sig_noise) > length(sig_speech)
    sig_noise = sig_noise(1:length(sig_speech));
end

rms_speech = rms(sig_speech);
sig_speech = sig_speech/rms_speech;

Nyq = fss/2; 
nlpc = 1024; 
n = (fss/1e3) + 4; % Markel & Gray (1976)
% n = ((fss/1e3)/1.2) + 2; % nth-order recommendation for female adult speech

% ESTIMATE LPC COEFFICIENTS OF LTASS AND FILTER WHITE NOISE TO CREATE SSN
[a1,g1] = lpc(sig_speech,n); % get estimated LPC coefficients of long term average speech spectrum
[H1,F1] = freqz(g1,a1,nlpc,fss); % frequency response of digital filter
SSN = filter(g1,a1,sig_noise); % filter white noise with LPC coefficients to create SSN

rms_Noise = rms(sig_noise);
rms_SSN = rms(SSN);
SSN = SSN*rms_Noise/rms_SSN; %rms normalisation

% LPC Coefficients for LTASS
[a2,g2] = lpc(SSN,n);
[H2,F2] = freqz(g2,a2,nlpc,fss); % frequency response of digital filter

% SAVE SSN .WAV FILE
SSN_name = join(['SSN',num2str(n),'th_order_lpc.wav']); 
audiowrite(fullfile(dir_masker2disk,SSN_name),SSN,fss);

%% CREATE SPEECH MODULATED NOISE (SMN)
env = abs(hilbert(sig_speech)); % envelope of speech signal in time domain
SMN = SSN.*env; % apply amplitude modulation to speech-shaped noise

rms_SMN = rms(SMN);
SMN = SMN*rms_Noise/rms_SMN; % T.Cox's recommended rms normalisation

% ESTIMATE LPC COEFFICIENTS OF LTAS OF SMN
[a3,g3] = lpc(SMN,n);
[H3,F3] = freqz(g3,a3,nlpc,fss); % frequency response of digital filter

% SAVE SMN .WAV FILE
SMN_name = join(['SMN_',num2str(n),'nd_order_lpc.wav']);
audiowrite(fullfile(dir_masker2disk,SMN_name),SMN,fss);

%%
% PLOT LTASS VERSUS LTAS OF SSN and SMN
p1 = plot(F1/1e3,mag2db(abs([H1,H2,H3])),'linewidth',3);

p1(1).Color = 'r';
p1(2).Color = 'g';
p1(3).Color = 'b';

ax = gca; 
ax.XLim = ([0.02 20]); % define x-axis limits from 20 Hz to 20 kHz
grid on; 
grid minor;
xlabel('Frequency (kHz)');
ylabel('Magnitude (dB)');
title('Long term average spectra');
ax.FontSize = 8;
ax.FontWeight = 'bold';
legend({'LTASS','LTAS SSN','LTAS SMN'});





