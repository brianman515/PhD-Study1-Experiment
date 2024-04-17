close all
clc
fs = 48e3;
[y1 ~] = audioread("audio\Speech\0001.wav");
[y2 ~] = audioread("audio\Speech\0002.wav");
[y3 ~] = audioread("audio\Speech\0003.wav");
[y4 ~] = audioread("audio\Speech\0004.wav");
[y5 ~] = audioread("audio\Speech\0005.wav");
[y6 ~] = audioread("audio\Speech\0006.wav");
[y7 ~] = audioread("audio\Speech\0007.wav");
[y8 ~] = audioread("audio\Speech\0008.wav");
[y9 ~] = audioread("audio\Speech\0009.wav");
[y10 ~] = audioread("audio\Speech\0010.wav");

cut_time=1000e-3*fs;

tmp = {y1,y2,y3,y4,y5,y6,y7,y8,y9,y10};

for ii=1:10
    temp = tmp{ii}; 
    tmp{ii} = temp(cut_time:end-cut_time);
end

y = vertcat(tmp{1},tmp{2},tmp{3},tmp{4},tmp{5},tmp{6},tmp{7},tmp{8},tmp{9},tmp{10});

audiowrite("audio\Speech\long.wav",y,fs);